import 'package:flutter/material.dart';

/// "2025 · 342 photos" — mirrors `.year-header` in `photos.html`.
class YearHeader extends StatelessWidget {
  const YearHeader({super.key, required this.year, required this.count});

  final int year;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('$year', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(width: 10),
          Text(
            '$count ${count == 1 ? 'photo' : 'photos'}',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
