import 'package:flutter/material.dart';

/// Centered icon + optional heading + supporting line (+ optional Retry) —
/// the web's `.empty-state` pattern, used for every empty and error state
/// so they look the same across screens.
class StatusMessage extends StatelessWidget {
  const StatusMessage({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.isError = false,
    this.onRetry,
    this.iconSize = 56,
  });

  final IconData icon;
  final String? title;
  final String message;

  /// Tints the icon with the error color.
  final bool isError;
  final VoidCallback? onRetry;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final heading = title;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: isError ? scheme.error : scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            if (heading != null) ...[
              Text(heading, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
