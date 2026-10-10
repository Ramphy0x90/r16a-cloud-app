import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Thumbnails kept on the device behind [ThumbnailCache]'s memory layer, so
/// they survive restarts and show offline. Mobile-only: the web keeps
/// thumbnails in memory only. Failures never surface: a broken store
/// behaves like an empty one.
abstract interface class ThumbnailStore {
  Future<Uint8List?> read(String fileId);
  Future<void> write(String fileId, Uint8List bytes);
  Future<void> clear();
}

/// [ThumbnailStore] as one file per thumbnail in a directory the OS may
/// purge (the app's cache directory). Kept under [maxBytes]: the least
/// recently used files go first, checked every [trimEvery] writes and once
/// at startup.
class FileThumbnailStore implements ThumbnailStore {
  FileThumbnailStore(this._directory, {this.maxBytes = defaultMaxBytes});

  /// `<app cache dir>/thumbnails`.
  factory FileThumbnailStore.appCache() => FileThumbnailStore(
    getApplicationCacheDirectory().then(
      (dir) => Directory('${dir.path}/thumbnails'),
    ),
  );

  /// Thumbnails are a few tens of KB: thousands of them fit.
  static const defaultMaxBytes = 150 * 1024 * 1024;
  static const trimEvery = 50;

  final Future<Directory> _directory;
  final int maxBytes;
  var _writesSinceTrim = 0;
  Future<Directory>? _ready;

  /// Created and trimmed once, before first use.
  Future<Directory> get _dir => _ready ??= _directory.then((dir) async {
    await dir.create(recursive: true);
    await _trim(dir);
    return dir;
  });

  @override
  Future<Uint8List?> read(String fileId) async {
    try {
      final file = await _file(fileId);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      // Marks it recently used for trimming; best effort.
      file.setLastModified(DateTime.now()).catchError((_) {});
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String fileId, Uint8List bytes) async {
    try {
      final file = await _file(fileId);
      // Written aside then renamed, so a reader never sees half a file.
      final partial = File('${file.path}.part');
      await partial.writeAsBytes(bytes, flush: true);
      await partial.rename(file.path);
      if (++_writesSinceTrim >= trimEvery) {
        _writesSinceTrim = 0;
        await _trim(await _dir);
      }
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      final dir = await _dir;
      if (await dir.exists()) await dir.delete(recursive: true);
      await dir.create(recursive: true);
    } catch (_) {}
  }

  Future<File> _file(String fileId) async {
    // Ids are UUIDs; anything else is reduced to a safe file name.
    final name = fileId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File('${(await _dir).path}/$name');
  }

  /// Drops least recently used files until at most 80% of [maxBytes]
  /// remain, so trimming doesn't run again on the very next write.
  Future<void> _trim(Directory dir) async {
    try {
      final entries = <(File, FileStat)>[];
      var total = 0;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        entries.add((entity, stat));
        total += stat.size;
      }
      if (total <= maxBytes) return;
      entries.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
      final target = maxBytes * 0.8;
      for (final (file, stat) in entries) {
        if (total <= target) break;
        try {
          await file.delete();
          total -= stat.size;
        } catch (_) {}
      }
    } catch (_) {}
  }
}
