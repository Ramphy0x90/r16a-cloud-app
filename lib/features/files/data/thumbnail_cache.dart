import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'files_api.dart';

class _CachedThumbnail {
  _CachedThumbnail(this.bytes, this.expiresAt, this.lastAccessedAt);

  final Uint8List bytes;
  final DateTime expiresAt;
  DateTime lastAccessedAt;
}

/// Port of the thumbnail half of the web client's `ImagePreviewService`
/// (`services/image-preview.service.ts`) plus the `mergeMap(..., 4)` queue in
/// `FilesPage`: small thumbnails kept 5 min, at most 400 (least recently used
/// evicted first), in-flight requests shared, at most 4 fetches at a time.
class ThumbnailCache {
  ThumbnailCache(this._api, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const ttl = Duration(minutes: 5);
  static const maxEntries = 400;
  static const maxConcurrent = 4;

  final FilesApi _api;
  final DateTime Function() _now;
  final _cache = <String, _CachedThumbnail>{};
  final _inFlight = <String, Future<Uint8List?>>{};
  final _waiting = Queue<Completer<void>>();
  var _running = 0;

  /// Thumbnail bytes for [fileId], or `null` when the server has none (the
  /// failure is not cached, so a later call retries — like the web).
  Future<Uint8List?> get(String fileId) {
    final cached = _cache[fileId];
    if (cached != null) {
      final now = _now();
      if (cached.expiresAt.isAfter(now)) {
        cached.lastAccessedAt = now;
        return Future.value(cached.bytes);
      }
      _cache.remove(fileId);
    }

    // Block body on purpose: returning the removed future from the callback
    // would make `whenComplete` wait on itself.
    return _inFlight[fileId] ??= _fetch(fileId).whenComplete(() {
      _inFlight.remove(fileId);
    });
  }

  void clear() => _cache.clear();

  Future<Uint8List?> _fetch(String fileId) async {
    await _acquire();
    try {
      final bytes = await _api.getThumbnail(fileId);
      final now = _now();
      _cache[fileId] = _CachedThumbnail(bytes, now.add(ttl), now);
      _evictExcess();
      return bytes;
    } catch (_) {
      return null;
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_running < maxConcurrent) {
      _running++;
      return;
    }
    final slot = Completer<void>();
    _waiting.add(slot);
    await slot.future;
  }

  /// Hands the slot straight to the next waiter, or frees it.
  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _running--;
    }
  }

  void _evictExcess() {
    if (_cache.length <= maxEntries) return;
    final byAge = _cache.entries.toList()
      ..sort(
        (a, b) => a.value.lastAccessedAt.compareTo(b.value.lastAccessedAt),
      );
    for (final entry in byAge.take(_cache.length - maxEntries)) {
      _cache.remove(entry.key);
    }
  }
}
