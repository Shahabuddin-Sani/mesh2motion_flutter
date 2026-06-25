import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/editor_state.dart';
import '../theme/app_theme.dart';
import '../engine/m2m_resources.dart';

class LeftPanel extends StatelessWidget {
  const LeftPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final editorProvider = context.watch<EditorProvider>();
    final state = editorProvider.state;

    return Container(
      color: AppTheme.bgPanel,
      child: Column(
        children: [
          // ── Panel header ──────────────────────────────────────────────────
          const _PanelHeader(
            title: 'HIERARCHY',
            icon: Icons.layers_outlined,
          ),

          // ── Hierarchy Tree ────────────────────────────────────────────────
          Expanded(
            child: _HierarchyTree(state: state),
          ),
          
          // ── Skeleton Fitting (if applicable) ──────────────────────────────
          if (state.phase == EditorPhase.modelLoaded)
            _SkeletonFittingSection(state: state),
        ],
      ),
    );
  }
}

class _HierarchyTree extends StatelessWidget {
  final EditorState state;
  const _HierarchyTree({required this.state});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<EditorProvider>();
    final rootNodes = state.sceneNodes.where((n) => n.parentId == null).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: rootNodes.map((n) => _HierarchyNode(
        node: n,
        allNodes: state.sceneNodes,
        selectedId: state.selectedNodeId,
        depth: 0,
        onSelect: (id) => provider.selectNode(id),
      )).toList(),
    );
  }
}

class _HierarchyNode extends StatefulWidget {
  final SceneNode node;
  final List<SceneNode> allNodes;
  final String? selectedId;
  final int depth;
  final ValueChanged<String> onSelect;

  const _HierarchyNode({
    required this.node,
    required this.allNodes,
    required this.selectedId,
    required this.depth,
    required this.onSelect,
  });

  @override
  State<_HierarchyNode> createState() => _HierarchyNodeState();
}

class _HierarchyNodeState extends State<_HierarchyNode> {
  bool _expanded = true;

  List<SceneNode> get _children =>
      widget.allNodes.where((n) => n.parentId == widget.node.id).toList();

  IconData _getIconForType(String type) {
    switch (type) {
      case 'model': return Icons.view_in_ar;
      case 'bone': return Icons.circle;
      case 'camera': return Icons.videocam;
      case 'light': return Icons.lightbulb;
      case 'grid': return Icons.grid_on;
      default: return Icons.device_hub;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.selectedId == widget.node.id;
    final hasChildren = _children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => widget.onSelect(widget.node.id),
          child: Container(
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.accentDim.withOpacity(0.6)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            padding: EdgeInsets.only(left: 4.0 + widget.depth * 14.0),
            child: Row(
              children: [
                if (hasChildren)
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Icon(
                      _expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 14,
                      color: AppTheme.textMuted,
                    ),
                  )
                else
                  const SizedBox(width: 14),

                const SizedBox(width: 4),
                Icon(
                  _getIconForType(widget.node.type),
                  size: 12,
                  color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.node.name,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.edit_note, size: 12, color: AppTheme.accent),
                  ),
              ],
            ),
          ),
        ),
        if (hasChildren && _expanded)
          ..._children.map((child) => _HierarchyNode(
            node: child,
            allNodes: widget.allNodes,
            selectedId: widget.selectedId,
            depth: widget.depth + 1,
            onSelect: widget.onSelect,
          )),
      ],
    );
  }
}

class _SkeletonFittingSection extends StatelessWidget {
  final EditorState state;
  const _SkeletonFittingSection({required this.state});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<EditorProvider>();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
        color: AppTheme.bgSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'SKELETON FITTING',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonHideUnderline(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: DropdownButton<SkeletonType>(
                value: state.selectedSkeleton ?? SkeletonType.human,
                dropdownColor: AppTheme.bgCard,
                isExpanded: true,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
                items: SkeletonType.values.map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(t.label),
                )).toList(),
                onChanged: (v) => v != null ? provider.selectSkeleton(v) : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => provider.fitSkeleton(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('AUTO FIT SKELETON', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _PanelHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
        color: AppTheme.bgSecondary,
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
