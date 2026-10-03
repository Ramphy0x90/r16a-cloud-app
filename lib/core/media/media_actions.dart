import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../logging/app_logger.dart';
import '../model/file_item.dart';
import 'file_downloads.dart';
import 'file_viewer_screen.dart';
import 'media_providers.dart';
import 'widgets/download_progress_dialog.dart';

// User-facing file flows shared by Files and Photos. Each reports problems
// with a snackbar on the nearest messenger.

/// Opens [file]: images in the in-app viewer (swiping through [gallery],
/// which should contain [file]; thumbnails tagged `'$heroTagPrefix$id'`
/// fly in); everything else — videos included —
/// fetched to a temporary copy and handed to the system "open with".
Future<void> openMediaFile(
  BuildContext context,
  WidgetRef ref,
  FileItem file, {
  required List<FileItem> gallery,
  String? heroTagPrefix,
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
          heroTagPrefix: heroTagPrefix,
        ),
      ),
    );
    return;
  }

  final messenger = ScaffoldMessenger.of(context);
  final path = await _fetchWithProgress(context, ref, file, 'Opening');
  if (path == null) return;
  if (!await ref.read(fileDownloadsProvider).open(path)) {
    _snack(messenger, 'No app found to open this file.');
  }
}

/// Saves [files] to the device — the web's `downloadSelected()`: one file
/// as-is, several (or a folder) as a zip. Android: Downloads folder with a
/// progress notification. iOS: the share sheet ("Save to Files"…).
Future<void> saveMediaFiles(
  BuildContext context,
  WidgetRef ref,
  List<FileItem> files,
) async {
  if (files.isEmpty) return;
  final downloads = ref.read(fileDownloadsProvider);
  final messenger = ScaffoldMessenger.of(context);
  final origin = _shareOrigin(context);
  _snack(
    messenger,
    files.length == 1
        ? 'Downloading ${files.single.name}…'
        : 'Downloading ${files.length} items…',
  );

  try {
    final saved = await downloads.save(files);
    if (saved.inDownloads) {
      _snack(messenger, 'Saved to Downloads');
    } else {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(saved.path)], sharePositionOrigin: origin),
      );
    }
  } on DownloadCancelled {
    // Cancelled from the notification.
  } catch (e, stack) {
    AppLogger.error(e, stack, 'Download failed');
    _snack(
      messenger,
      e is DownloadFailure && e.message == 'Storage permission denied.'
          ? 'Allow storage access to save downloads.'
          : 'Could not download.',
    );
  }
}

/// Hands [file] to other apps through the system share sheet ("Share
/// via…"). Not the same as Files' "Share", which grants other users access.
Future<void> shareMediaFile(
  BuildContext context,
  WidgetRef ref,
  FileItem file,
) async {
  final origin = _shareOrigin(context);
  final path = await _fetchWithProgress(context, ref, file, 'Preparing');
  if (path == null) return;
  await SharePlus.instance.share(
    ShareParams(files: [XFile(path)], sharePositionOrigin: origin),
  );
}

/// Temporary local copy of [file] behind a cancellable progress dialog
/// ("[verb] name…"). `null` when cancelled or failed (already reported).
Future<String?> _fetchWithProgress(
  BuildContext context,
  WidgetRef ref,
  FileItem file,
  String verb,
) async {
  final downloads = ref.read(fileDownloadsProvider);
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  final progress = ValueNotifier<double?>(null);
  String? taskId;
  var cancelled = false;

  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (_) => DownloadProgressDialog(
      title: '$verb ${file.name}',
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
    if (cancelled) return null;
    navigator.pop();
    return path;
  } on DownloadCancelled {
    return null; // Dialog already closed by Cancel.
  } catch (e, stack) {
    if (cancelled) return null;
    navigator.pop();
    AppLogger.error(e, stack, 'Fetching ${file.name} failed');
    _snack(messenger, 'Could not open the file.');
    return null;
  }
}

void _snack(ScaffoldMessengerState messenger, String message) => messenger
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message)));

/// Where the iPad share popover anchors: the calling screen.
Rect? _shareOrigin(BuildContext context) {
  final box = context.findRenderObject();
  return box is RenderBox ? box.localToGlobal(Offset.zero) & box.size : null;
}
