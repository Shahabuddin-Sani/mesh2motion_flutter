import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/editor_state.dart';
import '../theme/app_theme.dart';
import '../widgets/top_toolbar.dart';
import '../widgets/left_panel.dart';
import '../widgets/right_panel.dart';
import '../widgets/bottom_timeline.dart';
import '../widgets/viewport_overlay.dart';
import '../widgets/busy_overlay.dart';
import '../services/mesh2motion_scene.dart';
import '../engine/m2m_engine.dart';
import '../engine/m2m_view.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late Mesh2MotionScene _scene;
  bool _sceneReady = false;
  EditorProvider? _provider;
  String? _lastLoadedPath;

  @override
  void initState() {
    super.initState();
    M2MLogger.info('EditorScreen: initState');
    _scene = Mesh2MotionScene();

    // Hook into M2MEngine
    M2MEngine.instance.core.onDidInit = _onEngineReady;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _provider = Provider.of<EditorProvider>(context, listen: false);
        _provider!.addListener(_onProviderStateChanged);
      }
    });
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderStateChanged);
    super.dispose();
  }

  void _onProviderStateChanged() {
    if (!mounted || !_sceneReady) return;
    
    final state = _provider!.state;
    if (state.loadedModelPath != _lastLoadedPath) {
      M2MLogger.info('EditorScreen: Model path changed in state: ${state.loadedModelPath}');
      _lastLoadedPath = state.loadedModelPath;
      if (_lastLoadedPath != null) {
        _scene.loadModelFromPath(_lastLoadedPath!, _provider!);
      }
    }
  }

  Future<void> _onEngineReady() async {
    M2MLogger.info('EditorScreen: Engine ready callback triggered');
    try {
      await M2MEngine.instance.setScene(_scene);
      M2MLogger.info('EditorScreen: Scene attached to engine');
      if (mounted) {
        setState(() => _sceneReady = true);
        // Check if there's already a model to load
        _onProviderStateChanged();
      }
    } catch (e, stack) {
      M2MLogger.error('Failed to initialize engine/scene', e, stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorProvider = context.watch<EditorProvider>();
    final editorState = editorProvider.state;

    // Sync scene state whenever provider changes
    if (_sceneReady) {
      bool needRebuild = _scene.showSkeleton != editorState.showSkeleton ||
          _scene.selectedNodeId != editorState.selectedNodeId;

      _scene.showSkeleton = editorState.showSkeleton;
      _scene.showWireframe = editorState.showWireframe;
      _scene.showBoneLabels = editorState.showBoneLabels;
      _scene.isPlaying = editorState.isPlaying;
      _scene.playbackSpeed = editorState.animPlaybackSpeed;
      _scene.selectedNodeId = editorState.selectedNodeId;
      _scene.skeletonType = editorState.selectedSkeleton;
      _scene.setActiveAnimation(editorState.activeAnimation?.id);
      _scene.updateMaterial(editorState.materialSettings);

      if (needRebuild) {
        _scene.rebuildBoneGizmos();
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: Provider<Mesh2MotionScene>.value(
        value: _scene,
        child: Column(
          children: [
            // ── Top Toolbar ──────────────────────────────────────────────────
            TopToolbar(scene: _scene),

            // ── Main Editor Area ─────────────────────────────────────────────
            Expanded(
              child: Row(
                children: [
                  // ── Vertical Tools Bar ────────────────────────────────────
                  _VerticalToolsBar(),

                  // ── Left Column: Hierarchy ────────────────────────────────
                  const SizedBox(
                    width: 200,
                    child: LeftPanel(), // We'll update LeftPanel to be the Hierarchy
                  ),

                  // ── 3D Viewport ───────────────────────────────────────────
                  Expanded(
                    child: Stack(
                      children: [
                        const M2MView(),

                        if (!_sceneReady)
                          Container(
                            color: AppTheme.bgSecondary,
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                      color: AppTheme.accent, strokeWidth: 2),
                                  SizedBox(height: 16),
                                  Text(
                                    'Initialising renderer…',
                                    style: TextStyle(
                                        color: AppTheme.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const ViewportOverlay(),

                        if (editorState.phase == EditorPhase.empty)
                          const _EmptyViewportCTA(),

                        if (editorState.isBusy)
                          BusyOverlay(message: editorState.busyMessage ?? 'Working…'),
                      ],
                    ),
                  ),

                  // ── Right Column: Properties & Assets ─────────────────────
                  const SizedBox(
                    width: 300,
                    child: RightPanel(), // We'll update RightPanel to be Inspector + Library
                  ),
                ],
              ),
            ),

            // ── Bottom Timeline ───────────────────────────────────────────────
            if (editorState.phase.index >= EditorPhase.animated.index)
              const BottomTimeline(),
          ],
        ),
      ),
    );
  }
}

class _VerticalToolsBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();
    final state = provider.state;

    return Container(
      width: 42,
      decoration: const BoxDecoration(
        color: AppTheme.bgSecondary,
        border: Border(right: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _ToolIcon(
            icon: Icons.near_me_outlined,
            activeIcon: Icons.near_me,
            label: 'Select',
            isActive: state.activeTool == EditorTool.select,
            onTap: () => provider.setTool(EditorTool.select),
          ),
          _ToolIcon(
            icon: Icons.open_with_outlined,
            activeIcon: Icons.open_with,
            label: 'Move',
            isActive: state.activeTool == EditorTool.move,
            onTap: () => provider.setTool(EditorTool.move),
          ),
          _ToolIcon(
            icon: Icons.rotate_right_outlined,
            activeIcon: Icons.rotate_right,
            label: 'Rotate',
            isActive: state.activeTool == EditorTool.rotate,
            onTap: () => provider.setTool(EditorTool.rotate),
          ),
          _ToolIcon(
            icon: Icons.aspect_ratio_outlined,
            activeIcon: Icons.aspect_ratio,
            label: 'Scale',
            isActive: state.activeTool == EditorTool.scale,
            onTap: () => provider.setTool(EditorTool.scale),
          ),
          const Spacer(),
          _ToolIcon(
            icon: Icons.videocam_outlined,
            activeIcon: Icons.videocam,
            label: 'Camera',
            isActive: state.activeTool == EditorTool.view,
            onTap: () => provider.setTool(EditorTool.view),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolIcon({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isActive ? AppTheme.accentDim : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isActive ? AppTheme.accent : Colors.transparent,
                width: 1,
              ),
            ),
            child: Icon(
              isActive ? activeIcon : icon,
              size: 18,
              color: isActive ? AppTheme.accentLight : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyViewportCTA extends StatelessWidget {
  const _EmptyViewportCTA();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_box_outlined, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'Load a model to start editing',
            style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5), fontSize: 14),
          ),
        ],
      ),
    );
  }
}
