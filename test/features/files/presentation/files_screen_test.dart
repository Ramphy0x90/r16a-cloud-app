import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/media/file_viewer_screen.dart';
import 'package:r16a_cloud_app/core/media/media_providers.dart';
import 'package:r16a_cloud_app/core/session/session_providers.dart';
import 'package:r16a_cloud_app/features/files/domain/file_sort.dart';
import 'package:r16a_cloud_app/features/files/presentation/files_providers.dart';
import 'package:r16a_cloud_app/features/files/presentation/files_screen.dart';
import 'package:r16a_cloud_app/features/files/presentation/widgets/file_grid_tile.dart';
import 'package:r16a_cloud_app/features/files/presentation/widgets/file_list_tile.dart';

import '../fakes.dart';

void main() {
  late FakeFilesApi api;
  late FakeMediaApi media;
  late FakeFileDownloads downloads;

  setUp(() {
    api = FakeFilesApi();
    media = FakeMediaApi();
    downloads = FakeFileDownloads();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filesApiProvider.overrideWithValue(api),
          mediaApiProvider.overrideWithValue(media),
          fileDownloadsProvider.overrideWithValue(downloads),
          sessionApiProvider.overrideWithValue(FakeSessionApi()),
        ],
        child: const MaterialApp(home: FilesScreen()),
      ),
    );
    await tester.pump();
  }

  /// Answers the latest listing request and lets the UI settle.
  Future<void> answer(WidgetTester tester, List<Object> items) async {
    api.calls.last.response.complete(fakePage(items.cast()));
    await tester.pumpAndSettle();
  }

  testWidgets('shows a spinner, then the files in the preferred view', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await answer(tester, [fakeFile('docs', isDirectory: true), fakeFile('a')]);

    // FakeSessionApi prefers the list view.
    expect(find.byType(FileListTile), findsNWidgets(2));
    expect(find.text('a.txt'), findsOneWidget);
  });

  testWidgets('empty states use the web copy', (tester) async {
    await pumpScreen(tester);
    await answer(tester, []);
    expect(find.text('No files yet'), findsOneWidget);

    await tester.tap(find.text('Shared'));
    await tester.pump();
    api.sharedCalls.single.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('Nothing shared with you yet'), findsOneWidget);
  });

  testWidgets(
    'opening a folder shows the back chip; system back returns to root',
    (tester) async {
      await pumpScreen(tester);
      await answer(tester, [fakeFile('docs', isDirectory: true)]);

      await tester.tap(find.text('docs'));
      await tester.pump();
      await answer(tester, [fakeFile('inner', parentId: 'docs')]);

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('inner.txt'), findsOneWidget);
      expect(find.text('My files'), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('My files'), findsOneWidget);
      expect(find.text('docs'), findsOneWidget);
    },
  );

  testWidgets('options sheet switches view and flips the active sort', (
    tester,
  ) async {
    await pumpScreen(tester);
    await answer(tester, [fakeFile('a')]);

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Grid'));
    await tester.pumpAndSettle();
    expect(find.byType(FileGridTile), findsOneWidget);

    await tester.tap(find.text('Name'));
    await tester.pump();
    expect(api.calls.last.sortField, FileSortField.name);
    expect(api.calls.last.sortDirection, FileSortDirection.desc);
    await answer(tester, [fakeFile('a')]);
  });

  testWidgets('a failed load offers Retry', (tester) async {
    await pumpScreen(tester);
    api.calls.single.response.completeError(Exception('down'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load files right now.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(api.calls, hasLength(2));
    await answer(tester, [fakeFile('a')]);
    expect(find.text('a.txt'), findsOneWidget);
  });

  testWidgets('thumbnails are requested for images only', (tester) async {
    await pumpScreen(tester);
    await answer(tester, [
      fakeFile('photo', extension: 'jpg'),
      fakeFile('doc', extension: 'pdf'),
    ]);

    expect(media.thumbnailCalls.map((c) => c.$1), ['photo']);
  });

  testWidgets('tapping an image opens the viewer; other files open outside', (
    tester,
  ) async {
    await pumpScreen(tester);
    await answer(tester, [
      fakeFile('a', extension: 'png'),
      fakeFile('doc', extension: 'pdf'),
      fakeFile('b', extension: 'jpg'),
    ]);

    await tester.tap(find.text('doc.pdf'));
    await tester.pumpAndSettle();
    expect(find.byType(FileViewerScreen), findsNothing);
    expect(downloads.fetched, ['doc']);
    expect(downloads.opened, ['/tmp/doc.pdf']);
    // The "Opening…" dialog is gone once the file is handed off.
    expect(find.textContaining('Opening'), findsNothing);

    await tester.tap(find.text('b.jpg'));
    // The preview never resolves in tests, so the spinner keeps animating.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final viewer = tester.widget<FileViewerScreen>(
      find.byType(FileViewerScreen),
    );
    expect(viewer.files.map((f) => f.id), ['a', 'b']);
    expect(viewer.initialIndex, 1);
    expect(viewer.heroTagPrefix, 'files:');
    // The tapped tile carries the matching tag.
    expect(
      find.byWidgetPredicate((w) => w is Hero && w.tag == 'files:b'),
      findsWidgets,
    );
    expect(media.downloadCalls, ['b']);
  });
}
