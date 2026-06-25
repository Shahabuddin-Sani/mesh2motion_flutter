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
    label: 'Fox / 4-Leg',
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
  ),
  kaiju(
    label: 'Kaiju',
    icon: '👾',
    description: 'Giant monster creature',
    boneCount: 36,
  ),
  spider(
    label: 'Spider',
    icon: '🕷️',
    description: 'Eight-legged creature',
    boneCount: 32,
  ),
  snake(
    label: 'Snake',
    icon: '🐍',
    description: 'Limbless serpentine creature',
    boneCount: 28,
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

/// Maps each skeleton type to its bundled asset GLB paths.
/// animGlbs lists all animation GLBs to load for that skeleton.
class SkeletonAssets {
  final String modelGlb;
  final List<String> animGlbs;
  const SkeletonAssets({required this.modelGlb, required this.animGlbs});
}

const Map<SkeletonType, SkeletonAssets> kSkeletonAssets = {
  SkeletonType.human: SkeletonAssets(
    modelGlb: 'assets/models/model-human.glb',
    animGlbs: [
      'assets/animations/human-base-animations.glb',
      'assets/animations/human-addon-animations.glb',
    ],
  ),
  SkeletonType.quadruped: SkeletonAssets(
    modelGlb: 'assets/models/model-fox.glb',
    animGlbs: ['assets/animations/fox-animations.glb'],
  ),
  SkeletonType.bird: SkeletonAssets(
    modelGlb: 'assets/models/model-bird.glb',
    animGlbs: ['assets/animations/bird-animations.glb'],
  ),
  SkeletonType.dragon: SkeletonAssets(
    modelGlb: 'assets/models/model-dragon.glb',
    animGlbs: ['assets/animations/dragon-animations.glb'],
  ),
  SkeletonType.kaiju: SkeletonAssets(
    modelGlb: 'assets/models/model-kaiju.glb',
    animGlbs: ['assets/animations/kaiju-animations.glb'],
  ),
  SkeletonType.spider: SkeletonAssets(
    modelGlb: 'assets/models/model-spider.glb',
    animGlbs: ['assets/animations/spider-animations.glb'],
  ),
  SkeletonType.snake: SkeletonAssets(
    modelGlb: 'assets/models/model-snake.glb',
    animGlbs: ['assets/animations/snake-animations.glb'],
  ),
};

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
    bool clearSkeleton = false,
  }) {
    return EditorState(
      phase: phase ?? this.phase,
      loadedModelPath: clearModel ? null : (loadedModelPath ?? this.loadedModelPath),
      loadedModelName: clearModel ? null : (loadedModelName ?? this.loadedModelName),
      selectedSkeleton: clearSkeleton ? null : (selectedSkeleton ?? this.selectedSkeleton),
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
    
    final newNodes = List<SceneNode>.from(_state.sceneNodes
        .where((n) => n.type != 'model' && n.type != 'bone'));
    final modelNode = SceneNode(id: 'model_root', name: name, type: 'model');
    newNodes.add(modelNode);
    
    _updateState(_state.copyWith(
      phase: EditorPhase.modelLoaded,
      loadedModelPath: path,
      loadedModelName: name,
      sceneNodes: newNodes,
      selectedNodeId: 'model_root',
      isBusy: false,
      clearAnimation: true,
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

  /// Select a skeleton type. This triggers loading the bundled mannequin model
  /// for that skeleton type (handled by EditorScreen listener).
  void selectSkeleton(SkeletonType type) {
    M2MLogger.info('Selecting skeleton: ${type.label}');
    final assets = kSkeletonAssets[type]!;
    final modelName = _skeletonDisplayName(type);
    
    // Update the scene nodes to reflect the new model
    final baseNodes = [
      const SceneNode(id: 'grid', name: 'Grid Floor', type: 'grid'),
      const SceneNode(id: 'camera', name: 'Main Camera', type: 'camera'),
      const SceneNode(id: 'light', name: 'Directional Light', type: 'light'),
      SceneNode(id: 'model_root', name: modelName, type: 'model'),
    ];

    _updateState(_state.copyWith(
      selectedSkeleton: type,
      loadedModelPath: assets.modelGlb,
      loadedModelName: modelName,
      phase: EditorPhase.skeletonFitted,
      sceneNodes: baseNodes,
      selectedNodeId: 'model_root',
      clearAnimation: true,
      isBusy: true,
      busyMessage: 'Loading ${type.label} skeleton…',
    ));
    M2MLogger.state('skeleton', type.label);
  }

  String _skeletonDisplayName(SkeletonType type) {
    switch (type) {
      case SkeletonType.human: return 'Mannequin';
      case SkeletonType.quadruped: return 'Fox';
      case SkeletonType.bird: return 'Bird';
      case SkeletonType.dragon: return 'Dragon';
      case SkeletonType.kaiju: return 'Kaiju';
      case SkeletonType.spider: return 'Spider';
      case SkeletonType.snake: return 'Snake';
    }
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
// Animation names match what is stored in the bundled GLB files.
// The 'id' is used to look up the animation by name in the GLB animator.

const List<AnimationEntry> kAnimationLibrary = [
  // ── Human – base animations ─────────────────────────────────────────────
  AnimationEntry(id: 'Idle_Loop',           name: 'Idle',               category: 'Basic',      durationSecs: 3.0,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Sitting_Idle_Loop',   name: 'Sit',                category: 'Basic',      durationSecs: 1.5,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Crouch_Idle_Loop',    name: 'Crouch Idle',        category: 'Basic',      durationSecs: 2.0,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Jump_Start',          name: 'Jump Start',         category: 'Basic',      durationSecs: 0.5,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Jump_Loop',           name: 'Jump Loop',          category: 'Basic',      durationSecs: 0.8,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Jump_Land',           name: 'Land',               category: 'Basic',      durationSecs: 1.2,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Walk_Loop',           name: 'Walk',               category: 'Locomotion', durationSecs: 1.2,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Jog_Fwd_Loop',        name: 'Jog',                category: 'Locomotion', durationSecs: 0.8,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Sprint_Loop',         name: 'Sprint',             category: 'Locomotion', durationSecs: 0.6,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Crouch_Fwd_Loop',     name: 'Crouch Walk',        category: 'Locomotion', durationSecs: 1.5,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Roll',                name: 'Roll',               category: 'Locomotion', durationSecs: 0.9,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Punch_Jab',           name: 'Jab',                category: 'Combat',     durationSecs: 0.4,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Punch_Cross',         name: 'Cross',              category: 'Combat',     durationSecs: 0.5,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Melee_Hook',          name: 'Hook',               category: 'Combat',     durationSecs: 0.6,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Sword_Attack',        name: 'Sword Attack',       category: 'Combat',     durationSecs: 0.8,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Sword_Block',         name: 'Sword Block',        category: 'Combat',     durationSecs: 0.6,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Pistol_Shoot',        name: 'Shoot',              category: 'Combat',     durationSecs: 0.5,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Death01',             name: 'Death',              category: 'Combat',     durationSecs: 2.0,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Hit_Chest',           name: 'Hit Chest',          category: 'Combat',     durationSecs: 0.5,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Dance_Loop',          name: 'Dance',              category: 'Emotes',     durationSecs: 4.0,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Greeting',            name: 'Wave',               category: 'Emotes',     durationSecs: 2.0,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Bow',                 name: 'Bow',                category: 'Emotes',     durationSecs: 1.5,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Victory',             name: 'Victory',            category: 'Emotes',     durationSecs: 2.0,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Angry',              name: 'Angry',               category: 'Emotes',     durationSecs: 2.0,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Idle_Talking_Loop',   name: 'Talk',               category: 'Emotes',     durationSecs: 3.0,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Meditate',            name: 'Meditate',           category: 'Emotes',     durationSecs: 3.0,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Sleeping',            name: 'Sleeping',           category: 'Emotes',     durationSecs: 5.0,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Tired',              name: 'Tired',               category: 'Emotes',     durationSecs: 2.0,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Swim_Fwd_Loop',       name: 'Swim',               category: 'Special',    durationSecs: 1.5,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Levitate Idle',       name: 'Levitate',           category: 'Special',    durationSecs: 2.0,  compatibleWith: [SkeletonType.human]),
  AnimationEntry(id: 'Backflip',           name: 'Backflip',            category: 'Special',    durationSecs: 1.2,  compatibleWith: [SkeletonType.human]),

  // ── Fox / Quadruped ─────────────────────────────────────────────────────
  AnimationEntry(id: 'Idle',               name: 'Idle',                category: 'Basic',      durationSecs: 3.0,  compatibleWith: [SkeletonType.quadruped]),
  AnimationEntry(id: 'Sit',               name: 'Sit',                  category: 'Basic',      durationSecs: 1.5,  compatibleWith: [SkeletonType.quadruped]),
  AnimationEntry(id: 'Walk',              name: 'Walk',                  category: 'Locomotion', durationSecs: 1.0,  compatibleWith: [SkeletonType.quadruped]),
  AnimationEntry(id: 'Run',               name: 'Run',                   category: 'Locomotion', durationSecs: 0.6,  compatibleWith: [SkeletonType.quadruped]),
  AnimationEntry(id: 'Jump',              name: 'Jump',                  category: 'Locomotion', durationSecs: 1.5,  compatibleWith: [SkeletonType.quadruped]),
  AnimationEntry(id: 'Trot',              name: 'Trot',                  category: 'Locomotion', durationSecs: 0.8,  compatibleWith: [SkeletonType.quadruped]),
  AnimationEntry(id: 'Gallop',            name: 'Gallop',                category: 'Locomotion', durationSecs: 0.5,  compatibleWith: [SkeletonType.quadruped]),
  AnimationEntry(id: 'Bark',              name: 'Bark',                  category: 'Emotes',     durationSecs: 1.0,  compatibleWith: [SkeletonType.quadruped]),
  AnimationEntry(id: 'Howl',              name: 'Howl',                  category: 'Emotes',     durationSecs: 2.5,  compatibleWith: [SkeletonType.quadruped]),
  AnimationEntry(id: 'Death',             name: 'Death',                 category: 'Combat',     durationSecs: 2.0,  compatibleWith: [SkeletonType.quadruped]),
  AnimationEntry(id: 'Bite',              name: 'Bite',                  category: 'Combat',     durationSecs: 0.8,  compatibleWith: [SkeletonType.quadruped]),

  // ── Bird ────────────────────────────────────────────────────────────────
  AnimationEntry(id: 'Idle',              name: 'Idle',                  category: 'Basic',      durationSecs: 2.0,  compatibleWith: [SkeletonType.bird]),
  AnimationEntry(id: 'Rest Pose',         name: 'Rest',                  category: 'Basic',      durationSecs: 1.0,  compatibleWith: [SkeletonType.bird]),
  AnimationEntry(id: 'Walk',              name: 'Walk',                  category: 'Locomotion', durationSecs: 1.0,  compatibleWith: [SkeletonType.bird]),
  AnimationEntry(id: 'Flap',             name: 'Flap',                   category: 'Locomotion', durationSecs: 0.6,  compatibleWith: [SkeletonType.bird]),
  AnimationEntry(id: 'Glide',            name: 'Glide',                  category: 'Locomotion', durationSecs: 3.0,  compatibleWith: [SkeletonType.bird]),
  AnimationEntry(id: 'Death',            name: 'Death',                  category: 'Combat',     durationSecs: 1.5,  compatibleWith: [SkeletonType.bird]),

  // ── Dragon ──────────────────────────────────────────────────────────────
  AnimationEntry(id: 'Idle',             name: 'Idle',                   category: 'Basic',      durationSecs: 4.0,  compatibleWith: [SkeletonType.dragon]),
  AnimationEntry(id: 'Rest Pose',        name: 'Rest',                   category: 'Basic',      durationSecs: 1.0,  compatibleWith: [SkeletonType.dragon]),
  AnimationEntry(id: 'Walk',             name: 'Walk',                   category: 'Locomotion', durationSecs: 1.2,  compatibleWith: [SkeletonType.dragon]),
  AnimationEntry(id: 'Fly Flap',         name: 'Fly Flap',               category: 'Locomotion', durationSecs: 1.0,  compatibleWith: [SkeletonType.dragon]),
  AnimationEntry(id: 'Fly Glide',        name: 'Fly Glide',              category: 'Locomotion', durationSecs: 3.0,  compatibleWith: [SkeletonType.dragon]),

  // ── Kaiju ───────────────────────────────────────────────────────────────
  AnimationEntry(id: 'Idle',             name: 'Idle',                   category: 'Basic',      durationSecs: 4.0,  compatibleWith: [SkeletonType.kaiju]),
  AnimationEntry(id: 'Walk',             name: 'Walk',                   category: 'Locomotion', durationSecs: 1.5,  compatibleWith: [SkeletonType.kaiju]),
  AnimationEntry(id: 'Attack',           name: 'Attack',                 category: 'Combat',     durationSecs: 1.5,  compatibleWith: [SkeletonType.kaiju]),
  AnimationEntry(id: 'Roar',             name: 'Roar',                   category: 'Emotes',     durationSecs: 2.5,  compatibleWith: [SkeletonType.kaiju]),
  AnimationEntry(id: 'Death',            name: 'Death',                  category: 'Combat',     durationSecs: 2.5,  compatibleWith: [SkeletonType.kaiju]),
  AnimationEntry(id: 'Hit',              name: 'Hit',                    category: 'Combat',     durationSecs: 0.5,  compatibleWith: [SkeletonType.kaiju]),

  // ── Spider ──────────────────────────────────────────────────────────────
  AnimationEntry(id: 'Idle',             name: 'Idle',                   category: 'Basic',      durationSecs: 2.0,  compatibleWith: [SkeletonType.spider]),
  AnimationEntry(id: 'Walk',             name: 'Walk',                   category: 'Locomotion', durationSecs: 0.8,  compatibleWith: [SkeletonType.spider]),
  AnimationEntry(id: 'Jump',             name: 'Jump',                   category: 'Locomotion', durationSecs: 1.2,  compatibleWith: [SkeletonType.spider]),
  AnimationEntry(id: 'Attack',           name: 'Attack',                 category: 'Combat',     durationSecs: 0.8,  compatibleWith: [SkeletonType.spider]),
  AnimationEntry(id: 'Bite',             name: 'Bite',                   category: 'Combat',     durationSecs: 0.6,  compatibleWith: [SkeletonType.spider]),
  AnimationEntry(id: 'Death',            name: 'Death',                  category: 'Combat',     durationSecs: 2.0,  compatibleWith: [SkeletonType.spider]),

  // ── Snake ───────────────────────────────────────────────────────────────
  AnimationEntry(id: 'Idle',             name: 'Idle',                   category: 'Basic',      durationSecs: 3.0,  compatibleWith: [SkeletonType.snake]),
  AnimationEntry(id: 'Coiled',           name: 'Coiled',                 category: 'Basic',      durationSecs: 2.0,  compatibleWith: [SkeletonType.snake]),
  AnimationEntry(id: 'Side winding',     name: 'Sidewind',               category: 'Locomotion', durationSecs: 1.5,  compatibleWith: [SkeletonType.snake]),
  AnimationEntry(id: 'Bite',             name: 'Bite',                   category: 'Combat',     durationSecs: 0.6,  compatibleWith: [SkeletonType.snake]),
  AnimationEntry(id: 'Death',            name: 'Death',                  category: 'Combat',     durationSecs: 2.0,  compatibleWith: [SkeletonType.snake]),
  AnimationEntry(id: 'Dance',            name: 'Dance',                  category: 'Emotes',     durationSecs: 3.0,  compatibleWith: [SkeletonType.snake]),
];
