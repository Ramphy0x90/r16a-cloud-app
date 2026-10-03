import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/features/files/data/files_cache.dart';
import 'package:r16a_cloud_app/features/files/domain/file_sort.dart';

import '../fakes.dart';

void main() {
  late FakeFilesApi api;
  late DateTime now;
  late FilesCache cache;

  setUp(() {
    api = FakeFilesApi();
    now = DateTime(2026, 10, 3, 12);
    cache = FilesCache(api, now: () => now);
  });

  test('serves the same first page within the TTL, refetches after', () async {
    final first = cache.getFirstPage(ownerId: 'o');
    api.calls.single.response.complete(fakePage([fakeFile('a')]));
    await first;

    now = now.add(const Duration(seconds: 59));
    await cache.getFirstPage(ownerId: 'o');
    expect(api.calls, hasLength(1));

    now = now.add(const Duration(seconds: 2));
    cache.getFirstPage(ownerId: 'o');
    expect(api.calls, hasLength(2));
  });

  test('shares an in-flight request', () {
    cache.getFirstPage(ownerId: 'o');
    cache.getFirstPage(ownerId: 'o');
    expect(api.calls, hasLength(1));
  });

  test('keys by folder and sort', () {
    cache.getFirstPage(ownerId: 'o');
    cache.getFirstPage(ownerId: 'o', parentId: 'p');
    cache.getFirstPage(ownerId: 'o', sortField: FileSortField.updatedAt);
    cache.getFirstPage(ownerId: 'o', sortDirection: FileSortDirection.desc);
    expect(api.calls, hasLength(4));
  });

  test(
    'invalidateFolder evicts first and cursor pages of that folder only',
    () {
      cache.getFirstPage(ownerId: 'o', parentId: 'p');
      cache.getNextPage(
        ownerId: 'o',
        parentId: 'p',
        cursor: 'c',
        sortField: FileSortField.name,
        sortDirection: FileSortDirection.asc,
      );
      cache.getFirstPage(ownerId: 'o');

      cache.invalidateFolder('o', 'p');

      cache.getFirstPage(ownerId: 'o', parentId: 'p');
      cache.getNextPage(
        ownerId: 'o',
        parentId: 'p',
        cursor: 'c',
        sortField: FileSortField.name,
        sortDirection: FileSortDirection.asc,
      );
      cache.getFirstPage(ownerId: 'o');
      expect(api.calls, hasLength(5));
    },
  );

  test('a failed fetch is not cached', () async {
    final first = cache.getFirstPage(ownerId: 'o');
    api.calls.single.response.completeError(Exception('boom'));
    await expectLater(first, throwsException);

    cache.getFirstPage(ownerId: 'o');
    expect(api.calls, hasLength(2));
  });
}
