import 'package:flutter/material.dart';

import '../upload_controller.dart';

/// The web's `.upload-progress-card`: "Uploading", "i / n — name" and the
/// overall progress bar. Shown inline instead of as a blocking overlay, so
/// browsing continues while files upload.
class UploadProgressBanner extends StatelessWidget {
  const UploadProgressBanner({super.key, required this.progress});

  final UploadProgress progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detail = progress.currentIndex == 0
        ? 'Preparing…'
        : '${progress.currentIndex} / ${progress.fileCount} — '
              '${progress.currentName}';

    return _BannerCard(
      color: scheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Uploading', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.fraction,
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
    );
  }
}

/// The web's `.upload-errors-banner`: "Some uploads failed", one line per
/// file, and "Dismiss".
class UploadErrorsBanner extends StatelessWidget {
  const UploadErrorsBanner({
    super.key,
    required this.errors,
    required this.onDismiss,
  });

  final List<String> errors;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return _BannerCard(
      color: scheme.errorContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Some uploads failed',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: scheme.onErrorContainer),
          ),
          const SizedBox(height: 4),
          for (final error in errors)
            Text(
              error,
              style: TextStyle(fontSize: 12, color: scheme.onErrorContainer),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onDismiss,
              child: Text(
                'Dismiss',
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: child,
        ),
      ),
    );
  }
}
