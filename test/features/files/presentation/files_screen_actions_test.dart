import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/network/api_exception.dart';
import 'package:r16a_cloud_app/core/session/session_providers.dart';
import 'package:r16a_cloud_app/features/files/presentation/files_providers.dart';
import 'package:r16a_cloud_app/features/files/presentation/files_screen.dart';

import '../fakes.dart';

void main() {
  late FakeFilesApi api;
  late FakeFileDownloads downloads;

  setUp(() {
    api = FakeFilesApi();
    downloads = FakeFileDownloads();
  });

  /// Pumps the screen and answers the root listing with [items].
  Future<void> pumpWith(WidgetTester tester, List<Object> items) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filesApiProvider.overrideWithValue(api),
          fileDownloadsProvider.overrideWithValue(downloads),
          sessionApiProvider.overrideWithValue(FakeSessionApi()),
        ],
        child: const MaterialApp(home: FilesScreen()),
      ),
    );
    await tester.pump();
    api.calls.last.response.complete(fakePage(items.cast()));
    await tester.pumpAndSettle();
  }

  testWidgets('New folder creates and shows it', (tester) async {
    await pumpWith(tester, [fakeFile('a')]);

    await tester.tap(find.byTooltip('New folder'));
    await tester.pumpAndSettle();
    expect(find.text('Create Folder'), findsOneWidget);

    final create = find.widgetWithText(FilledButton, 'Create');
    expect(tester.widget<FilledButton>(create).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Projects');
    await tester.pump();
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(find.text('Projects'), findsOneWidget);
  });

  testWidgets('a duplicate name is reported in a snackbar', (tester) async {
    await pumpWith(tester, []);
    api.mutationError = const ApiException('dup', statusCode: 409);

    await tester.tap(find.byTooltip('New folder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(
      find.text('A file or folder with that name already exists.'),
      findsOneWidget,
    );
  });

  testWidgets('long-press → Delete asks first, then removes the file', (
    tester,
  ) async {
    await pumpWith(tester, [fakeFile('a'), fakeFile('b')]);

    await tester.longPress(find.text('a.txt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete file'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(api.deleted, ['a']);
    expect(find.text('a.txt'), findsNothing);
    expect(find.text('b.txt'), findsOneWidget);
  });

  testWidgets('long-press → Rename pre-fills the name', (tester) async {
    await pumpWith(tester, [fakeFile('a')]);

    await tester.longPress(find.text('a.txt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'a.txt');
    expect(field.controller!.selection.textInside('a.txt'), 'a');

    await tester.enterText(find.byType(TextField), 'b.txt');
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();

    expect(api.renamed, [('a', 'b.txt')]);
  });

  testWidgets('selection mode: count, single-item actions, bulk delete', (
    tester,
  ) async {
    await pumpWith(tester, [fakeFile('a'), fakeFile('b'), fakeFile('c')]);

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('a.txt'));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byTooltip('Rename'), findsOneWidget);
    expect(find.byTooltip('Share'), findsOneWidget);

    await tester.tap(find.text('c.txt'));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.byTooltip('Rename'), findsNothing);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete 2 items'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(api.deleted, unorderedEquals(['a', 'c']));
    expect(find.text('b.txt'), findsOneWidget);
    expect(find.text('2 selected'), findsNothing);
  });

  testWidgets('system back leaves selection mode before anything else', (
    tester,
  ) async {
    await pumpWith(tester, [fakeFile('a')]);
    await tester.longPress(find.text('a.txt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsNothing);
    expect(find.text('a.txt'), findsOneWidget);
  });

  testWidgets('share sheet hides self and owner and saves the checked users', (
    tester,
  ) async {
    await pumpWith(tester, [
      fakeFile('a', ownerId: 'owner-1', sharedWithIds: ['u3']),
    ]);

    await tester.longPress(find.text('a.txt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(find.text('Share file'), findsOneWidget);
    expect(find.text('owner@example.com'), findsNothing);
    expect(find.text('jdoe'), findsOneWidget);
    expect(find.text('Amy'), findsOneWidget);

    await tester.tap(find.text('jdoe'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Share'));
    await tester.pumpAndSettle();

    expect(api.sharingUpdates.single.$1, 'a');
    expect(api.sharingUpdates.single.$2, unorderedEquals(['u3', 'u2']));
    expect(find.text('Share file'), findsNothing);
  });

  testWidgets('Shared tab is read-only but can download', (tester) async {
    await pumpWith(tester, []);

    await tester.tap(find.text('Shared'));
    await tester.pump();
    api.sharedCalls.single.complete([fakeFile('theirs', ownerId: 'u2')]);
    await tester.pumpAndSettle();

    expect(find.byTooltip('New folder'), findsNothing);
    await tester.longPress(find.text('theirs.txt'));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Rename'), findsNothing);
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsNothing);
    await tester.tap(find.byTooltip('Download'));
    await tester.pumpAndSettle();
    expect(downloads.saved, [
      ['theirs'],
    ]);
  });

  testWidgets('selection Download saves all selected and leaves selection', (
    tester,
  ) async {
    await pumpWith(tester, [fakeFile('a'), fakeFile('b')]);
    await tester.longPress(find.text('a.txt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('b.txt'));
    await tester.pump();

    await tester.tap(find.byTooltip('Download'));
    await tester.pumpAndSettle();

    expect(downloads.saved.single, unorderedEquals(['a', 'b']));
    expect(find.text('2 selected'), findsNothing);
    expect(find.text('Saved to Downloads'), findsOneWidget);
  });

  testWidgets('long-press → Download on a folder', (tester) async {
    await pumpWith(tester, [fakeFile('docs', isDirectory: true)]);

    await tester.longPress(find.text('docs'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsNothing);
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();

    expect(downloads.saved, [
      ['docs'],
    ]);
  });

  testWidgets('a file no app can open says so', (tester) async {
    await pumpWith(tester, [fakeFile('x', extension: 'xyz')]);
    downloads.canOpen = false;

    await tester.tap(find.text('x.xyz'));
    await tester.pumpAndSettle();

    expect(find.text('No app found to open this file.'), findsOneWidget);
  });
}
