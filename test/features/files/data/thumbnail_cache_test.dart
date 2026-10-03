import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/features/files/data/files_api.dart';
import 'package:r16a_cloud_app/features/files/data/thumbnail_cache.dart';

/// Thumbnail calls stay pending until the test answers them.
class _PendingThumbnailsApi extends FilesApi {
  _PendingThumbnailsApi() : super(Dio());

  final calls = <String, Completer<Uint8List>>{};

  @override
  Future<Uint8List> getThumbnail(
    String id, {
    ThumbnailSize size = ThumbnailSize.small,
    Duration? receiveTimeout,
  }) => (calls[id] = Completer<Uint8List>()).future;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _PendingThumbnailsApi api;
  late DateTime now;
  late ThumbnailCache cache;

  setUp(() {
    api = _PendingThumbnailsApi();
    now = DateTime(2026, 10, 3, 12);
    cache = ThumbnailCache(api, now: () => now);
  });

  test(
    'shares in-flight requests and serves cached bytes within the TTL',
    () async {
      final a = cache.get('f1');
      final b = cache.get('f1');
      await _settle();
      expect(api.calls, hasLength(1));

      api.calls['f1']!.complete(Uint8List.fromList([1]));
      expect(await a, [1]);
      expect(await b, [1]);

      now = now.add(const Duration(minutes: 4));
      expect(await cache.get('f1'), [1]);
      expect(api.calls, hasLength(1));

      now = now.add(const Duration(minutes: 2));
      cache.get('f1');
      await _settle();
      expect(api.calls['f1']!.isCompleted, isFalse);
    },
  );

  test('runs at most 4 fetches at a time', () async {
    for (var i = 0; i < 6; i++) {
      cache.get('f$i');
    }
    await _settle();
    expect(api.calls.keys, ['f0', 'f1', 'f2', 'f3']);

    api.calls['f0']!.complete(Uint8List(0));
    await _settle();
    await _settle();
    expect(api.calls.keys, contains('f4'));
    expect(api.calls.keys, isNot(contains('f5')));
  });

  test('a failure yields null and is retried next time', () async {
    final first = cache.get('f1');
    await _settle();
    api.calls['f1']!.completeError(Exception('404'));
    expect(await first, isNull);

    final second = cache.get('f1');
    await _settle();
    api.calls['f1']!.complete(Uint8List.fromList([2]));
    expect(await second, [2]);
  });

  test('evicts the least recently used beyond 400 entries', () async {
    for (var i = 0; i <= ThumbnailCache.maxEntries; i++) {
      final future = cache.get('f$i');
      await _settle();
      api.calls['f$i']!.complete(Uint8List(0));
      await future;
      now = now.add(const Duration(milliseconds: 1));
    }

    api.calls.clear();
    await cache.get('f${ThumbnailCache.maxEntries}');
    expect(api.calls, isEmpty);

    cache.get('f0');
    await _settle();
    expect(api.calls.keys, ['f0']);
  });
}
