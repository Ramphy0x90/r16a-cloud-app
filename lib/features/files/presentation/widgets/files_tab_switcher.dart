import 'package:flutter/material.dart';

import '../files_state.dart';

/// "My files" | "Shared" — the web toolbar's `filter-tabs`, shown at root.
/// Styled like the dock (card-colored pill, primary-tinted selection)
/// rather than web's underline tabs.
class FilesTabSwitcher extends StatelessWidget {
  const FilesTabSwitcher({
    super.key,
    required this.tab,
    required this.onChanged,
  });

  final FilesTab tab;
  final ValueChanged<FilesTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Segment(
              icon: Icons.cloud_outlined,
              label: 'My files',
              selected: tab == FilesTab.mine,
              onTap: () => onChanged(FilesTab.mine),
            ),
            const SizedBox(width: 2),
            _Segment(
              icon: Icons.people_outline,
              label: 'Shared',
              selected: tab == FilesTab.shared,
              onTap: () => onChanged(FilesTab.shared),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
