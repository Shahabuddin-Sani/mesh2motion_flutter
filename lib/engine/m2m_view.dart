import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'm2m_engine.dart';
import '../models/editor_state.dart';
import '../theme/app_theme.dart';
import '../services/mesh2motion_scene.dart';

/// A native replacement for M3View that provides better lifecycle management
/// and integration with the M2MEngine.
class M2MView extends StatefulWidget {
  const M2MView({super.key});

  @override
  State<M2MView> createState() => _M2MViewState();
}

class _M2MViewState extends State<M2MView> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Timer? _debounceTimer;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    M2MLogger.info('M2MView: initState');
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initEngine();
    });
  }

  Future<void> _initEngine() async {
    if (!mounted) return;
    
    final size = await _getValidSize(context);
    if (!mounted) return;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    
    M2MLogger.info('M2MView: Initializing engine with size ${size.width}x${size.height} @ $dpr');

    // Setup the ticker for the core engine
    final engine = M2MEngine.instance.core;
    engine.ticker = createTicker(engine.updateRender);

    // Initialize our native wrapper (which in turn inits the core)
    await M2MEngine.instance.initialize(
      width: size.width.toInt(),
      height: size.height.toInt(),
      dpr: dpr,
    );

    if (mounted) {
      setState(() {
        _isInitialized = true;
        engine.resume();
      });
      M2MLogger.info('M2MView: Engine initialization complete');
    }
  }

  Future<Size> _getValidSize(BuildContext context) async {
    Size size = MediaQuery.of(context).size;
    while (size.width == 0 || size.height == 0) {
      await Future.delayed(const Duration(milliseconds: 16));
      if (!context.mounted) break;
      size = MediaQuery.of(context).size;
    }
    return size;
  }

  @override
  void dispose() {
    M2MLogger.info('M2MView: dispose');
    _debounceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    M2MEngine.instance.core.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final engine = M2MEngine.instance.core;
    engine.pause();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      final mq = MediaQuery.of(context);
      final w = mq.size.width.toInt();
      final h = mq.size.height.toInt();
      final dpr = mq.devicePixelRatio;
      
      M2MLogger.info('M2MView: Resizing engine to ${w}x${h}');
      await engine.onResize(w, h, dpr);

      setState(() {
        engine.resume();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        color: AppTheme.bgPrimary,
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2),
        ),
      );
    }

    final editorProvider = context.watch<EditorProvider>();
    final state = editorProvider.state;
    final scene = M2MEngine.instance.currentScene;

    // Sync scene state
    if (scene is Mesh2MotionScene) {
      scene.isPlaying = state.isPlaying;
      scene.playbackSpeed = state.animPlaybackSpeed;
      scene.showSkeleton = state.showSkeleton;
      scene.showWireframe = state.showWireframe;
      scene.showBoneLabels = state.showBoneLabels;
      scene.skeletonType = state.selectedSkeleton;
      scene.activeAnimationId = state.activeAnimation?.id;
      
      if (scene.selectedNodeId != state.selectedNodeId) {
        scene.selectedNodeId = state.selectedNodeId;
        scene.rebuildBoneGizmos();
      }
    }

    final engineWidget = M2MEngine.instance.core.getAppWidget();

    return Listener(
      onPointerSignal: (signal) {
        if (signal is PointerScrollEvent && scene is Mesh2MotionScene) {
          scene.zoom(signal.scrollDelta.dy);
        }
      },
      child: GestureDetector(
        onTapDown: (details) {
          if (scene is Mesh2MotionScene) {
            final size = context.size!;
            final pickedId = scene.pickBone(
              details.localPosition.dx,
              details.localPosition.dy,
              size.width,
              size.height,
            );
            
            // If we didn't pick a bone, maybe we clicked in space?
            // For now just select what we found
            editorProvider.selectNode(pickedId);
          }
        },
        onPanUpdate: (details) {
          if (scene is Mesh2MotionScene) {
            final isPanning = (HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) || 
                               HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight));
            
            if (isPanning) {
              scene.pan(details.delta.dx, details.delta.dy);
            } else {
              scene.orbit(details.delta.dx, details.delta.dy);
            }
          }
        },
        child: engineWidget,
      ),
    );
  }
}
