import 'dart:typed_data';
import 'package:flutter/material.dart' hide Matrix4;
import 'package:macbear_3d/macbear_3d.dart';
import 'package:vector_math/vector_math.dart';
import 'm2m_resources.dart';
import '../models/editor_state.dart';

// Internal macbear_3d imports for native model loading
// ignore: implementation_imports
import 'package:macbear_3d/src/mesh/obj_loader.dart';
// ignore: implementation_imports
import 'package:macbear_3d/src/gltf/gltf_loader.dart';
// ignore: implementation_imports
import 'package:macbear_3d/src/gltf/gltf_parser.dart';
// ignore: implementation_imports
import 'package:macbear_3d/src/mesh/animator.dart';

/// The native Mesh2Motion engine that wraps and extends macbear_3d's AppEngine.
class M2MEngine extends ChangeNotifier {
  static final M2MEngine instance = M2MEngine._internal();
  M2MEngine._internal();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  M3Scene? _currentScene;
  M3Scene? get currentScene => _currentScene;

  /// The underlying macbear_3d engine instance
  M3AppEngine get core => M3AppEngine.instance;

  /// Initialize the engine
  Future<void> initialize({required int width, required int height, required double dpr}) async {
    if (_initialized) return;

    M2MLogger.info('Engine: Initializing ($width x $height @ $dpr)');
    await core.initApp(width: width, height: height, dpr: dpr);
    
    _initialized = true;
    M2MLogger.info('Engine: Initialized');
    notifyListeners();
  }

  /// Sets the active scene
  Future<void> setScene(M3Scene scene) async {
    M2MLogger.info('Engine: Setting active scene: ${scene.runtimeType}');
    _currentScene = scene;
    await core.setScene(scene);
    notifyListeners();
  }

  /// Load a model from a path (asset, URL, or registered memory buffer).
  /// Returns the constructed M3Mesh.
  Future<M3Mesh> loadMesh(String path) async {
    M2MLogger.info('Engine: Loading mesh from $path');
    
    try {
      final bytes = await loadRawBuffer(path);
      
      final ext = path.split('.').last.toLowerCase().split('?').first;
      
      if (ext == 'obj') {
        final geom = M3ObjLoader.parse(String.fromCharCodes(bytes), path);
        return M3Mesh(geom);
      } else if (ext == 'gltf' || ext == 'glb') {
        final doc = await M3GltfLoader.loadFromBytes(bytes, path);
        return _constructMeshFromDoc(doc);
      } else {
        throw UnsupportedError('Unsupported model format: $ext');
      }
    } catch (e, stack) {
      M2MLogger.error('Engine: Failed to load mesh from $path', e, stack);
      rethrow;
    }
  }

  /// Load raw bytes from a path (asset, URL, or memory buffer).
  Future<Uint8List> loadRawBuffer(String path) async {
    final buf = await M2MResourceManager.instance.loadBuffer(path);
    return buf.asUint8List();
  }

  /// Helper to construct M3Mesh from GltfDocument.
  M3Mesh _constructMeshFromDoc(GltfDocument doc) {
    final List<M3SubMesh> primitives = [];
    if (doc.meshes.isNotEmpty) {
      final gltfMesh = doc.meshes[0];
      for (final primitive in gltfMesh.primitives) {
        final geom = M3GltfGeom.fromPrimitive(primitive);
        M3Material? mtr;
        if (primitive.materialIndex != null && primitive.materialIndex! < doc.materials.length) {
          mtr = M3Material.fromGltf(doc.materials[primitive.materialIndex!], doc);
        }
        primitives.add(M3SubMesh(geom, material: mtr));
      }
    }

    M3Skin? skin;
    int? skinIndex;
    Matrix4 matNode = Matrix4.identity();

    for (final node in doc.nodes) {
      if (node.meshIndex == 0) {
        if (node.skinIndex != null) skinIndex = node.skinIndex;
        if (node.matrix != null) {
          matNode.setFrom(node.matrix!);
        } else {
          matNode.setFrom(Matrix4.compose(node.translation, node.rotation, node.scale));
        }
        break;
      }
    }

    if (skinIndex != null && skinIndex < doc.skins.length) {
      final gltfSkin = doc.skins[skinIndex];
      final ibm = gltfSkin.getInverseBindMatrices();
      final List<Matrix4>? inverseMatrices = ibm != null
          ? List.generate(gltfSkin.joints.length, (i) {
              return Matrix4.fromFloat32List(ibm.sublist(i * 16, i * 16 + 16));
            })
          : null;

      skin = M3Skin(
        gltfSkin.joints.length,
        inverseBindMatrices: inverseMatrices,
        jointNodes: gltfSkin.joints.map<GltfNode>((index) => doc.nodes[index] as GltfNode).toList(),
      );
    }

    final mesh = M3Mesh(null, skin: skin);
    mesh.subMeshes = primitives;
    mesh.initMatrix.setFrom(matNode);
    mesh.nodes = doc.nodes.cast<GltfNode>();

    // Bake in any animations that are already in the model GLB
    if (doc.animations.isNotEmpty) {
      final nodeMap = {for (int i = 0; i < doc.nodes.length; i++) i: doc.nodes[i] as GltfNode};
      mesh.animator = M3Animator(doc.animations.cast<GltfAnimation>(), nodeMap);
      mesh.animator!.isPlaying = false;
      M2MLogger.info('Engine: Model has ${doc.animations.length} built-in animations');
    }

    return mesh;
  }
}
