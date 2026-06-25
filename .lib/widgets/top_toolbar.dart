import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/editor_state.dart';
import '../theme/app_theme.dart';
import '../services/mesh2motion_scene.dart';
import '../engine/m2m_resources.dart';

class TopToolbar extends StatelessWidget {
  final Mesh2MotionScene scene;
  const TopToolbar({super.key, required this.scene});

  @override
  Widget build(BuildContext context) {
    final editorProvider = context.watch<EditorProvider>();
    final state = editorProvider.state;

    return Container(
      height: 46,
      color: AppTheme.bgSecondary,
      child: Row(
        children: [
          // ── Brand ────────────────────────────────────────────────────────
          Container(
            width: 220,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: AppTheme.borderColor)),
            ),
            child: Row(
              children: [
                const Icon(Icons.view_in_ar, color: AppTheme.accent, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Mesh2Motion',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.accentDim,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'FLUTTER',
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── File Menu ────────────────────────────────────────────────────
          _MenuButton(
            label: 'File',
            items: [
              _MenuItem(
                icon: Icons.folder_open,
                label: 'Load Model…',
                shortcut: 'Ctrl+O',
                onTap: () => _pickAndLoadModel(context, editorProvider),
              ),
              _MenuItem(
                icon: Icons.save_alt,
                label: 'Export GLB…',
                shortcut: 'Ctrl+E',
                enabled: state.phase.index >= EditorPhase.skeletonFitted.index,
                onTap: () => _exportGLB(context, editorProvider),
              ),
              const _MenuDivider(),
              _MenuItem(
                icon: Icons.restart_alt,
                label: 'Reset Scene',
                onTap: () {
                  M2MLogger.info('TopToolbar: Reset Scene clicked');
                  editorProvider.reset();
                },
              ),
            ],
          ),

          // ── View Menu ────────────────────────────────────────────────────
          _MenuButton(
            label: 'View',
            items: [
              _MenuItem(
                icon: state.showSkeleton
                    ? Icons.visibility
                    : Icons.visibility_off,
                label: 'Skeleton',
                shortcut: 'S',
                isToggle: true,
                toggleValue: state.showSkeleton,
                onTap: () {
                  M2MLogger.info('TopToolbar: Toggle Skeleton clicked');
                  editorProvider.toggleSkeleton();
                },
              ),
              _MenuItem(
                icon: Icons.grid_3x3,
                label: 'Wireframe',
                shortcut: 'W',
                isToggle: true,
                toggleValue: state.showWireframe,
                onTap: () {
                  M2MLogger.info('TopToolbar: Toggle Wireframe clicked');
                  editorProvider.toggleWireframe();
                },
              ),
              _MenuItem(
                icon: Icons.label_outline,
                label: 'Bone Labels',
                shortcut: 'L',
                isToggle: true,
                toggleValue: state.showBoneLabels,
                onTap: () {
                  M2MLogger.info('TopToolbar: Toggle Bone Labels clicked');
                  editorProvider.toggleBoneLabels();
                },
              ),
            ],
          ),

          const SizedBox(width: 16),
          _ToolbarDivider(),

          // ── Transform Tools ───────────────────────────────────────────────
          _ToolButton(
            icon: Icons.near_me,
            tooltip: 'Select (Q)',
            isActive: state.activeTool == EditorTool.select,
            onTap: () {
              M2MLogger.info('TopToolbar: Select tool clicked');
              editorProvider.setTool(EditorTool.select);
            },
          ),
          _ToolButton(
            icon: Icons.open_with,
            tooltip: 'Move (G)',
            isActive: state.activeTool == EditorTool.move,
            onTap: () {
              M2MLogger.info('TopToolbar: Move tool clicked');
              editorProvider.setTool(EditorTool.move);
            },
          ),
          _ToolButton(
            icon: Icons.rotate_left,
            tooltip: 'Rotate (R)',
            isActive: state.activeTool == EditorTool.rotate,
            onTap: () {
              M2MLogger.info('TopToolbar: Rotate tool clicked');
              editorProvider.setTool(EditorTool.rotate);
            },
          ),
          _ToolButton(
            icon: Icons.unfold_more,
            tooltip: 'Scale (S)',
            isActive: state.activeTool == EditorTool.scale,
            onTap: () {
              M2MLogger.info('TopToolbar: Scale tool clicked');
              editorProvider.setTool(EditorTool.scale);
            },
          ),

          _ToolbarDivider(),

          // ── Phase indicator ───────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _PhaseIndicator(phase: state.phase),
            ),
          ),

          // ── Export button ─────────────────────────────────────────────────
          if (state.phase.index >= EditorPhase.skeletonFitted.index)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: () => _exportGLB(context, editorProvider),
                icon: const Icon(Icons.save_alt, size: 14),
                label: const Text('Export GLB'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickAndLoadModel(BuildContext context, EditorProvider provider) async {
    M2MLogger.info('TopToolbar: Pick and Load Model clicked');
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['glb', 'gltf', 'fbx', 'obj'],
      withData: true,
      dialogTitle: 'Load 3D Model',
    );
    if (result == null || result.files.isEmpty) {
      M2MLogger.info('TopToolbar: Model picking cancelled');
      return;
    }

    final file = result.files.first;
    final name = file.name;
    final path = kIsWeb ? null : file.path;
    final bytes = file.bytes;

    provider.setBusy('Loading $name…');

    try {
      if (bytes != null) {
        M2MResourceManager.instance.registerBuffer(name, bytes);
        M2MLogger.info('TopToolbar: Registered memory buffer for $name');
        await scene.loadModelFromPath(name, provider);
        provider.loadModel(name, name);
      } else if (path != null) {
        M2MLogger.info('TopToolbar: Loading model from local path: $path');
        await scene.loadModelFromPath(path, provider);
        provider.loadModel(path, name);
      } else {
        throw Exception('No data or path available for the picked file');
      }
      
      M2MLogger.info('TopToolbar: Scene loaded model successfully');
    } catch (e, stack) {
      M2MLogger.error('TopToolbar: Failed to load model', e, stack);
      provider.clearBusy();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load model: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _exportGLB(BuildContext context, EditorProvider provider) async {
    final state = provider.state;
    if (state.phase == EditorPhase.empty) {
      M2MLogger.warning('TopToolbar: Export clicked but phase is empty');
      return;
    }

    M2MLogger.info('TopToolbar: Export GLB clicked');
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Rigged GLB',
      fileName: 'rigged_${state.loadedModelName ?? "character"}.glb',
      type: FileType.custom,
      allowedExtensions: ['glb'],
    );
    if (savePath == null) {
      M2MLogger.info('TopToolbar: Export cancelled by user');
      return;
    }

    provider.setBusy('Exporting GLB…');
    M2MLogger.info('TopToolbar: Starting export to $savePath');
    await Future.delayed(const Duration(seconds: 1)); // simulate export
    provider.exportGLB(savePath);
    M2MLogger.info('TopToolbar: Export completed');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported to $savePath'),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

class _PhaseIndicator extends StatelessWidget {
  final EditorPhase phase;
  const _PhaseIndicator({required this.phase});

  static const _steps = ['Load', 'Skeleton', 'Animate', 'Export'];
  static const _phases = [
    EditorPhase.modelLoaded,
    EditorPhase.skeletonFitted,
    EditorPhase.animated,
    EditorPhase.exported,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepIdx = i ~/ 2;
          final done = phase.index > _phases[stepIdx].index;
          return Container(
            width: 20,
            height: 1,
            color: done ? AppTheme.accent : AppTheme.borderColor,
          );
        }
        final stepIdx = i ~/ 2;
        final done = phase.index > _phases[stepIdx].index;
        final active = phase == _phases[stepIdx] ||
            (stepIdx == 0 && phase == EditorPhase.modelLoaded);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? AppTheme.accent
                    : active
                        ? AppTheme.accentLight
                        : AppTheme.borderColor,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              _steps[stepIdx],
              style: TextStyle(
                color: done || active
                    ? AppTheme.accent
                    : AppTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 28,
    color: AppTheme.borderColor,
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.accentDim : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isActive ? AppTheme.accent : Colors.transparent,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isActive ? AppTheme.accentLight : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String? shortcut;
  final bool enabled;
  final bool isToggle;
  final bool? toggleValue;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.shortcut,
    this.enabled = true,
    this.isToggle = false,
    this.toggleValue,
    required this.onTap,
  });
}

class _MenuDivider {
  const _MenuDivider();
}

class _MenuButton extends StatelessWidget {
  final String label;
  final List<Object> items;

  const _MenuButton({required this.label, required this.items});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      offset: const Offset(0, 36),
      color: AppTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      itemBuilder: (context) {
        final menuItems = <PopupMenuEntry<int>>[];
        for (int i = 0; i < items.length; i++) {
          final item = items[i];
          if (item is _MenuDivider) {
            menuItems.add(const PopupMenuDivider(height: 1));
          } else if (item is _MenuItem) {
            menuItems.add(PopupMenuItem<int>(
              value: i,
              enabled: item.enabled,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Icon(item.icon,
                      size: 14,
                      color: item.enabled
                          ? AppTheme.textSecondary
                          : AppTheme.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: item.enabled
                            ? AppTheme.textPrimary
                            : AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (item.shortcut != null)
                    Text(
                      item.shortcut!,
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 10),
                    ),
                  if (item.isToggle && item.toggleValue != null)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.toggleValue!
                            ? AppTheme.accent
                            : AppTheme.textMuted,
                      ),
                    ),
                ],
              ),
            ));
          }
        }
        return menuItems;
      },
      onSelected: (i) {
        final item = items[i];
        if (item is _MenuItem && item.enabled) item.onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
