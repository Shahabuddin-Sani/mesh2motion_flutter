import 'package:flutter/material.dart' hide Colors;
import '../services/mesh2motion_scene.dart';
import 'package:provider/provider.dart';
import '../models/editor_state.dart';
import '../theme/app_theme.dart';

class ViewportOverlay extends StatelessWidget {
  const ViewportOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorProvider>().state;

    return Stack(
      children: [
        // ── Axis gizmo (top-right) ─────────────────────────────────────────
        const Positioned(
          top: 12,
          right: 12,
          child: _AxisGizmo(),
        ),

        // ── Active tool hint (top-left) ────────────────────────────────────
        Positioned(
          top: 12,
          left: 12,
          child: _ToolHint(tool: state.activeTool),
        ),

        // ── Stats HUD (bottom-left) ────────────────────────────────────────
        if (state.phase != EditorPhase.empty)
          Positioned(
            bottom: 12,
            left: 12,
            child: _StatsHUD(state: state),
          ),

        // ── Bone label tooltip (bottom-right if bone selected) ─────────────
        if (state.selectedNodeId != null && state.showBoneLabels)
          Positioned(
            bottom: 12,
            right: 12,
            child: _BoneTooltip(
              boneName: state.sceneNodes
                  .firstWhere((n) => n.id == state.selectedNodeId,
                      orElse: () => const SceneNode(id: '', name: '', type: ''))
                  .name,
            ),
          ),
        
        // ── Camera presets (bottom-right) ──────────────────────────────────
        Positioned(
          bottom: 12,
          right: 12,
          child: _CameraPresets(),
        ),
      ],
    );
  }
}

class _CameraPresets extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scene = context.read<Mesh2MotionScene>();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.bgPanel.withOpacity(0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CamBtn(icon: Icons.vertical_align_bottom, label: 'TOP', onTap: scene.setTopView),
          _CamBtn(icon: Icons.border_left, label: 'SIDE', onTap: scene.setSideView),
          _CamBtn(icon: Icons.border_top, label: 'FRONT', onTap: scene.setFrontView),
          _CamBtn(icon: Icons.home, label: 'RESET', onTap: scene.resetCamera),
        ],
      ),
    );
  }
}

class _CamBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CamBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.textSecondary),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ─── Axis gizmo ───────────────────────────────────────────────────────────────

class _AxisGizmo extends StatelessWidget {
  const _AxisGizmo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppTheme.bgPanel.withOpacity(0.6),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: CustomPaint(painter: _AxisPainter()),
    );
  }
}

class _AxisPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const len = 22.0;

    void drawAxis(Offset end, Color color, String label) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(center, center + end, paint);
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
          canvas, center + end - Offset(textPainter.width / 2, textPainter.height / 2));
    }

    drawAxis(const Offset(len, 0), const Color(0xFFFC8181), 'X');
    drawAxis(const Offset(0, -len), const Color(0xFF68D391), 'Y');
    drawAxis(Offset(len * 0.6, len * 0.4), const Color(0xFF63B3ED), 'Z');
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Tool hint ────────────────────────────────────────────────────────────────

class _ToolHint extends StatelessWidget {
  final EditorTool tool;
  const _ToolHint({required this.tool});

  static const _toolNames = {
    EditorTool.select: ('SELECT', Icons.near_me),
    EditorTool.move: ('MOVE', Icons.open_with),
    EditorTool.rotate: ('ROTATE', Icons.rotate_left),
    EditorTool.scale: ('SCALE', Icons.unfold_more),
  };

  @override
  Widget build(BuildContext context) {
    final (name, icon) = _toolNames[tool] ?? ('VIEW', Icons.videocam);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bgPanel.withOpacity(0.7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppTheme.accent),
          const SizedBox(width: 5),
          Text(
            name,
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats HUD ────────────────────────────────────────────────────────────────

class _StatsHUD extends StatelessWidget {
  final EditorState state;
  const _StatsHUD({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.bgPanel.withOpacity(0.7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statRow('Nodes', '${state.sceneNodes.length}'),
          if (state.selectedSkeleton != null)
            _statRow('Skeleton', state.selectedSkeleton!.label),
          if (state.activeAnimation != null)
            _statRow('Anim', state.activeAnimation!.name),
        ],
      ),
    );
  }

  Widget _statRow(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$k: ',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
        ),
        Text(
          v,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9),
        ),
      ],
    ),
  );
}

// ─── Bone tooltip ─────────────────────────────────────────────────────────────

class _BoneTooltip extends StatelessWidget {
  final String boneName;
  const _BoneTooltip({required this.boneName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accentDim.withOpacity(0.85),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, size: 6, color: AppTheme.boneSelected),
          const SizedBox(width: 5),
          Text(
            boneName,
            style: const TextStyle(
              color: AppTheme.boneSelected,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
