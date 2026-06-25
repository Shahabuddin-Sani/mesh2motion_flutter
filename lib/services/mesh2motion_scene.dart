import 'dart:math';
import 'package:flutter/material.dart' hide Matrix4;
import 'package:macbear_3d/macbear_3d.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../models/editor_state.dart';
import '../engine/m2m_engine.dart';

// ignore: implementation_imports
import 'package:macbear_3d/src/gltf/gltf_parser.dart';
// ignore: implementation_imports
import 'package:macbear_3d/src/mesh/animator.dart';
// ignore: implementation_imports
import 'package:macbear_3d/src/gltf/gltf_loader.dart';

/// The main 3D scene for Mesh2Motion.
///
/// Fixes vs original:
/// 1. Camera: macbear_3d uses Z-up, so setEuler(yaw, pitch, roll) and
///    orbit/view math must use Z-up conventions.
/// 2. Animation: When injecting animations from a separate GLB, node mapping
///    is done by **name** (not by index), since animation GLBs have their own
///    node arrays.
/// 3. No double-update: entity.update() already calls animator.update()
///    internally, so the scene must NOT call it again.
/// 4. Orientation detection uses the correct axes for Z-up convention.
class Mesh2MotionScene extends M3Scene {
  M3Entity? _modelEntity;
  M3Entity? get modelEntity => _modelEntity;

  final List<M3Entity> _boneGizmos = [];
  final Map<String, M3Entity> _nodeToGizmo = {};

  M3Entity? _gridEntity;

  bool showSkeleton = true;
  bool showWireframe = false;
  SkeletonType? skeletonType;
  String? activeAnimationId;
  bool isPlaying = false;
  double playbackSpeed = 1.0;
  List<BoneInfo> bones = [];
  String? selectedNodeId;
  bool showBoneLabels = false;

  // ── Camera state (Z-up: yaw = rotation around Z, pitch = elevation) ──────
  // macbear_3d camera uses setEuler(yaw, pitch, roll)
  // Yaw = horizontal rotation, Pitch = vertical tilt from horizon
  double _cameraYaw = pi / 4;    // 45° around Z
  double _cameraPitch = pi / 6;  // 30° up from horizon  
  double _cameraDist = 4.0;

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    // Camera — standard 3/4 front view
    camera.setEuler(_cameraYaw, _cameraPitch, 0, distance: _cameraDist);

    // Lighting
    light.color = vm.Vector3(1.0, 0.98, 0.9);
    light.setEuler(pi / 4, pi / 3, 0, distance: 20);
    M3Light.ambient = vm.Vector3(0.25, 0.25, 0.3);

    // Grid (XY plane, Z=0)
    _buildGrid();
  }

  void _buildGrid() {
    final gridGeom = M3PlaneGeom(20, 20, widthSegments: 20, heightSegments: 20);
    final gridMesh = M3Mesh(gridGeom);
    _gridEntity = M3Entity()..mesh = gridMesh;
    _gridEntity!.position = vm.Vector3(0, 0, 0);
    _gridEntity!.color = vm.Vector4(0.12, 0.14, 0.18, 1.0);
    addEntity(_gridEntity!);
  }

  /// Load a GLB model and inject animations from separate animation GLBs.
  Future<void> loadModelFromPath(
    String path,
    List<String> animPaths,
    EditorProvider provider,
  ) async {
    M2MLogger.info('Scene: Loading model from $path');
    if (_modelEntity != null) {
      entities.remove(_modelEntity!);
      _modelEntity = null;
    }
    clearBoneGizmos();

    try {
      final mesh = await M2MEngine.instance.loadMesh(path);
      _modelEntity = M3Entity()..mesh = mesh;
      addEntity(_modelEntity!);

      _fixModelOrientation(_modelEntity!);
      _fitModelInView(_modelEntity!);

      M2MLogger.info('Scene: Model loaded — nodes=${mesh.nodes?.length}, skin=${mesh.skin != null}, animator=${mesh.animator != null}');

      if (animPaths.isNotEmpty) {
        await _loadAndInjectAnimations(mesh, animPaths);
      }

      // Sync hierarchy
      final List<SceneNode> sceneNodes = [
        const SceneNode(id: 'grid', name: 'Grid Floor', type: 'grid'),
        const SceneNode(id: 'camera', name: 'Main Camera', type: 'camera'),
        const SceneNode(id: 'light', name: 'Directional Light', type: 'light'),
      ];
      const modelNodeId = 'model_root';
      sceneNodes.add(SceneNode(
        id: modelNodeId,
        name: provider.state.loadedModelName ?? '3D Model',
        type: 'model',
      ));
      if (mesh.nodes != null) {
        for (final node in mesh.nodes!) {
          if (node.name.isNotEmpty) {
            sceneNodes.add(SceneNode(
              id: node.name,
              name: node.name,
              type: 'bone',
              parentId: modelNodeId,
            ));
          }
        }
      }

      provider.setSceneNodes(sceneNodes);
      provider.clearBusy();
      rebuildBoneGizmos();
    } catch (e, stack) {
      M2MLogger.error('Scene: Error loading model', e, stack);
      provider.clearBusy();
    }
  }

  /// Load animation GLBs and inject by matching bone **names**.
  ///
  /// The key fix: animation channels reference node indices in the *animation
  /// GLB's own* node list, not the model's node list. We match by name and
  /// repoint each channel to the model's nodes so the existing M3Animator
  /// machinery works correctly.
  Future<void> _loadAndInjectAnimations(M3Mesh targetMesh, List<String> animPaths) async {
    if (targetMesh.nodes == null || targetMesh.nodes!.isEmpty) {
      M2MLogger.warning('Scene: Model has no nodes — cannot inject animations');
      return;
    }

    // Build name→node map from the model's actual nodes
    final Map<String, GltfNode> modelNodeByName = {};
    for (final node in targetMesh.nodes!) {
      if (node.name.isNotEmpty) {
        modelNodeByName[node.name] = node;
      }
    }

    final List<GltfAnimation> allAnimations = [];
    final Map<int, GltfNode> unifiedNodeMap = {};

    for (final animPath in animPaths) {
      try {
        M2MLogger.info('Scene: Loading animations from $animPath');
        final buffer = await M2MEngine.instance.loadRawBuffer(animPath);
        final doc = await M3GltfLoader.loadFromBytes(buffer, animPath);

        if (doc.animations.isEmpty) {
          M2MLogger.warning('Scene: No animations in $animPath');
          continue;
        }

        // Build index→modelNode mapping for this animation doc by name-matching
        final Map<int, GltfNode> localMap = {};
        for (int i = 0; i < doc.nodes.length; i++) {
          final animNode = doc.nodes[i];
          final modelNode = modelNodeByName[animNode.name];
          if (modelNode != null) {
            localMap[i] = modelNode;
          }
        }

        // Count matched bones for debugging
        int matchedBones = 0;
        for (final anim in doc.animations) {
          for (final ch in anim.channels) {
            if (ch.targetNodeIndex != null && localMap.containsKey(ch.targetNodeIndex)) {
              matchedBones++;
            }
          }
        }
        M2MLogger.info('Scene: $animPath — ${doc.animations.length} anims, $matchedBones channel-node matches');

        // Re-index: merge localMap offsets into unifiedNodeMap
        // We need a stable key space. We use the model node's hashCode as a
        // synthetic index and rebuild animation channels.
        // Actually the simplest approach: just build a new M3Animator for each
        // doc that uses the localMap, and combine them all.
        // M3Animator takes (animations, nodes) where nodes: Map<int, GltfNode>
        // and indices are the channel's targetNodeIndex values from that doc.
        // So per-doc maps work perfectly — we create one animator that covers
        // all docs by assigning a unique offset per doc.

        final int offset = unifiedNodeMap.isEmpty ? 0 : (unifiedNodeMap.keys.reduce(max) + 1000);
        for (final entry in localMap.entries) {
          unifiedNodeMap[offset + entry.key] = entry.value;
        }

        // Remap animation channel indices to offset space
        for (final anim in doc.animations) {
          final remappedChannels = anim.channels.map((ch) {
            if (ch.targetNodeIndex == null) return ch;
            return GltfAnimationChannel(
              document: ch.document,
              samplerIndex: ch.samplerIndex,
              targetNodeIndex: localMap.containsKey(ch.targetNodeIndex)
                  ? offset + ch.targetNodeIndex!
                  : null, // null = skip this channel (bone not in model)
              targetPath: ch.targetPath,
            );
          }).toList();

          allAnimations.add(GltfAnimation(
            document: anim.document,
            name: anim.name,
            channels: remappedChannels,
            samplers: anim.samplers,
          ));
        }

        M2MLogger.info('Scene: Accumulated ${allAnimations.length} animations so far');
      } catch (e, stack) {
        M2MLogger.error('Scene: Failed to load $animPath', e, stack);
      }
    }

    if (allAnimations.isEmpty) {
      M2MLogger.warning('Scene: No animations injected');
      return;
    }

    targetMesh.animator = M3Animator(allAnimations, unifiedNodeMap);
    targetMesh.animator!.isPlaying = false;

    M2MLogger.info('Scene: Injected ${allAnimations.length} total animations');
    for (int i = 0; i < allAnimations.length; i++) {
      M2MLogger.info('  [$i] ${allAnimations[i].name}');
    }
  }

  /// Detect and correct model orientation.
  ///
  /// macbear_3d uses Z-up. A model exported from Blender with Z-up will be
  /// correct. A model exported with Y-up (e.g. standard glTF) will appear
  /// Fix model orientation.
  ///
  /// All bundled animation GLBs have a -90 deg X rotation baked into the root
  /// bone (quaternion [-0.707, 0, 0, 0.707]). The skeleton already converts
  /// from glTF Y-up geometry space to macbear Z-up world space. We must NOT
  /// apply any additional entity rotation, or the model will be double-rotated
  /// and appear lying flat on its back.
  void _fixModelOrientation(M3Entity entity) {
    // No-op: root bone already handles Y-up to Z-up conversion.
    M2MLogger.info('Scene: Skipping auto-rotation — root bone handles coordinate conversion');
  }

  void _fitModelInView(M3Entity entity) {
    entity.updateBounds();
    final bounds = entity.worldBounding.aabb;
    final size = bounds.max - bounds.min;
    // The raw geometry is in Y-up space (tall in Y before bone rotation).
    // Use the largest dimension across all axes as the height proxy.
    final maxDim = [size.x, size.y, size.z].reduce(max);

    if (maxDim > 0) {
      final scale = 2.0 / maxDim;
      entity.scale = vm.Vector3.all(scale);
      final cx = (bounds.max.x + bounds.min.x) / 2;
      final cy = (bounds.max.y + bounds.min.y) / 2;
      entity.position = vm.Vector3(-cx * scale, -cy * scale, -bounds.min.z * scale);
    }
    M2MLogger.info('Scene: Model fitted to view (scale=${entity.scale.x.toStringAsFixed(3)})');
  }

  void rebuildBoneGizmos() {
    clearBoneGizmos();
    _nodeToGizmo.clear();

    if (!showSkeleton || _modelEntity == null || _modelEntity!.mesh?.nodes == null) return;

    final nodes = _modelEntity!.mesh!.nodes!;
    for (final node in nodes) {
      if (node.name.isEmpty) continue;

      final gizmoGeom = M3SphereGeom(0.015);
      final gizmoMesh = M3Mesh(gizmoGeom);
      final gizmo = M3Entity()..mesh = gizmoMesh;

      final isSelected = (selectedNodeId != null && node.name == selectedNodeId);
      gizmo.color = isSelected
          ? vm.Vector4(1.0, 0.6, 0.0, 1.0)
          : vm.Vector4(0.2, 0.8, 1.0, 0.6);

      _boneGizmos.add(gizmo);
      _nodeToGizmo[node.name] = gizmo;
      addEntity(gizmo);
    }
    _updateGizmoPositions();
  }

  void _updateGizmoPositions() {
    if (_modelEntity == null || _nodeToGizmo.isEmpty) return;
    if (_modelEntity!.mesh?.nodes == null) return;

    for (final node in _modelEntity!.mesh!.nodes!) {
      final gizmo = _nodeToGizmo[node.name];
      if (gizmo == null) continue;

      // node.worldMatrix is the bone's transform in the GLB local space,
      // computed by the animator's _updateHierarchy(). Transform it into
      // world space using the entity's TRS matrix (entity.matrix = compose(pos,rot,scale)).
      final boneLocalPos = node.worldMatrix.getTranslation();
      gizmo.position = _modelEntity!.matrix.transform3(boneLocalPos.clone());
    }
  }

  void clearBoneGizmos() {
    for (final g in _boneGizmos) {
      entities.remove(g);
    }
    _boneGizmos.clear();
    _nodeToGizmo.clear();
  }

  void setActiveAnimation(String? animId) {
    if (activeAnimationId == animId) return;
    activeAnimationId = animId;

    if (_modelEntity != null && _modelEntity!.mesh?.animator != null) {
      final animator = _modelEntity!.mesh!.animator!;

      if (animId != null) {
        int idx = -1;
        final target = animId.toLowerCase();

        for (int i = 0; i < animator.animations.length; i++) {
          if (animator.animations[i].name.toLowerCase() == target) {
            idx = i;
            break;
          }
        }
        if (idx == -1) {
          for (int i = 0; i < animator.animations.length; i++) {
            final n = animator.animations[i].name.toLowerCase();
            if (n.contains(target) || target.contains(n)) {
              idx = i;
              break;
            }
          }
        }

        if (idx != -1) {
          M2MLogger.info('Scene: Playing animation "${animator.animations[idx].name}" (index $idx)');
          animator.play(idx);
          animator.isPlaying = isPlaying;
        } else {
          M2MLogger.warning('Scene: Animation "$animId" not found. Available: ${animator.animations.map((a) => a.name).join(', ')}');
        }
      } else {
        animator.isPlaying = false;
      }
    }
  }

  void updateMaterial(MaterialSettings settings) {
    if (_modelEntity == null) return;
    final c = settings.baseColor;
    _modelEntity!.color = vm.Vector4(
      c.red / 255, c.green / 255, c.blue / 255, c.alpha / 255,
    );
  }

  // ── Camera Controls (Z-up convention) ─────────────────────────────────────

  void orbit(double dx, double dy) {
    // Z-up: yaw = horizontal, pitch = elevation (clamped to avoid gimbal lock)
    _cameraYaw += dx * 0.005;
    _cameraPitch = (_cameraPitch - dy * 0.005).clamp(0.01, pi / 2 - 0.01);
    camera.setEuler(_cameraYaw, _cameraPitch, 0, distance: _cameraDist);
  }

  void zoom(double delta) {
    _cameraDist = (_cameraDist + delta * 0.005).clamp(0.5, 50.0);
    camera.setEuler(_cameraYaw, _cameraPitch, 0, distance: _cameraDist);
  }

  void pan(double dx, double dy) {
    // Pan perpendicular to view direction
    final yawCos = cos(_cameraYaw);
    final yawSin = sin(_cameraYaw);
    final right = vm.Vector3(yawCos, yawSin, 0);    // horizontal right
    final up = vm.Vector3(0, 0, 1);                  // Z-up world up

    final factor = _cameraDist * 0.001;
    camera.target += right * (-dx * factor) + up * (dy * factor);
    camera.setEuler(_cameraYaw, _cameraPitch, 0, distance: _cameraDist);
  }

  void resetCamera() {
    _cameraYaw = pi / 4;
    _cameraPitch = pi / 6;
    _cameraDist = 4.0;
    camera.target = vm.Vector3.zero();
    camera.setEuler(_cameraYaw, _cameraPitch, 0, distance: _cameraDist);
  }

  /// Front view: looking along -Y axis (from +Y toward origin), Z-up
  void setFrontView() {
    _cameraYaw = -pi / 2; // camera at +Y side, looking toward -Y
    _cameraPitch = 0.01;
    camera.setEuler(_cameraYaw, _cameraPitch, 0, distance: _cameraDist);
  }

  /// Side view: looking along -X axis (from +X), Z-up
  void setSideView() {
    _cameraYaw = 0;
    _cameraPitch = 0.01;
    camera.setEuler(_cameraYaw, _cameraPitch, 0, distance: _cameraDist);
  }

  /// Top view: looking straight down along -Z
  void setTopView() {
    _cameraYaw = _cameraYaw; // keep yaw
    _cameraPitch = pi / 2 - 0.01;
    camera.setEuler(_cameraYaw, _cameraPitch, 0, distance: _cameraDist);
  }

  String? pickBone(double screenX, double screenY, double width, double height) {
    if (_nodeToGizmo.isEmpty) return null;
    String? bestId;
    double minDist = 30.0;
    _nodeToGizmo.forEach((name, gizmo) {
      final screenPos = _worldToScreen(gizmo.position, width, height);
      final dist = (Offset(screenX, screenY) - screenPos).distance;
      if (dist < minDist) {
        minDist = dist;
        bestId = name;
      }
    });
    return bestId;
  }

  Offset _worldToScreen(vm.Vector3 worldPos, double width, double height) {
    final viewProj = camera.projectionMatrix * camera.viewMatrix;
    final pos4 = viewProj * vm.Vector4(worldPos.x, worldPos.y, worldPos.z, 1.0);
    if (pos4.w <= 0) return const Offset(-1000, -1000);
    final ndcX = pos4.x / pos4.w;
    final ndcY = pos4.y / pos4.w;
    return Offset((ndcX + 1.0) * 0.5 * width, (1.0 - ndcY) * 0.5 * height);
  }

  @override
  void update(double delta) {
    super.update(delta);

    if (_modelEntity != null) {
      // Sync playback state onto animator BEFORE entity.update() calls it
      final animator = _modelEntity!.mesh?.animator;
      if (animator != null) {
        animator.isPlaying = isPlaying;
        animator.playRate = playbackSpeed;
      }

      // entity.update() handles: animator.update(dt) + skin.update() + bounds dirty
      _modelEntity!.update(delta);

      if (showSkeleton) {
        _updateGizmoPositions();
      }
    }
  }
}