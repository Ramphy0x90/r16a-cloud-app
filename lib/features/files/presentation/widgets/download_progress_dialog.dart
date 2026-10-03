import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Blocking progress while a file is fetched to open it. [progress] is
/// 0..1, or `null` while the size is unknown.
class DownloadProgressDialog extends StatelessWidget {
  const DownloadProgressDialog({
    super.key,
    required this.title,
    required this.progress,
    required this.onCancel,
  });

  final String title;
  final ValueListenable<double?> progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: ValueListenableBuilder(
          valueListenable: progress,
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        actions: [TextButton(onPressed: onCancel, child: const Text('Cancel'))],
      ),
    );
  }
}
