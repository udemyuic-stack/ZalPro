import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../theme.dart';
import 'ui.dart';

class AppNavItem {
  final Widget icon;
  final Widget? selectedIcon;
  final String label;
  const AppNavItem(
      {required this.icon, this.selectedIcon, required this.label});
}

class AppNavBar extends StatelessWidget {
  final List<AppNavItem> items;
  final int primary;
  final int selected;
  final ValueChanged<int> onSelected;
  final Widget moreIcon;

  const AppNavBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    int? primary,
    this.moreIcon = const Icon(Icons.more_horiz),
  }) : primary = primary ?? items.length;

  bool get _hasMore => primary < items.length;

  void _select(BuildContext context, int i) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    onSelected(i);
  }

  Future<void> _openMore(BuildContext context) async {
    final picked = await showSheet<int>(
      context,
      Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr("Ko'proq"), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpace.sm),
            for (var i = primary; i < items.length; i++)
              ListTile(
                minTileHeight: 56,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                selected: selected == i,
                selectedColor: AppColors.accentText,
                selectedTileColor: AppColors.accent.withValues(alpha: 0.10),
                iconColor: AppColors.textMuted,
                leading: IconTheme.merge(
                    data: const IconThemeData(size: 24),
                    child: selected == i
                        ? (items[i].selectedIcon ?? items[i].icon)
                        : items[i].icon),
                title: Text(items[i].label,
                    style: Theme.of(context).textTheme.titleMedium),
                trailing: Icon(Icons.chevron_right, color: AppColors.textFaint),
                onTap: () => Navigator.pop(context, i),
              ),
          ]),
    );
    if (picked != null && context.mounted) _select(context, picked);
  }

  @override
  Widget build(BuildContext context) {
    final shown = _hasMore ? primary : items.length;
    return _GlassBar(
      child: NavigationBar(
        selectedIndex: selected < shown ? selected : shown,
        onDestinationSelected: (i) {
          if (_hasMore && i == shown) {
            _openMore(context);
          } else {
            _select(context, i);
          }
        },
        destinations: [
          for (var i = 0; i < shown; i++)
            NavigationDestination(
              icon: items[i].icon,
              selectedIcon: items[i].selectedIcon,
              label: items[i].label,
              tooltip: '',
            ),
          if (_hasMore)
            NavigationDestination(
                icon: moreIcon, label: tr("Ko'proq"), tooltip: ''),
        ],
      ),
    );
  }
}

class _GlassBar extends StatelessWidget {
  final Widget child;
  const _GlassBar({required this.child});

  @override
  Widget build(BuildContext context) => ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.hairline))),
            child: child,
          ),
        ),
      );
}
