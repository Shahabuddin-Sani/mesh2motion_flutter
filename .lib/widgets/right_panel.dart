import 'package:flutter/material.dart';
import '../models/editor_state.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';

class RightPanel extends StatefulWidget {
  const RightPanel({super.key});

  @override
  State<RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends State<RightPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _animSearch = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgPanel,
        border: Border(left: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Column(
        children: [
          // ── Tab bar ───────────────────────────────────────────────────────
          Container(
            color: AppTheme.bgSecondary,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.accent,
              indicatorWeight: 2,
              labelColor: AppTheme.accent,
              unselectedLabelColor: AppTheme.textMuted,
              labelStyle: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
              tabs: const [
                Tab(text: 'INSPECTOR'),
                Tab(text: 'LIBRARY'),
                Tab(text: 'MATERIAL'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const _InspectorTab(),
                _LibraryTab(
                  searchQuery: _animSearch,
                  onSearchChanged: (q) => setState(() => _animSearch = q),
                ),
                const _MaterialTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Inspector Tab ──────────────────────────────────────────────────────────

class _InspectorTab extends StatelessWidget {
  const _InspectorTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorProvider>().state;
    final selectedNode = state.sceneNodes
        .where((n) => n.id == state.selectedNodeId)
        .firstOrNull;

    if (selectedNode == null) {
      return const Center(
        child: Text(
          'Select an item in Hierarchy\nto view properties',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── Node Info ──────────────────────────────────────────────────────
        _PropSection(
          title: 'ITEM INFO',
          children: [
            _PropRow('Name', selectedNode.name),
            _PropRow('Type', selectedNode.type.toUpperCase()),
            _PropRow('ID', selectedNode.id),
          ],
        ),
        const SizedBox(height: 12),

        // ── Transform ──────────────────────────────────────────────────────
        const _PropSection(
          title: 'TRANSFORM',
          children: [
            _Vec3Field(label: 'Position', x: 0.0, y: 0.0, z: 0.0),
            SizedBox(height: 10),
            _Vec3Field(label: 'Rotation', x: 0.0, y: 0.0, z: 0.0),
            SizedBox(height: 10),
            _Vec3Field(label: 'Scale', x: 1.0, y: 1.0, z: 1.0),
          ],
        ),
        const SizedBox(height: 12),

        // ── Type Specific ──────────────────────────────────────────────────
        if (selectedNode.type == 'camera')
          const _PropSection(
            title: 'CAMERA SETTINGS',
            children: [
              _PropRow('FOV', '60°'),
              _PropRow('Near', '0.1'),
              _PropRow('Far', '1000.0'),
              _PropRow('Type', 'Perspective'),
            ],
          ),
          
        if (selectedNode.type == 'light')
          const _PropSection(
            title: 'LIGHT SETTINGS',
            children: [
              _PropRow('Intensity', '1.0'),
              _PropRow('Color', '#FFFFFF'),
              _PropRow('Cast Shadows', 'On'),
            ],
          ),

        if (selectedNode.type == 'model')
          _PropSection(
            title: 'MODEL DATA',
            children: [
              _PropRow('Skeleton', state.selectedSkeleton?.label ?? 'None'),
              _PropRow('Status', state.phase.name.toUpperCase()),
              if (state.activeAnimation != null)
                _PropRow('Animation', state.activeAnimation!.name),
            ],
          ),
      ],
    );
  }
}

// ─── Library Tab (Animations) ────────────────────────────────────────────────

class _LibraryTab extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  const _LibraryTab({
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final editorProvider = context.watch<EditorProvider>();
    final state = editorProvider.state;
    final selectedType = state.selectedSkeleton;

    final available = kAnimationLibrary.where((a) {
      if (selectedType != null && !a.compatibleWith.contains(selectedType)) {
        return false;
      }
      if (searchQuery.isNotEmpty &&
          !a.name.toLowerCase().contains(searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    final Map<String, List<AnimationEntry>> byCategory = {};
    for (final anim in available) {
      byCategory.putIfAbsent(anim.category, () => []).add(anim);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: TextField(
              onChanged: onSearchChanged,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
              decoration: const InputDecoration(
                hintText: 'Search Library…',
                hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                prefixIcon: Icon(Icons.search, size: 14, color: AppTheme.textMuted),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: byCategory.entries.map((entry) {
              return _AnimationCategory(
                category: entry.key,
                animations: entry.value,
                activeId: state.activeAnimation?.id,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _AnimationCategory extends StatelessWidget {
  final String category;
  final List<AnimationEntry> animations;
  final String? activeId;

  const _AnimationCategory({
    required this.category,
    required this.animations,
    this.activeId,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<EditorProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
          child: Text(
            category.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
        ...animations.map((anim) => _AnimationTile(
          anim: anim,
          isActive: anim.id == activeId,
          onTap: () => provider.setActiveAnimation(anim),
        )),
      ],
    );
  }
}

class _AnimationTile extends StatelessWidget {
  final AnimationEntry anim;
  final bool isActive;
  final VoidCallback onTap;

  const _AnimationTile({
    required this.anim,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.accentDim : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? AppTheme.accent : AppTheme.borderColor,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? Icons.play_arrow : Icons.play_arrow_outlined,
              size: 14,
              color: isActive ? AppTheme.accent : AppTheme.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                anim.name,
                style: TextStyle(
                  color: isActive ? AppTheme.accentLight : AppTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Text(
              '${anim.durationSecs.toStringAsFixed(1)}s',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Material Tab ─────────────────────────────────────────────────────────────

class _MaterialTab extends StatelessWidget {
  const _MaterialTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();
    final settings = provider.state.materialSettings;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _PropSection(
          title: 'SHADING MODEL',
          children: [
            Row(
              children: [
                _TypeButton(
                  label: 'PBR',
                  isActive: settings.type == M2MMaterialType.pbr,
                  onTap: () => provider.updateMaterial(settings.copyWith(type: M2MMaterialType.pbr)),
                ),
                const SizedBox(width: 8),
                _TypeButton(
                  label: 'TOON',
                  isActive: settings.type == M2MMaterialType.toon,
                  onTap: () => provider.updateMaterial(settings.copyWith(type: M2MMaterialType.toon)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        _PropSection(
          title: 'SURFACE PROPERTIES',
          children: [
            if (settings.type == M2MMaterialType.pbr) ...[
              _SliderRow(
                label: 'Roughness',
                value: settings.roughness,
                onChanged: (v) => provider.updateMaterial(settings.copyWith(roughness: v)),
              ),
              _SliderRow(
                label: 'Metalness',
                value: settings.metalness,
                onChanged: (v) => provider.updateMaterial(settings.copyWith(metalness: v)),
              ),
            ] else ...[
              _SliderRow(
                label: 'Steps',
                value: settings.toonSteps,
                min: 2, max: 8, divisions: 6,
                onChanged: (v) => provider.updateMaterial(settings.copyWith(toonSteps: v)),
              ),
              _ToggleRow(
                label: 'Rim Lighting',
                value: settings.useRimLight,
                onChanged: (v) => provider.updateMaterial(settings.copyWith(useRimLight: v)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        _PropSection(
          title: 'BASE COLOR',
          children: [
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: settings.baseColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.borderColor),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ColorSwatch(color: const Color(0xFFDDDDDD), current: settings.baseColor, onTap: (c) => provider.updateMaterial(settings.copyWith(baseColor: c))),
                _ColorSwatch(color: const Color(0xFFFC8181), current: settings.baseColor, onTap: (c) => provider.updateMaterial(settings.copyWith(baseColor: c))),
                _ColorSwatch(color: const Color(0xFF68D391), current: settings.baseColor, onTap: (c) => provider.updateMaterial(settings.copyWith(baseColor: c))),
                _ColorSwatch(color: const Color(0xFF63B3ED), current: settings.baseColor, onTap: (c) => provider.updateMaterial(settings.copyWith(baseColor: c))),
                _ColorSwatch(color: const Color(0xFFF6AD55), current: settings.baseColor, onTap: (c) => provider.updateMaterial(settings.copyWith(baseColor: c))),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Small Components ─────────────────────────────────────────────────────────

class _PropSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _PropSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            title,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _PropRow extends StatelessWidget {
  final String label;
  final String value;
  const _PropRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 10, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Vec3Field extends StatelessWidget {
  final String label;
  final double x, y, z;
  const _Vec3Field({required this.label, required this.x, required this.y, required this.z});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
        const SizedBox(height: 5),
        Row(
          children: [
            _NumBox('X', x, const Color(0xFFFC8181)),
            const SizedBox(width: 4),
            _NumBox('Y', y, const Color(0xFF68D391)),
            const SizedBox(width: 4),
            _NumBox('Z', z, const Color(0xFF63B3ED)),
          ],
        ),
      ],
    );
  }
}

class _NumBox extends StatelessWidget {
  final String axis;
  final double value;
  final Color color;
  const _NumBox(this.axis, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: AppTheme.bgSecondary,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Text(axis, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value.toStringAsFixed(2),
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _TypeButton({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.accentDim : AppTheme.bgSecondary,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isActive ? AppTheme.accent : AppTheme.borderColor),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? AppTheme.accentLight : AppTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min, max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
            Text(value.toStringAsFixed(2), style: const TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
          ),
          child: Slider(
            value: value,
            min: min, max: max, divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.accent,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final Color current;
  final ValueChanged<Color> onTap;
  const _ColorSwatch({required this.color, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = color == current;
    return GestureDetector(
      onTap: () => onTap(color),
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : AppTheme.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}
