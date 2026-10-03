import 'dart:io';

import 'package:background_downloader/background_downloader.dart';

import '../model/file_item.dart';
import 'media_api.dart';

/// What the platform downloader should fetch.
class DownloadRequest {
  const DownloadRequest({
    required this.url,
    required this.filename,
    this.headers = const {},
    this.post,
  });

  final String url;
  final String filename;
  final Map<String, String> headers;

  /// JSON body; `null` means GET.
  final Map<String, Object?>? post;
}

/// The user cancelled the download.
class DownloadCancelled implements Exception {
  const DownloadCancelled();
}

class DownloadFailure implements Exception {
  const DownloadFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A finished "save to device" download.
class SavedDownload {
  const SavedDownload({required this.path, required this.inDownloads});

  final String path;

  /// `true` on Android (moved to the shared Downloads folder); `false` on
  /// iOS, where the file stays in the app and is handed to the share sheet.
  final bool inDownloads;
}

/// Downloads through `background_downloader`, mirroring the web's
/// `downloadSelected()`: one plain file uses the signed token link
/// (`GET /fs/download/token`), anything else the zip endpoint
/// (`POST /fs/download`). Two uses: a temporary copy to open a file, and a
/// saved copy (Android Downloads / iOS share sheet).
class FileDownloads {
  FileDownloads(this._api, this._accessToken, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const _saveGroup = 'save';

  final MediaApi _api;
  final Future<String?> Function() _accessToken;
  final DateTime Function() _now;
  var _saveNotificationsReady = false;

  FileDownloader get _downloader => FileDownloader();

  Future<DownloadRequest> requestFor(List<FileItem> files) async {
    if (files.isEmpty) throw ArgumentError.value(files, 'files', 'empty');

    if (files.length == 1 && !files.single.isDirectory) {
      final file = files.single;
      final token = await _api.getDownloadToken(file.id);
      return DownloadRequest(
        url: _api.tokenDownloadUri(token).toString(),
        filename: file.name,
      );
    }

    final bearer = await _accessToken();
    return DownloadRequest(
      url: _api.zipDownloadUri.toString(),
      // A lone folder keeps its name; otherwise the web's fallback name.
      filename: files.length == 1
          ? '${files.single.name}.zip'
          : 'download_${_now().millisecondsSinceEpoch}.zip',
      headers: {
        // Spring's @RequestBody needs it; the plugin doesn't add it.
        'Content-Type': 'application/json',
        if (bearer != null) 'Authorization': 'Bearer $bearer',
      },
      post: {
        'ids': [for (final f in files) f.id],
      },
    );
  }

  /// Local copy for opening, in temporary storage. Keyed by id and
  /// `updatedAt`, so an unchanged file opens without downloading again.
  /// [onStarted] receives the task id, for [cancel].
  Future<String> fetchForOpening(
    FileItem file, {
    void Function(double progress)? onProgress,
    void Function(String taskId)? onStarted,
  }) async {
    final directory =
        'open/${file.id}-${file.updatedAt.millisecondsSinceEpoch}';
    final cached = await DownloadTask(
      url: 'https://localhost',
      filename: file.name,
      directory: directory,
      baseDirectory: BaseDirectory.temporary,
    ).filePath();
    if (await File(cached).exists()) return cached;

    final request = await requestFor([file]);
    final task = DownloadTask(
      url: request.url,
      filename: request.filename,
      directory: directory,
      baseDirectory: BaseDirectory.temporary,
      updates: Updates.statusAndProgress,
    );
    return _run(task, onProgress, onStarted);
  }

  /// Saves [files] (a zip when several or a folder) to the device, with a
  /// system notification while it runs.
  Future<SavedDownload> save(
    List<FileItem> files, {
    void Function(double progress)? onProgress,
    void Function(String taskId)? onStarted,
  }) async {
    await _prepareSaveNotifications();
    final request = await requestFor(files);
    final task = DownloadTask(
      url: request.url,
      filename: request.filename,
      headers: request.headers,
      post: request.post,
      directory: 'downloads',
      baseDirectory: BaseDirectory.applicationSupport,
      group: _saveGroup,
      updates: Updates.statusAndProgress,
      // Resumable past Android's 9-minute task limit; needs Range support,
      // which only the single-file endpoint has.
      allowPause: request.post == null,
    );
    final path = await _run(task, onProgress, onStarted);
    if (!Platform.isAndroid) {
      return SavedDownload(path: path, inDownloads: false);
    }

    if (!await _granted(PermissionType.androidSharedStorage)) {
      throw const DownloadFailure('Storage permission denied.');
    }
    final shared = await _downloader.moveToSharedStorage(
      task,
      SharedStorage.downloads,
    );
    if (shared == null) {
      throw const DownloadFailure('Could not save to Downloads.');
    }
    return SavedDownload(path: shared, inDownloads: true);
  }

  /// Deletes the app's own copies of files: temporary copies made by
  /// [fetchForOpening], and saved downloads still inside the app (iOS keeps
  /// them there after the share sheet; Android moves them to Downloads).
  Future<void> clearLocalCopies() async {
    await _deleteDir('open', BaseDirectory.temporary);
    await _deleteDir('downloads', BaseDirectory.applicationSupport);
  }

  Future<void> _deleteDir(String directory, BaseDirectory base) async {
    try {
      final probe = await DownloadTask(
        url: 'https://localhost',
        filename: 'probe',
        directory: directory,
        baseDirectory: base,
      ).filePath();
      final dir = File(probe).parent;
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Nothing to clear, or storage unavailable.
    }
  }

  /// Hands [path] to the system "open with" flow. `false` when no app can.
  Future<bool> open(String path) => _downloader.openFile(filePath: path);

  Future<void> cancel(String taskId) =>
      _downloader.cancelTaskWithId(taskId).then((_) {});

  Future<String> _run(
    DownloadTask task,
    void Function(double progress)? onProgress,
    void Function(String taskId)? onStarted,
  ) async {
    onStarted?.call(task.taskId);
    final update = await _downloader.download(
      task,
      // Negative values are status signals, not progress.
      onProgress: onProgress == null
          ? null
          : (p) {
              if (p >= 0) onProgress(p);
            },
    );
    return switch (update.status) {
      TaskStatus.complete => task.filePath(),
      TaskStatus.canceled => throw const DownloadCancelled(),
      _ => throw DownloadFailure(
        update.exception?.description ?? 'Download failed',
      ),
    };
  }

  Future<void> _prepareSaveNotifications() async {
    if (_saveNotificationsReady) return;
    _saveNotificationsReady = true;
    _downloader.configureNotificationForGroup(
      _saveGroup,
      running: const TaskNotification('Downloading', '{filename}'),
      complete: const TaskNotification('Download complete', '{filename}'),
      error: const TaskNotification('Download failed', '{filename}'),
      progressBar: true,
    );
    // Without it the download still runs, just silently.
    await _granted(PermissionType.notifications);
  }

  Future<bool> _granted(PermissionType type) async {
    final permissions = _downloader.permissions;
    if (await permissions.status(type) == PermissionStatus.granted) {
      return true;
    }
    return await permissions.request(type) == PermissionStatus.granted;
  }
}
