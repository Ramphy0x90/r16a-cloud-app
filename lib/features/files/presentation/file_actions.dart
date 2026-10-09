import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/media/media_actions.dart';
import '../../../core/model/file_item.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/text_input_dialog.dart';
import '../data/upload_source.dart';
import 'files_controller.dart';
import 'files_providers.dart';
import 'files_state.dart';
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
      AppLogger.error(e, stack, 'Upload picker failed');
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
    HapticFeedback.mediumImpact();
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
    HapticFeedback.mediumImpact();
    await _run(_controller.deleteSelected, 'Could not delete all items.');
  }

  /// Images and videos open in the viewer, swiping through the listing's
  /// media; everything else goes to the system "open with".
  Future<void> open(FileItem file) => openMediaFile(
    _context,
    _ref,
    file,
    gallery: _ref.read(filesControllerProvider).items,
    heroTagPrefix: filesHeroPrefix,
  );

  /// Saves to the device (see [saveMediaFiles]) and leaves selection
  /// mode, like the web's `downloadSelected()`.
  Future<void> download(List<FileItem> files) {
    _controller.cancelSelection();
    return saveMediaFiles(_context, _ref, files);
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
