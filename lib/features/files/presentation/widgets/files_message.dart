import 'package:flutter/material.dart';

/// Centered icon + heading + supporting line — the web Files page's
/// `.empty-state`, also used for the load-error state (with [onRetry]).
class FilesMessage extends StatelessWidget {
  const FilesMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.isError = false,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 56,
            color: isError ? scheme.error : scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
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
    );
  }
}
