import 'package:flutter/material.dart';

/// The web tiles' `bi-circle` / `bi-check-circle-fill` selection marker.
class SelectionCheck extends StatelessWidget {
  const SelectionCheck({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
      child: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        size: 22,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
    );
  }
}
