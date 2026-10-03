import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/file_item.dart';
import 'file_downloads.dart';
import 'file_viewer_screen.dart';
import 'media_providers.dart';
import 'widgets/download_progress_dialog.dart';

/// Opens [file] the way Files and Photos both do: images in the in-app
/// viewer (swiping through [gallery], which should contain [file]);
/// everything else — videos included — fetched to a temporary copy behind
/// a cancellable progress dialog and handed to the system "open with".
/// Problems are reported with a snackbar.
Future<void> openMediaFile(
  BuildContext context,
  WidgetRef ref,
  FileItem file, {
  required List<FileItem> gallery,
}) async {
  if (file.isImage) {
    final images = gallery.where((f) => f.isImage).toList();
    final index = images.indexWhere((f) => f.id == file.id);
    // Root navigator: the viewer covers the dock.
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => FileViewerScreen(
          files: index < 0 ? [file] : images,
          initialIndex: index < 0 ? 0 : index,
        ),
      ),
    );
    return;
  }

  final downloads = ref.read(fileDownloadsProvider);
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  final progress = ValueNotifier<double?>(null);
  String? taskId;
  var cancelled = false;

  void snack(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DownloadProgressDialog(
      title: 'Opening ${file.name}',
      progress: progress,
      onCancel: () {
        cancelled = true;
        if (taskId case final id?) downloads.cancel(id);
        navigator.pop();
      },
    ),
  );

  try {
    final path = await downloads.fetchForOpening(
      file,
      onProgress: (p) {
        if (!cancelled) progress.value = p;
      },
      onStarted: (id) {
        taskId = id;
        // Cancelled while the download link was still being fetched.
        if (cancelled) downloads.cancel(id);
      },
    );
    if (cancelled) return;
    navigator.pop();
    if (!await downloads.open(path)) snack('No app found to open this file.');
  } on DownloadCancelled {
    // Dialog already closed by Cancel.
  } catch (e) {
    if (cancelled) return;
    navigator.pop();
    debugPrint('Open failed: $e');
    snack('Could not open the file.');
  }
}
