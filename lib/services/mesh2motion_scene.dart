import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/foundation.dart';
import 'package:macbear_3d/macbear_3d.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../models/editor_state.dart';
import '../engine/m2m_engine.dart';

// ignore: implementation_imports
import 'package:macbear_3d/src/gltf/gltf_parser.dart';

/// The main 3D scene that renders the loaded model, skeleton overlay,
/// and handles viewport camera interaction.
class Mesh2MotionScene extends M3Scene {
  // Current model entity
  M3Entity? _modelEntity;
  M3Entity? get modelEntity => _modelEntity;

  // Skeleton bone gizmos
  final List<M3Entity> _boneGizmos = [];
  final Map<String, M3Entity> _nodeToGizmo = {};

  // Grid floor
  M3Entity? _gridEntity;

  // Camera entity (visual representation)
  M3Entity? _cameraGizmo;

  // State refs
  bool showSkeleton = true;
  bool showWireframe = false;
  SkeletonType? skeletonType;
  String? activeAnimationId;
  bool isPlaying = false;
  double playbackSpeed = 1.0;
  List<BoneInfo> bones = [];
  String? selectedNodeId;
  bool showBoneLabels = false;

  // Camera state tracking
  double _cameraPitch = pi / 8;
  double _cameraYaw = -pi / 6;
  double _cameraDist = 5.0;

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    // ─── Camera ───────────────────────────────────────────────────────────────
    camera.setEuler(_cameraPitch, _cameraYaw, 0, distance: _cameraDist);

    // ─── Lighting ─────────────────────────────────────────────────────────────
    light.color = vm.Vector3(1.0, 0.98, 0.9); 
    light.setEuler(pi / 4, -pi / 4, 0, distance: 20);
    
    M3Light.ambient = vm.Vector3(0.25, 0.25, 0.3);

    // ─── Grid Floor ───────────────────────────────────────────────────────────
    _buildGrid();
    
    // ─── Camera Gizmo ─────────────────────────────────────────────────────────
    _buildCameraGizmo();
  }

  void _buildGrid() {
    final gridGeom = M3PlaneGeom(20, 20, widthSegments: 20, heightSegments: 20);
    final gridMesh = M3Mesh(gridGeom);
    _gridEntity = M3Entity()..mesh = gridMesh;
    _gridEntity!.position = vm.Vector3(0, 0, 0);
    _gridEntity!.color = vm.Vector4(0.1, 0.12, 0.15, 1.0);
    addEntity(_gridEntity!);
  }

  void _buildCameraGizmo() {
    final camGeom = M3BoxGeom(0.2, 0.2, 0.4);
    final camMesh = M3Mesh(camGeom);
    _cameraGizmo = M3Entity()..mesh = camMesh;
    _cameraGizmo!.color = vm.Vector4(1.0, 1.0, 0.0, 0.8);
    // Note: M3Entity visibility is usually handled by presence in scene,
    // but if it has a visible flag, we use it. If not, we'll just not add it yet.
    // _cameraGizmo!.isVisible = false; 
    addEntity(_cameraGizmo!);
  }

  /// Load a GLB/glTF model from [path].
  Future<void> loadModelFromPath(String path, EditorProvider provider) async {
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
      
      M2MLogger.info('Scene: Model loaded with ${mesh.nodes?.length ?? 0} nodes');
      
      // Sync hierarchy with provider
      final List<SceneNode> sceneNodes = [
        const SceneNode(id: 'grid', name: 'Grid Floor', type: 'grid'),
        const SceneNode(id: 'camera', name: 'Main Camera', type: 'camera'),
        const SceneNode(id: 'light', name: 'Directional Light', type: 'light'),
      ];

      final modelNodeId = 'model_root';
      sceneNodes.add(SceneNode(id: modelNodeId, name: '3D Model', type: 'model'));

      if (mesh.nodes != null) {
        for (final node in mesh.nodes!) {
          sceneNodes.add(SceneNode(
            id: node.name,
            name: node.name,
            type: 'bone',
            parentId: modelNodeId, // Flatten for now since GltfNode lacks parent ref
          ));
        }
      }
      
      provider.setSceneNodes(sceneNodes);
      
      // Initially rebuild gizmos if skeleton is enabled
      rebuildBoneGizmos();
    } catch (e, stack) {
      M2MLogger.error('Scene: Error loading model', e, stack);
    }
  }

  void _fixModelOrientation(M3Entity entity) {
    // GLTF is Y-up. If the model appears lying down, we rotate it.
    // User wants it standing on Z axis? Usually that means Z is up.
    // But macbear_3d is Y-up. So "standing" should be along Y.
    
    entity.updateBounds();
    final size = entity.worldBounding.aabb.max - entity.worldBounding.aabb.min;
    
    // If Z is significantly larger than Y, it's likely a Z-up model lying on its back
    if (size.z > size.y * 1.2) {
      M2MLogger.info('Scene: Detected Z-up model, auto-rotating to Y-up');
      entity.matrix.setRotationX(-pi / 2);
    }
  }

  void _fitModelInView(M3Entity entity) {
    entity.updateBounds();
    final bounds = entity.worldBounding.aabb;
    final size = bounds.max - bounds.min;
    final maxDim = [size.x, size.y, size.z].reduce(max);
    
    if (maxDim > 0) {
      final scale = 2.0 / maxDim;
      entity.scale = vm.Vector3.all(scale);
      
      final center = (bounds.max + bounds.min) / 2;
      // Position on the grid floor (Y=0)
      entity.position = vm.Vector3(-center.x * scale, -bounds.min.y * scale, -center.z * scale);
    }
  }

  /// Build bone gizmo spheres overlaid on the skeleton.
  void rebuildBoneGizmos() {
    clearBoneGizmos();
    _nodeToGizmo.clear();
    
    if (!showSkeleton || _modelEntity == null || _modelEntity!.mesh?.nodes == null) return;

    final nodes = _modelEntity!.mesh!.nodes!;
    for (final node in nodes) {
      // Only create gizmos for nodes that look like bones or are explicitly in the skeleton
      final name = node.name.toLowerCase();
      bool isBone = name.contains('bone') || 
                   name.contains('joint') || 
                   bones.any((b) => b.name.toLowerCase() == name || b.id.toLowerCase() == name);
      
      if (!isBone && nodes.length > 50) continue; // Optimization: don't show everything if too many nodes

      final gizmoGeom = M3SphereGeom(0.015);
      final gizmoMesh = M3Mesh(gizmoGeom);
      final gizmo = M3Entity()..mesh = gizmoMesh;
      
      final isSelected = (selectedNodeId != null && 
                         (name == selectedNodeId!.toLowerCase() || node.name == selectedNodeId));
      
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

    final modelMatrix = _modelEntity!.matrix;
    final modelScale = _modelEntity!.scale.x;
    final modelPos = _modelEntity!.position;

    for (final node in _modelEntity!.mesh!.nodes!) {
      final gizmo = _nodeToGizmo[node.name];
      if (gizmo == null) continue;

      // Calculate world position of node
      final vm.Matrix4 nodeWorldMatrix = _getNodeWorldMatrix(node);
      final worldPos = (nodeWorldMatrix * vm.Vector4(0, 0, 0, 1.0)).xyz;
      
      // Apply model-level transform
      gizmo.position = modelPos + (modelMatrix.getRotation() * worldPos) * modelScale;
    }
  }

  vm.Matrix4 _getNodeWorldMatrix(GltfNode node) {
    final vm.Matrix4 m = vm.Matrix4.identity();
    if (node.matrix != null) {
      final vm.Matrix4 nodeMat = vm.Matrix4.fromList(node.matrix!.storage);
      m.multiply(nodeMat);
    } else {
      m.setFrom(vm.Matrix4.compose(node.translation, node.rotation, node.scale));
    }
      
    final vm.Matrix4 world = vm.Matrix4.fromList(_modelEntity!.matrix.storage);
    world.multiply(m);
      
    return world;
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
          final animName = animator.animations[i].name.toLowerCase();
          if (animName == target || animName.contains(target) || target.contains(animName)) {
            idx = i;
            break;
          }
        }
        
        if (idx != -1) {
          M2MLogger.info('Scene: Playing animation "$animId" (index $idx)');
          animator.play(idx);
          animator.isPlaying = true;
        }
      } else {
        animator.isPlaying = false;
      }
    }
  }

  void updateWireframe(bool value) {
    showWireframe = value;
    // Wireframe support depends on macbear_3d rendering implementation
  }

  void updateMaterial(MaterialSettings settings) {
    if (_modelEntity == null) return;
    final c = settings.baseColor;
    _modelEntity!.color = vm.Vector4(c.r, c.g, c.b, c.a);
  }

  // ─── Camera Controls ───────────────────────────────────────────────────────

  void orbit(double dx, double dy) {
    _cameraPitch = (_cameraPitch + dy * 0.005).clamp(-pi / 2 + 0.1, pi / 2 - 0.1);
    _cameraYaw += dx * 0.005;
    camera.setEuler(_cameraPitch, _cameraYaw, 0, distance: _cameraDist);
    _updateCameraGizmo();
  }

  void zoom(double delta) {
    _cameraDist = (_cameraDist + delta * 0.005).clamp(0.5, 50.0);
    camera.setEuler(_cameraPitch, _cameraYaw, 0, distance: _cameraDist);
    _updateCameraGizmo();
  }

  void pan(double dx, double dy) {
    final right = vm.Vector3(cos(_cameraYaw), 0, -sin(_cameraYaw));
    final up = vm.Vector3(0, 1, 0);
    
    final factor = _cameraDist * 0.001;
    camera.target += right * (-dx * factor) + up * (dy * factor);
    camera.setEuler(_cameraPitch, _cameraYaw, 0, distance: _cameraDist);
    _updateCameraGizmo();
  }

  void _updateCameraGizmo() {
    if (_cameraGizmo == null) return;
    // Position gizmo at camera eye
    final eye = camera.target + (vm.Vector3(
      _cameraDist * cos(_cameraPitch) * sin(_cameraYaw),
      _cameraDist * sin(_cameraPitch),
      _cameraDist * cos(_cameraPitch) * cos(_cameraYaw),
    ));
    _cameraGizmo!.position = eye;
    // _cameraGizmo!.lookAt(camera.target); // If lookAt existed
  }

  void resetCamera() {
    _cameraPitch = pi / 8;
    _cameraYaw = -pi / 6;
    _cameraDist = 5.0;
    camera.target = vm.Vector3.zero();
    camera.setEuler(_cameraPitch, _cameraYaw, 0, distance: _cameraDist);
    _updateCameraGizmo();
  }

  void setTopView() {
    _cameraPitch = pi / 2 - 0.01;
    _cameraYaw = 0;
    camera.setEuler(_cameraPitch, _cameraYaw, 0, distance: _cameraDist);
    _updateCameraGizmo();
  }

  void setSideView() {
    _cameraPitch = 0;
    _cameraYaw = pi / 2;
    camera.setEuler(_cameraPitch, _cameraYaw, 0, distance: _cameraDist);
    _updateCameraGizmo();
  }

  void setFrontView() {
    _cameraPitch = 0;
    _cameraYaw = 0;
    camera.setEuler(_cameraPitch, _cameraYaw, 0, distance: _cameraDist);
    _updateCameraGizmo();
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
    final ndc = vm.Vector3(pos4.x / pos4.w, pos4.y / pos4.w, pos4.z / pos4.w);
    return Offset((ndc.x + 1.0) * 0.5 * width, (1.0 - ndc.y) * 0.5 * height);
  }

  @override
  void update(double delta) {
    super.update(delta);
    if (_modelEntity != null) {
      _modelEntity!.update(delta);
      
      final animator = _modelEntity!.mesh?.animator;
      if (animator != null) {
        animator.isPlaying = isPlaying;
        animator.playRate = playbackSpeed;
        if (isPlaying) {
          animator.update(delta);
        }
      }
      
      if (showSkeleton) {
        _updateGizmoPositions();
      }
    }
  }
}