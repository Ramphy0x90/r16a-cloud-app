import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/network/api_exception.dart';

import 'package:r16a_cloud_app/features/files/data/files_cache.dart';
import 'package:r16a_cloud_app/features/files/data/listing_store.dart';
import 'package:r16a_cloud_app/features/files/domain/file_sort.dart';

import '../fakes.dart';

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeFilesApi api;
  late MemoryListingStore store;
  late DateTime now;
  late FilesCache cache;

  setUp(() {
    api = FakeFilesApi();
    store = MemoryListingStore();
    now = DateTime(2026, 10, 3, 12);
    cache = FilesCache(api, store: store, now: () => now);
  });

  /// A fresh cache over the same store — like an app restart.
  FilesCache restart() => FilesCache(api, store: store, now: () => now);

  Future<void> loadRoot({String? etag, String id = 'a'}) async {
    final page = cache.getFirstPage(ownerId: 'o');
    await _settle();
    api.calls.last.response.complete(fakePage([fakeFile(id)]), etag: etag);
    await page;
  }

  group('memory layer', () {
    test('shares an in-flight request', () async {
      cache.getFirstPage(ownerId: 'o');
      cache.getFirstPage(ownerId: 'o');
      await _settle();
      expect(api.calls, hasLength(1));
    });

    test('keys by folder and sort', () async {
      cache.getFirstPage(ownerId: 'o');
      cache.getFirstPage(ownerId: 'o', parentId: 'p');
      cache.getFirstPage(ownerId: 'o', sortField: FileSortField.updatedAt);
      cache.getFirstPage(ownerId: 'o', sortDirection: FileSortDirection.desc);
      await _settle();
      expect(api.calls, hasLength(4));
    });

    test('a failed fetch is cached nowhere', () async {
      final first = cache.getFirstPage(ownerId: 'o');
      await _settle();
      api.calls.single.response.completeError(Exception('boom'));
      await expectLater(first, throwsException);

      cache.getFirstPage(ownerId: 'o');
      await _settle();
      expect(api.calls, hasLength(2));
      expect(store.entries, isEmpty);
    });
  });

  group('persistent layer', () {
    test('a restart within 5 min is served from the store', () async {
      await loadRoot();
      now = now.add(const Duration(minutes: 4));

      final page = await restart().getFirstPage(ownerId: 'o');

      expect(page.content.single.id, 'a');
      expect(api.calls, hasLength(1));
    });

    test(
      'past 5 min it revalidates with the ETag; 304 keeps the copy',
      () async {
        await loadRoot(etag: '"v1"');
        now = now.add(const Duration(minutes: 6));
        final fresh = restart();

        final page = fresh.getFirstPage(ownerId: 'o');
        await _settle();
        expect(api.calls.last.ifNoneMatch, '"v1"');
        api.calls.last.notModified();

        expect((await page).content.single.id, 'a');
        // The 304 refreshed the copy's age: served locally again.
        await restart().getFirstPage(ownerId: 'o');
        expect(api.calls, hasLength(2));
      },
    );

    test('a 200 on revalidation replaces the copy and its ETag', () async {
      await loadRoot(etag: '"v1"');
      now = now.add(const Duration(minutes: 6));
      cache = restart();

      await loadRoot(etag: '"v2"', id: 'b');

      final stored = store.entries.values.single;
      expect(stored.page.content.single.id, 'b');
      expect(stored.etag, '"v2"');
    });

    test(
      'invalidateFolder drops stored copies so no stale ETag is sent',
      () async {
        await loadRoot(etag: '"v1"');
        final child = cache.getFirstPage(ownerId: 'o', parentId: 'p');
        await _settle();
        api.calls.last.response.complete(fakePage([]), etag: '"c1"');
        await child;

        cache.invalidateFolder('o', null);
        cache.getFirstPage(ownerId: 'o');
        await _settle();

        expect(api.calls.last.ifNoneMatch, isNull);
        // Only the invalidated folder was dropped ('o::root::' prefix).
        expect(store.entries.keys.single, startsWith('o::p::'));
      },
    );

    test('a fetch overtaken by an invalidation is not persisted', () async {
      final page = cache.getFirstPage(ownerId: 'o');
      await _settle();
      cache.invalidateFolder('o', null);
      api.calls.single.response.complete(fakePage([fakeFile('stale')]));
      await page;
      await _settle();

      expect(store.entries, isEmpty);
    });

    test('offline, a stored copy of any age is served', () async {
      await loadRoot(etag: '"v1"');
      now = now.add(const Duration(hours: 3));
      cache = restart();

      final page = cache.getFirstPage(ownerId: 'o');
      await _settle();
      api.calls.last.response.completeError(
        const ApiException('Could not reach the server.'),
      );

      expect((await page).content.single.id, 'a');
      // Not kept in memory: the next request goes to the network again.
      cache.getFirstPage(ownerId: 'o');
      await _settle();
      expect(api.calls, hasLength(3));
    });

    test('a server error is not hidden by the stored copy', () async {
      await loadRoot();
      now = now.add(const Duration(minutes: 6));
      cache = restart();

      final page = cache.getFirstPage(ownerId: 'o');
      await _settle();
      api.calls.last.response.completeError(
        const ApiException('boom', statusCode: 500),
      );

      await expectLater(page, throwsA(isA<ApiException>()));
    });

    test('clear wipes the store (sign-out)', () async {
      await loadRoot();

      await cache.clear();

      expect(store.entries, isEmpty);
    });
  });

  test('cursor pages stay in memory only', () async {
    final page = cache.getNextPage(
      ownerId: 'o',
      cursor: 'c',
      sortField: FileSortField.name,
      sortDirection: FileSortDirection.asc,
    );
    await _settle();
    api.calls.single.response.complete(fakePage([]));
    await page;

    expect(store.entries, isEmpty);
  });
}
