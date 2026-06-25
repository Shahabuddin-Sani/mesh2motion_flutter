import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as dev;

/// A dedicated logger for the Mesh2Motion app to help debug scene and state issues.
class M2MLogger {
  static void info(String message) {
    debugPrint('🔵 [M2M-INFO] $message');
  }

  static void warning(String message) {
    debugPrint('🟠 [M2M-WARN] $message');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('🔴 [M2M-ERROR] $message');
    if (error != null) debugPrint('   Error: $error');
    if (stackTrace != null) dev.log(message, error: error, stackTrace: stackTrace, name: 'M2M-ERROR');
  }

  static void state(String property, dynamic value) {
    debugPrint('🟣 [M2M-STATE] $property → $value');
  }
}

// ─── Skeleton Types ───────────────────────────────────────────────────────────

enum SkeletonType {
  human(
    label: 'Human',
    icon: '👤',
    description: 'Bipedal humanoid character',
    boneCount: 24,
  ),
  quadruped(
    label: 'Quadruped',
    icon: '🐺',
    description: 'Four-legged animal (fox, dog, cat)',
    boneCount: 32,
  ),
  bird(
    label: 'Bird',
    icon: '🦅',
    description: 'Flying creature with wing bones',
    boneCount: 28,
  ),
  dragon(
    label: 'Dragon',
    icon: '🐉',
    description: 'Fantasy creature with wings and tail',
    boneCount: 40,
  );

  const SkeletonType({
    required this.label,
    required this.icon,
    required this.description,
    required this.boneCount,
  });

  final String label;
  final String icon;
  final String description;
  final int boneCount;
}

// ─── Animation Entry ──────────────────────────────────────────────────────────

class AnimationEntry {
  final String id;
  final String name;
  final String category;
  final double durationSecs;
  final List<SkeletonType> compatibleWith;

  const AnimationEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.durationSecs,
    required this.compatibleWith,
  });
}

// ─── Bone Info ────────────────────────────────────────────────────────────────

class BoneInfo {
  final String id;
  final String name;
  final String? parentId;
  bool isSelected;
  bool isVisible;

  BoneInfo({
    required this.id,
    required this.name,
    this.parentId,
    this.isSelected = false,
    this.isVisible = true,
  });
}

// ─── Material Types ───────────────────────────────────────────────────────────
enum M2MMaterialType { pbr, toon }

class MaterialSettings {
  final M2MMaterialType type;
  final Color baseColor;
  final double roughness;
  final double metalness;
  final double toonSteps;
  final bool useRimLight;

  const MaterialSettings({
    this.type = M2MMaterialType.pbr,
    this.baseColor = const Color(0xFFCCCCCC),
    this.roughness = 0.5,
    this.metalness = 0.0,
    this.toonSteps = 3.0,
    this.useRimLight = true,
  });

  MaterialSettings copyWith({
    M2MMaterialType? type,
    Color? baseColor,
    double? roughness,
    double? metalness,
    double? toonSteps,
    bool? useRimLight,
  }) {
    return MaterialSettings(
      type: type ?? this.type,
      baseColor: baseColor ?? this.baseColor,
      roughness: roughness ?? this.roughness,
      metalness: metalness ?? this.metalness,
      toonSteps: toonSteps ?? this.toonSteps,
      useRimLight: useRimLight ?? this.useRimLight,
    );
  }
}

enum EditorTool { select, move, rotate, scale, view }
enum EditorPhase { empty, modelLoaded, skeletonFitted, animated, exported }

class SceneNode {
  final String id;
  final String name;
  final String type; // 'model', 'bone', 'camera', 'light', 'grid'
  final String? parentId;
  final bool isVisible;

  const SceneNode({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    this.isVisible = true,
  });
}

class EditorState {
  final EditorPhase phase;
  final String? loadedModelPath;
  final String? loadedModelName;
  final SkeletonType? selectedSkeleton;
  final AnimationEntry? activeAnimation;
  final EditorTool activeTool;
  final bool showSkeleton;
  final bool showWireframe;
  final bool showBoneLabels;
  final bool isPlaying;
  final double animPlaybackSpeed;
  final double animProgress;
  final List<SceneNode> sceneNodes;
  final String? selectedNodeId;
  final MaterialSettings materialSettings;
  final bool isBusy;
  final String? busyMessage;
  final String? lastExportPath;

  const EditorState({
    this.phase = EditorPhase.empty,
    this.loadedModelPath,
    this.loadedModelName,
    this.selectedSkeleton,
    this.activeAnimation,
    this.activeTool = EditorTool.select,
    this.showSkeleton = true,
    this.showWireframe = false,
    this.showBoneLabels = false,
    this.isPlaying = false,
    this.animPlaybackSpeed = 1.0,
    this.animProgress = 0.0,
    this.sceneNodes = const [
      SceneNode(id: 'grid', name: 'Grid Floor', type: 'grid'),
      SceneNode(id: 'camera', name: 'Main Camera', type: 'camera'),
      SceneNode(id: 'light', name: 'Directional Light', type: 'light'),
    ],
    this.selectedNodeId,
    this.materialSettings = const MaterialSettings(),
    this.isBusy = false,
    this.busyMessage,
    this.lastExportPath,
  });

  EditorState copyWith({
    EditorPhase? phase,
    String? loadedModelPath,
    String? loadedModelName,
    SkeletonType? selectedSkeleton,
    AnimationEntry? activeAnimation,
    EditorTool? activeTool,
    bool? showSkeleton,
    bool? showWireframe,
    bool? showBoneLabels,
    bool? isPlaying,
    double? animPlaybackSpeed,
    double? animProgress,
    List<SceneNode>? sceneNodes,
    String? selectedNodeId,
    MaterialSettings? materialSettings,
    bool isBusy = false,
    String? busyMessage,
    String? lastExportPath,
    bool clearAnimation = false,
    bool clearModel = false,
    bool clearNode = false,
  }) {
    return EditorState(
      phase: phase ?? this.phase,
      loadedModelPath: clearModel ? null : (loadedModelPath ?? this.loadedModelPath),
      loadedModelName: clearModel ? null : (loadedModelName ?? this.loadedModelName),
      selectedSkeleton: selectedSkeleton ?? this.selectedSkeleton,
      activeAnimation: clearAnimation ? null : (activeAnimation ?? this.activeAnimation),
      activeTool: activeTool ?? this.activeTool,
      showSkeleton: showSkeleton ?? this.showSkeleton,
      showWireframe: showWireframe ?? this.showWireframe,
      showBoneLabels: showBoneLabels ?? this.showBoneLabels,
      isPlaying: isPlaying ?? this.isPlaying,
      animPlaybackSpeed: animPlaybackSpeed ?? this.animPlaybackSpeed,
      animProgress: animProgress ?? this.animProgress,
      sceneNodes: sceneNodes ?? this.sceneNodes,
      selectedNodeId: clearNode ? null : (selectedNodeId ?? this.selectedNodeId),
      materialSettings: materialSettings ?? this.materialSettings,
      isBusy: isBusy,
      busyMessage: busyMessage ?? this.busyMessage,
      lastExportPath: lastExportPath ?? this.lastExportPath,
    );
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

class EditorProvider extends ChangeNotifier {
  EditorState _state = const EditorState();
  EditorState get state => _state;

  EditorProvider() {
    M2MLogger.info('EditorProvider initialized');
  }

  void _updateState(EditorState newState) {
    _state = newState;
    notifyListeners();
  }

  void loadModel(String path, String name) {
    M2MLogger.info('Loading model: $name from $path');
    
    // Create hierarchy with a model root and a placeholder for bones
    final newNodes = List<SceneNode>.from(_state.sceneNodes);
    final modelNode = SceneNode(id: 'model_root', name: name, type: 'model');
    newNodes.add(modelNode);
    
    _updateState(_state.copyWith(
      phase: EditorPhase.modelLoaded,
      loadedModelPath: path,
      loadedModelName: name,
      sceneNodes: newNodes,
      selectedNodeId: 'model_root',
      isBusy: false,
    ));
  }

  void setSceneNodes(List<SceneNode> nodes) {
    _updateState(_state.copyWith(sceneNodes: nodes));
  }

  void setBusy(String message) {
    M2MLogger.info('Setting busy: $message');
    _updateState(_state.copyWith(isBusy: true, busyMessage: message));
  }

  void clearBusy() {
    M2MLogger.info('Clearing busy state');
    _updateState(_state.copyWith(isBusy: false, busyMessage: ''));
  }

  void selectSkeleton(SkeletonType type) {
    M2MLogger.info('Selecting skeleton: ${type.label}');
    _updateState(_state.copyWith(
      selectedSkeleton: type,
      phase: _state.phase.index >= EditorPhase.modelLoaded.index
          ? EditorPhase.skeletonFitted
          : _state.phase,
    ));
    M2MLogger.state('skeleton', type.label);
    M2MLogger.state('phase', _state.phase);
  }

  void fitSkeleton() {
    if (_state.selectedSkeleton == null) {
      M2MLogger.warning('Cannot fit skeleton: no skeleton selected');
      return;
    }
    M2MLogger.info('Fitting skeleton to model...');
    _updateState(_state.copyWith(
      phase: EditorPhase.skeletonFitted,
      isBusy: false,
    ));
    M2MLogger.state('phase', _state.phase);
  }

  void setActiveAnimation(AnimationEntry anim) {
    M2MLogger.info('Setting active animation: ${anim.name}');
    _updateState(_state.copyWith(
      activeAnimation: anim,
      phase: EditorPhase.animated,
      isPlaying: true,
    ));
    M2MLogger.state('animation', anim.name);
    M2MLogger.state('phase', _state.phase);
  }

  void togglePlay() {
    M2MLogger.info('Toggling playback: ${!_state.isPlaying}');
    _updateState(_state.copyWith(isPlaying: !_state.isPlaying));
  }

  void setPlaybackSpeed(double speed) {
    M2MLogger.info('Setting playback speed: $speed');
    _updateState(_state.copyWith(animPlaybackSpeed: speed));
  }

  void setAnimProgress(double progress) {
    _updateState(_state.copyWith(animProgress: progress));
  }

  void setTool(EditorTool tool) {
    M2MLogger.info('Setting tool: ${tool.name}');
    _updateState(_state.copyWith(activeTool: tool));
  }

  void toggleSkeleton() {
    M2MLogger.info('Toggling skeleton visibility: ${!_state.showSkeleton}');
    _updateState(_state.copyWith(showSkeleton: !_state.showSkeleton));
  }

  void toggleWireframe() {
    M2MLogger.info('Toggling wireframe visibility: ${!_state.showWireframe}');
    _updateState(_state.copyWith(showWireframe: !_state.showWireframe));
  }

  void toggleBoneLabels() {
    M2MLogger.info('Toggling bone labels visibility: ${!_state.showBoneLabels}');
    _updateState(_state.copyWith(showBoneLabels: !_state.showBoneLabels));
  }

  void selectNode(String? nodeId) {
    M2MLogger.info('Selecting node: $nodeId');
    _updateState(_state.copyWith(selectedNodeId: nodeId));
  }

  void updateMaterial(MaterialSettings settings) {
    M2MLogger.info('Updating material settings');
    _updateState(_state.copyWith(materialSettings: settings));
  }

  void exportGLB(String path) {
    M2MLogger.info('Exporting GLB to: $path');
    _updateState(_state.copyWith(
      phase: EditorPhase.exported,
      lastExportPath: path,
      isBusy: false,
    ));
    M2MLogger.state('phase', _state.phase);
  }

  void reset() {
    M2MLogger.info('Resetting editor state');
    _updateState(const EditorState());
  }
}

// ─── Animation Library Data ───────────────────────────────────────────────────

const List<AnimationEntry> kAnimationLibrary = [
  // Human
  AnimationEntry(id: 'idle',          name: 'Idle',           category: 'Basic',      durationSecs: 3.0,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'walk',          name: 'Walk',           category: 'Locomotion', durationSecs: 1.2,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'run',           name: 'Run',            category: 'Locomotion', durationSecs: 0.8,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'jump',          name: 'Jump',           category: 'Locomotion', durationSecs: 1.5,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'wave',          name: 'Wave',           category: 'Gestures',   durationSecs: 2.0,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'punch',         name: 'Punch',          category: 'Combat',     durationSecs: 0.6,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'kick',          name: 'Kick',           category: 'Combat',     durationSecs: 0.7,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'dance',         name: 'Dance',          category: 'Emotes',     durationSecs: 4.0,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'sit',           name: 'Sit',            category: 'Basic',      durationSecs: 1.0,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'crouch',        name: 'Crouch',         category: 'Locomotion', durationSecs: 0.5,  compatibleWith: [SkeletonType.human]),
  // Quadruped
  AnimationEntry(id: 'q_idle',        name: 'Idle',           category: 'Basic',      durationSecs: 3.0,  compatibleWith: [SkeletonType.quadruped]),
  AnimationEntry(id: 'q_walk',        name: 'Walk',           category: 'Locomotion', durationSecs: 1.0,  compatibleWith: [SkeletonType.quadruped]),
  AnimationEntry(id: 'q_trot',        name: 'Trot',           category: 'Locomotion', durationSecs: 0.8,  compatibleWith: [SkeletonType.quadruped]),
  AnimationEntry(id: 'q_gallop',      name: 'Gallop',         category: 'Locomotion', durationSecs: 0.5,  compatibleWith: [SkeletonType.quadruped]),
  AnimationEntry(id: 'q_sit',         name: 'Sit',            category: 'Basic',      durationSecs: 1.5,  compatibleWith: [SkeletonType.quadruped]),
  AnimationEntry(id: 'q_attack',      name: 'Attack',         category: 'Combat',     durationSecs: 0.8,  compatibleWith: [SkeletonType.quadruped]),
  // Bird
  AnimationEntry(id: 'b_idle',        name: 'Idle',           category: 'Basic',      durationSecs: 2.0,  compatibleWith: [SkeletonType.bird]),
  AnimationEntry(id: 'b_flap',        name: 'Flap',           category: 'Locomotion', durationSecs: 0.6,  compatibleWith: [SkeletonType.bird]),
  AnimationEntry(id: 'b_glide',       name: 'Glide',          category: 'Locomotion', durationSecs: 3.0,  compatibleWith: [SkeletonType.bird]),
  AnimationEntry(id: 'b_land',        name: 'Land',           category: 'Basic',      durationSecs: 1.2,  compatibleWith: [SkeletonType.bird]),
  // Dragon
  AnimationEntry(id: 'd_idle',        name: 'Idle',           category: 'Basic',      durationSecs: 4.0,  compatibleWith: [SkeletonType.dragon]),
  AnimationEntry(id: 'd_walk',        name: 'Walk',           category: 'Locomotion', durationSecs: 1.2,  compatibleWith: [SkeletonType.dragon]),
  AnimationEntry(id: 'd_fly',         name: 'Fly',            category: 'Locomotion', durationSecs: 1.0,  compatibleWith: [SkeletonType.dragon]),
  AnimationEntry(id: 'd_roar',        name: 'Roar',           category: 'Emotes',     durationSecs: 2.5,  compatibleWith: [SkeletonType.dragon]),
  AnimationEntry(id: 'd_breathe',     name: 'Breathe Fire',   category: 'Combat',     durationSecs: 2.0,  compatibleWith: [SkeletonType.dragon]),
  AnimationEntry(id: 'd_land',        name: 'Land',           category: 'Basic',      durationSecs: 2.0,  compatibleWith: [SkeletonType.dragon]),
];
