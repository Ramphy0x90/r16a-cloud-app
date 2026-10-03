import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/network/api_exception.dart';
import 'package:r16a_cloud_app/core/session/session_providers.dart';
import 'package:r16a_cloud_app/features/files/domain/file_sort.dart';
import 'package:r16a_cloud_app/features/files/presentation/files_controller.dart';
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
  FilesController controller() =>
      container.read(filesControllerProvider.notifier);
  List<String> ids() => state().items.map((f) => f.id).toList();

  /// Starts the controller and answers the root listing with [items].
  Future<void> start(List<Object> items) async {
    container.listen(filesControllerProvider, (_, _) {});
    await _settle();
    api.calls.single.response.complete(fakePage(items.cast()));
    await _settle();
  }

  setUp(() {
    api = FakeFilesApi();
    container = ProviderContainer(
      overrides: [
        filesApiProvider.overrideWithValue(api),
        sessionApiProvider.overrideWithValue(FakeSessionApi()),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('selection', () {
    test('toggles, and navigating away clears it', () async {
      final docs = fakeFile('docs', isDirectory: true);
      await start([docs, fakeFile('a')]);

      controller().setSelectionMode(true);
      controller().toggleSelected(docs);
      controller().toggleSelected(state().items[1]);
      controller().toggleSelected(docs);
      expect(state().selectedFiles.map((f) => f.id), ['a']);

      controller().setSelectionMode(false);
      expect(state().selectedIds, isEmpty);

      controller().startSelection(docs);
      expect(state().selectionMode, isTrue);
      controller().openFolder(docs);
      expect(state().selectionMode, isFalse);
      expect(state().selectedIds, isEmpty);
    });

    test('switching tabs clears it', () async {
      await start([fakeFile('a')]);
      controller().startSelection(state().items.single);

      controller().setTab(FilesTab.shared);

      expect(state().selectionMode, isFalse);
    });
  });

  group('createFolder', () {
    test('inserts folders-first in sort order without reloading', () async {
      await start([fakeFile('b-dir', isDirectory: true), fakeFile('a')]);

      await controller().createFolder('  a-dir ');

      expect(ids(), ['a-dir', 'b-dir', 'a']);
      expect(api.calls, hasLength(1));
    });

    test('respects a descending sort', () async {
      await start([]);
      controller().setSortDirection(FileSortDirection.desc);
      await _settle();
      api.calls.last.response.complete(
        fakePage([fakeFile('b-dir', isDirectory: true), fakeFile('z')]),
      );
      await _settle();

      await controller().createFolder('c-dir');

      expect(ids(), ['c-dir', 'b-dir', 'z']);
    });

    test('invalidates the folder so coming back refetches it', () async {
      final docs = fakeFile('docs', isDirectory: true);
      await start([docs]);
      await controller().createFolder('new');

      controller().openFolder(docs);
      await _settle();
      api.calls.last.response.complete(fakePage([]));
      await _settle();
      controller().goUp();
      await _settle();

      expect(api.calls.last.parentId, isNull);
      expect(api.calls, hasLength(3));
    });

    test('failure leaves the list alone and rethrows', () async {
      await start([fakeFile('a')]);
      api.mutationError = const ApiException('dup', statusCode: 409);

      await expectLater(
        controller().createFolder('a'),
        throwsA(isA<ApiException>()),
      );
      expect(ids(), ['a']);
    });
  });

  test('rename swaps in the server copy and leaves selection mode', () async {
    await start([fakeFile('a')]);
    controller().startSelection(state().items.single);

    await controller().rename(state().items.single, 'b.txt');

    expect(api.renamed, [('a', 'b.txt')]);
    expect(state().items.single.name, 'b.txt');
    expect(state().selectionMode, isFalse);
  });

  test('updateSharing stores the new share list', () async {
    await start([fakeFile('a')]);

    await controller().updateSharing(state().items.single, ['u2']);

    expect(api.sharingUpdates.single.$1, 'a');
    expect(api.sharingUpdates.single.$2, ['u2']);
    expect(state().items.single.isShared, isTrue);
  });

  group('delete', () {
    test('removes the item locally', () async {
      await start([fakeFile('a'), fakeFile('b')]);

      await controller().delete(state().items.first);

      expect(api.deleted, ['a']);
      expect(ids(), ['b']);
    });

    test(
      'bulk delete removes the selection and exits selection mode',
      () async {
        await start([fakeFile('a'), fakeFile('b'), fakeFile('c')]);
        controller().setSelectionMode(true);
        controller().toggleSelected(state().items[0]);
        controller().toggleSelected(state().items[2]);

        await controller().deleteSelected();

        expect(api.deleted, unorderedEquals(['a', 'c']));
        expect(ids(), ['b']);
        expect(state().selectionMode, isFalse);
      },
    );

    test('a partial bulk failure reloads the folder from the server', () async {
      await start([fakeFile('a'), fakeFile('b')]);
      api.failingDeletes.add('b');
      controller().setSelectionMode(true);
      controller().toggleSelected(state().items[0]);
      controller().toggleSelected(state().items[1]);

      await expectLater(
        controller().deleteSelected(),
        throwsA(isA<ApiException>()),
      );
      await _settle();

      expect(state().selectionMode, isFalse);
      // Not served from the (now stale) cache.
      expect(api.calls, hasLength(2));
      api.calls.last.response.complete(fakePage([fakeFile('b')]));
      await _settle();
      expect(ids(), ['b']);
    });
  });

  test('load more does not duplicate a locally created folder', () async {
    container.listen(filesControllerProvider, (_, _) {});
    await _settle();
    api.calls.single.response.complete(
      fakePage([fakeFile('a', isDirectory: true)], nextCursor: 'c1'),
    );
    await _settle();
    await controller().createFolder('z');

    controller().loadMore();
    await _settle();
    api.calls.last.response.complete(
      fakePage([fakeFile('z', isDirectory: true), fakeFile('b')]),
    );
    await _settle();

    expect(ids(), ['a', 'z', 'b']);
  });
}
