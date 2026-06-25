import 'dart:async';
import 'package:flutter/material.dart' hide Colors;
import 'package:provider/provider.dart';
import '../models/editor_state.dart';
import '../theme/app_theme.dart';

class BottomTimeline extends StatefulWidget {
  const BottomTimeline({super.key});

  @override
  State<BottomTimeline> createState() => _BottomTimelineState();
}

class _BottomTimelineState extends State<BottomTimeline> {
  Timer? _timer;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    M2MLogger.info('BottomTimeline: initState');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(double durationSecs, double speed, EditorProvider provider) {
    _timer?.cancel();
    M2MLogger.info('BottomTimeline: Starting playback timer (duration: $durationSecs, speed: $speed)');
    final tickMs = 16; // ~60fps
    _timer = Timer.periodic(Duration(milliseconds: tickMs), (t) {
      if (!mounted) return;
      setState(() {
        _progress += (tickMs / 1000.0) * speed / durationSecs;
        if (_progress >= 1.0) _progress = 0.0;
      });
      provider.setAnimProgress(_progress);
    });
  }

  void _stopTimer() {
    if (_timer != null && _timer!.isActive) {
      M2MLogger.info('BottomTimeline: Stopping playback timer');
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorProvider = context.watch<EditorProvider>();
    final state = editorProvider.state;

    // Start/stop timer based on play state
    if (state.isPlaying && state.activeAnimation != null) {
      if (_timer == null || !_timer!.isActive) {
        _startTimer(
          state.activeAnimation!.durationSecs,
          state.animPlaybackSpeed,
          editorProvider,
        );
      }
    } else {
      _stopTimer();
    }

    final anim = state.activeAnimation;
    final totalSecs = anim?.durationSecs ?? 1.0;
    final currentSec = _progress * totalSecs;

    return Container(
      height: 60,
      color: AppTheme.bgSecondary,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Scrubber ───────────────────────────────────────────────────────
          Row(
            children: [
              // Time display
              SizedBox(
                width: 60,
                child: Text(
                  _formatTime(currentSec),
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Scrub track
              Expanded(
                child: GestureDetector(
                  onTapDown: (details) => _scrubTo(details, context, editorProvider),
                  onHorizontalDragUpdate: (details) =>
                      _scrubTo(details, context, editorProvider),
                  child: Container(
                    height: 20,
                    alignment: Alignment.center,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Track background
                        Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppTheme.bgCard,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // Progress fill
                        FractionallySizedBox(
                          widthFactor: _progress,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppTheme.accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        // Playhead
                        FractionallySizedBox(
                          widthFactor: _progress,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppTheme.accentLight,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Total time
              SizedBox(
                width: 60,
                child: Text(
                  _formatTime(totalSecs),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ── Controls ───────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Skip to start
              _CtrlButton(
                icon: Icons.skip_previous,
                onTap: () {
                  M2MLogger.info('BottomTimeline: Skip to start clicked');
                  setState(() => _progress = 0.0);
                  editorProvider.setAnimProgress(0);
                },
              ),

              const SizedBox(width: 4),

              // Play / Pause
              GestureDetector(
                onTap: () {
                  M2MLogger.info('BottomTimeline: Toggle Play clicked');
                  editorProvider.togglePlay();
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    state.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: AppTheme.bgPrimary,
                    size: 18,
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // Skip to end
              _CtrlButton(
                icon: Icons.skip_next,
                onTap: () {
                  M2MLogger.info('BottomTimeline: Skip to end clicked');
                  setState(() => _progress = 1.0);
                  editorProvider.setAnimProgress(1);
                },
              ),

              const SizedBox(width: 16),

              // Speed selector
              _SpeedChip(
                speed: state.animPlaybackSpeed,
                onSelect: (s) {
                  M2MLogger.info('BottomTimeline: Speed selector: $s');
                  editorProvider.setPlaybackSpeed(s);
                },
              ),

              const SizedBox(width: 12),

              // Animation name
              if (anim != null)
                Text(
                  '${anim.name}  ·  ${anim.category}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _scrubTo(dynamic details, BuildContext context, EditorProvider provider) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    // Approximate track width (total - left margin - time label widths)
    final trackWidth = box.size.width - 16 - 16 - 60 - 60;
    final local = details is TapDownDetails
        ? details.localPosition.dx - 16 - 60
        : (details as DragUpdateDetails).localPosition.dx - 16 - 60;
    final clamped = (local / trackWidth).clamp(0.0, 1.0);
    setState(() => _progress = clamped);
    provider.setAnimProgress(clamped);
  }

  String _formatTime(double secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toStringAsFixed(2).padLeft(5, '0');
    return '$m:$s';
  }
}

class _CtrlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CtrlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Icon(icon, size: 14, color: AppTheme.textSecondary),
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  final double speed;
  final ValueChanged<double> onSelect;
  const _SpeedChip({required this.speed, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      offset: const Offset(0, -120),
      color: AppTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      itemBuilder: (context) => [0.25, 0.5, 1.0, 1.5, 2.0, 3.0]
          .map((s) => PopupMenuItem<double>(
                value: s,
                height: 30,
                child: Text(
                  '${s}×',
                  style: TextStyle(
                    color: s == speed ? AppTheme.accent : AppTheme.textPrimary,
                    fontSize: 12,
                  ),
                ),
              ))
          .toList(),
      onSelected: onSelect,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Text(
          '${speed.toStringAsFixed(speed == 1.0 ? 0 : 2)}×',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
