import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/media/file_downloads.dart';
import '../../../core/media/file_opener.dart';
import '../../../core/media/media_providers.dart';
import '../../../core/model/file_item.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/text_input_dialog.dart';
import '../data/upload_source.dart';
import 'files_controller.dart';
import 'files_providers.dart';
import 'widgets/file_context_sheet.dart';
import 'widgets/share_sheet.dart';
import 'widgets/upload_source_sheet.dart';

/// User-facing flows behind the Files screen's buttons: prompt (dialog /
/// sheet / picker), call the controllers, report failures. Mirrors the web
/// `FilesPage` handlers (`openCreateFolderModal`, `renameFile`,
/// `confirmDelete`, `confirmBulkDelete`, `saveShareSettings`,
/// `triggerUpload`); the web only logs errors, here they surface as
/// snackbars (upload failures go to the upload errors banner, as on web).
class FileActions {
  FileActions(this._context, this._ref);

  final BuildContext _context;
  final WidgetRef _ref;

  FilesController get _controller =>
      _ref.read(filesControllerProvider.notifier);

  Future<void> createFolder() async {
    final name = await showTextInputDialog(
      context: _context,
      title: 'Create Folder',
      hint: 'Folder name',
      confirmLabel: 'Create',
    );
    if (name == null) return;
    await _run(
      () => _controller.createFolder(name),
      'Could not create folder.',
    );
  }

  /// Uploads into the folder open when the picker was launched.
  Future<void> upload() async {
    final pick = await showUploadSourceSheet(_context);
    if (pick == null) return;
    final parentId = _ref.read(filesControllerProvider).currentFolder?.id;

    final List<UploadSource> sources;
    try {
      sources = await _ref.read(uploadPickerProvider)(pick);
    } catch (e, stack) {
      // The snackbar stays generic; the log says why (e.g. a missing
      // native plugin after hot reload, or a denied permission).
      debugPrint('Upload picker failed: $e\n$stack');
      _snack('Could not open the picker.');
      return;
    }
    await _ref
        .read(uploadControllerProvider.notifier)
        .upload(sources, parentId: parentId);
  }

  Future<void> rename(FileItem file) async {
    // Pre-select the name without its extension, as native file apps do.
    final dot = file.name.lastIndexOf('.');
    final name = await showTextInputDialog(
      context: _context,
      title: 'Rename',
      hint: 'New name',
      confirmLabel: 'Rename',
      initialValue: file.name,
      initialSelection: TextSelection(
        baseOffset: 0,
        extentOffset: file.isDirectory || dot <= 0 ? file.name.length : dot,
      ),
    );
    if (name == null || name == file.name) return;
    await _run(() => _controller.rename(file, name), 'Could not rename.');
  }

  /// The sheet reports its own save failures inline.
  Future<void> share(FileItem file) => showShareSheet(
    context: _context,
    file: file,
    onSave: (ids) => _controller.updateSharing(file, ids),
  );

  Future<void> delete(FileItem file) async {
    final confirmed = await showConfirmDialog(
      context: _context,
      title: 'Delete ${file.isDirectory ? 'folder' : 'file'}',
      message: TextSpan(
        text: 'Are you sure you want to delete ',
        children: [
          TextSpan(
            text: file.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const TextSpan(text: '?'),
        ],
      ),
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    await _run(() => _controller.delete(file), 'Could not delete.');
  }

  Future<void> deleteSelected() async {
    final count = _ref.read(filesControllerProvider).selectedIds.length;
    if (count == 0) return;
    final confirmed = await showConfirmDialog(
      context: _context,
      title: 'Delete $count items',
      message: TextSpan(
        text: 'Are you sure you want to delete ',
        children: [
          TextSpan(
            text: '$count',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const TextSpan(
            text: ' selected items? This action cannot be undone.',
          ),
        ],
      ),
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    await _run(_controller.deleteSelected, 'Could not delete all items.');
  }

  /// Images open in the viewer, swiping through the listing's images;
  /// everything else goes to the system "open with".
  Future<void> open(FileItem file) => openMediaFile(
    _context,
    _ref,
    file,
    gallery: _ref.read(filesControllerProvider).items,
  );

  /// Web `downloadSelected()`: one file as-is, several (or a folder) as a
  /// zip. Android saves to Downloads with a progress notification; iOS
  /// offers the share sheet ("Save to Files"…).
  Future<void> download(List<FileItem> files) async {
    if (files.isEmpty) return;
    final downloads = _ref.read(fileDownloadsProvider);
    final origin = _shareOrigin();
    _snack(
      files.length == 1
          ? 'Downloading ${files.single.name}…'
          : 'Downloading ${files.length} items…',
    );
    _controller.cancelSelection();

    try {
      final saved = await downloads.save(files);
      if (saved.inDownloads) {
        _snack('Saved to Downloads');
      } else {
        await SharePlus.instance.share(
          ShareParams(files: [XFile(saved.path)], sharePositionOrigin: origin),
        );
      }
    } on DownloadCancelled {
      // Cancelled from the notification.
    } catch (e) {
      debugPrint('Download failed: $e');
      _snack(
        e is DownloadFailure && e.message == 'Storage permission denied.'
            ? 'Allow storage access to save downloads.'
            : 'Could not download.',
      );
    }
  }

  /// Where the iPad share popover anchors: the whole screen.
  Rect? _shareOrigin() {
    final box = _context.findRenderObject();
    return box is RenderBox ? box.localToGlobal(Offset.zero) & box.size : null;
  }

  Future<void> showMenu(FileItem file) async {
    final action = await showFileContextSheet(
      context: _context,
      file: file,
      readOnly: _ref.read(filesControllerProvider).readOnly,
    );
    if (action == null || !_context.mounted) return;
    switch (action) {
      case FileAction.open:
        await open(file);
      case FileAction.download:
        await download([file]);
      case FileAction.select:
        _controller.startSelection(file);
      case FileAction.rename:
        await rename(file);
      case FileAction.share:
        await share(file);
      case FileAction.delete:
        await delete(file);
    }
  }

  Future<void> _run(Future<void> Function() action, String fallback) async {
    try {
      await action();
    } catch (e) {
      if (!_context.mounted) return;
      _snack(
        e is ApiException && e.statusCode == 409
            ? 'A file or folder with that name already exists.'
            : fallback,
      );
    }
  }

  /// Replaces any visible message instead of queueing behind it, so e.g.
  /// "Saved to Downloads" isn't stuck behind "Downloading…".
  void _snack(String message) {
    if (!_context.mounted) return;
    ScaffoldMessenger.of(_context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
