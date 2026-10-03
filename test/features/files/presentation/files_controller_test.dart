import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/session/session_providers.dart';
import 'package:r16a_cloud_app/features/files/domain/file_sort.dart';
import 'package:r16a_cloud_app/features/files/presentation/files_providers.dart';
import 'package:r16a_cloud_app/features/files/presentation/files_state.dart';

import '../fakes.dart';

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeFilesApi api;
  late ProviderContainer container;

  FilesState state() => container.read(filesControllerProvider);

  setUp(() async {
    api = FakeFilesApi();
    container = ProviderContainer(
      overrides: [
        filesApiProvider.overrideWithValue(api),
        sessionApiProvider.overrideWithValue(FakeSessionApi()),
      ],
    );
    // Keep the autoDispose controller alive for the whole test.
    container.listen(filesControllerProvider, (_, _) {});
    await _settle();
  });

  tearDown(() => container.dispose());

  test('loads the root folder on start', () async {
    expect(state().loading, isTrue);
    expect(api.calls.single.parentId, isNull);

    api.calls.single.response.complete(
      fakePage([fakeFile('a')], nextCursor: 'c1'),
    );
    await _settle();

    expect(state().loading, isFalse);
    expect(state().items.single.id, 'a');
    expect(state().hasMore, isTrue);
    expect(state().nextCursor, 'c1');
  });

  test(
    'openFolder / goUp navigate, and going back is served from cache',
    () async {
      final docs = fakeFile('docs', isDirectory: true);
      api.calls.single.response.complete(fakePage([docs]));
      await _settle();

      container.read(filesControllerProvider.notifier).openFolder(docs);
      await _settle();
      expect(state().currentFolder?.id, 'docs');
      expect(api.calls.last.parentId, 'docs');
      api.calls.last.response.complete(
        fakePage([fakeFile('inner', parentId: 'docs')]),
      );
      await _settle();
      expect(state().items.single.id, 'inner');

      expect(container.read(filesControllerProvider.notifier).goUp(), isTrue);
      await _settle();
      expect(state().breadcrumbs, isEmpty);
      expect(state().items.single.id, 'docs');
      expect(api.calls, hasLength(2));

      expect(container.read(filesControllerProvider.notifier).goUp(), isFalse);
    },
  );

  test('a load-more that resolves after navigation is dropped', () async {
    final docs = fakeFile('docs', isDirectory: true);
    api.calls.single.response.complete(fakePage([docs], nextCursor: 'c1'));
    await _settle();

    final controller = container.read(filesControllerProvider.notifier);
    controller.loadMore();
    await _settle();
    final loadMoreCall = api.calls.last;
    expect(loadMoreCall.cursor, 'c1');

    controller.openFolder(docs);
    await _settle();
    api.calls.last.response.complete(fakePage([fakeFile('inner')]));
    loadMoreCall.response.complete(fakePage([fakeFile('stale')]));
    await _settle();

    expect(state().items.map((f) => f.id), ['inner']);
  });

  test('loadMore appends the next page', () async {
    api.calls.single.response.complete(
      fakePage([fakeFile('a')], nextCursor: 'c1'),
    );
    await _settle();

    container.read(filesControllerProvider.notifier).loadMore();
    await _settle();
    api.calls.last.response.complete(fakePage([fakeFile('b')]));
    await _settle();

    expect(state().items.map((f) => f.id), ['a', 'b']);
    expect(state().hasMore, isFalse);
  });

  test('changing the sort field resets the direction to ascending', () async {
    api.calls.single.response.complete(fakePage([]));
    await _settle();
    final controller = container.read(filesControllerProvider.notifier);

    controller.setSortDirection(FileSortDirection.desc);
    await _settle();
    expect(api.calls.last.sortDirection, FileSortDirection.desc);

    controller.setSortField(FileSortField.updatedAt);
    await _settle();
    expect(state().sortDirection, FileSortDirection.asc);
    expect(api.calls.last.sortField, FileSortField.updatedAt);
    expect(api.calls.last.sortDirection, FileSortDirection.asc);
  });

  test('shared tab lists shared-with-me and does not open folders', () async {
    final docs = fakeFile('docs', isDirectory: true);
    api.calls.single.response.complete(fakePage([docs]));
    await _settle();
    final controller = container.read(filesControllerProvider.notifier);
    controller.openFolder(docs);
    await _settle();

    controller.setTab(FilesTab.shared);
    await _settle();
    expect(state().breadcrumbs, isEmpty);
    api.sharedCalls.single.complete([fakeFile('theirs', isDirectory: true)]);
    await _settle();
    expect(state().items.single.id, 'theirs');
    expect(state().readOnly, isTrue);

    final callsBefore = api.calls.length;
    controller.openFolder(state().items.single);
    await _settle();
    expect(state().breadcrumbs, isEmpty);
    expect(api.calls, hasLength(callsBefore));
  });

  test('a failed load sets error and retry clears it', () async {
    api.calls.single.response.completeError(Exception('down'));
    await _settle();
    expect(state().error, isNotNull);
    expect(state().loading, isFalse);

    container.read(filesControllerProvider.notifier).retry();
    await _settle();
    expect(state().error, isNull);
    expect(state().loading, isTrue);
    api.calls.last.response.complete(fakePage([fakeFile('a')]));
    await _settle();
    expect(state().items, hasLength(1));
  });

  test('refresh bypasses the cache and keeps the list visible', () async {
    api.calls.single.response.complete(fakePage([fakeFile('a')]));
    await _settle();

    final refresh = container.read(filesControllerProvider.notifier).refresh();
    await _settle();
    expect(api.calls, hasLength(2));
    expect(state().loading, isFalse);
    expect(state().items.single.id, 'a');

    api.calls.last.response.complete(fakePage([fakeFile('a'), fakeFile('b')]));
    await refresh;
    expect(state().items, hasLength(2));
  });
}
