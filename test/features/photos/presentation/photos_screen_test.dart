import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/media/file_viewer_screen.dart';
import 'package:r16a_cloud_app/core/media/media_providers.dart';
import 'package:r16a_cloud_app/core/session/session_providers.dart';
import 'package:r16a_cloud_app/features/photos/domain/photo_year.dart';
import 'package:r16a_cloud_app/features/photos/presentation/photos_providers.dart';
import 'package:r16a_cloud_app/features/photos/presentation/photos_screen.dart';
import 'package:r16a_cloud_app/features/photos/presentation/widgets/photo_placeholder_tile.dart';
import 'package:r16a_cloud_app/features/photos/presentation/widgets/photo_tile.dart';

import '../../files/fakes.dart';
import '../fakes.dart';

void main() {
  late FakePhotosApi api;

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photosApiProvider.overrideWithValue(api),
          mediaApiProvider.overrideWithValue(FakeMediaApi()),
          sessionApiProvider.overrideWithValue(FakeSessionApi()),
        ],
        child: const MaterialApp(home: PhotosScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  test('columns follow the web breakpoints', () {
    expect(PhotosScreen.columnsFor(390), 3);
    expect(PhotosScreen.columnsFor(480), 4);
  });

  testWidgets('empty state uses the web copy', (tester) async {
    api = FakePhotosApi();
    await pumpScreen(tester);

    expect(find.text('No photos yet'), findsOneWidget);
    expect(
      find.text('Upload photos or videos to see them here'),
      findsOneWidget,
    );
  });

  testWidgets('a year shows placeholders that load its photos', (tester) async {
    api = FakePhotosApi(
      years: const [PhotoYear(year: 2025, count: 2)],
      shared: [fakePhoto('s', DateTime.utc(2025, 6), owner: 'u2')],
    );
    await pumpScreen(tester);

    expect(find.text('2025'), findsOneWidget);
    expect(find.text('3 photos'), findsOneWidget);
    expect(find.byType(PhotoPlaceholderTile), findsNWidgets(2));
    expect(api.calls.single.year, 2025);

    api.calls.single.response.complete(
      photoPage([
        fakePhoto('a', DateTime.utc(2025, 3)),
        fakePhoto('b', DateTime.utc(2025, 2)),
      ]),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(PhotoPlaceholderTile), findsNothing);
    expect(find.byType(PhotoTile), findsNWidgets(3));
    // Only the other user's photo carries the shared badge.
    expect(find.byTooltip('Friend'), findsOneWidget);
  });

  testWidgets('tapping a photo opens the viewer on the year', (tester) async {
    api = FakePhotosApi(years: const [PhotoYear(year: 2025, count: 2)]);
    await pumpScreen(tester);
    api.calls.single.response.complete(
      photoPage([
        fakePhoto('a', DateTime.utc(2025, 3)),
        fakePhoto('b', DateTime.utc(2025, 2)),
      ]),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(PhotoTile).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final viewer = tester.widget<FileViewerScreen>(
      find.byType(FileViewerScreen),
    );
    expect(viewer.files.map((f) => f.id), ['a', 'b']);
    expect(viewer.initialIndex, 1);
    expect(viewer.heroTagPrefix, 'photos:');
  });

  testWidgets('a failed timeline offers Retry', (tester) async {
    api = FakePhotosApi()..yearsError = Exception('down');
    await pumpScreen(tester);

    expect(find.text('Could not load photos right now.'), findsOneWidget);
    api.yearsError = null;
    api.years = const [PhotoYear(year: 2024, count: 0)];
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.text('2024'), findsOneWidget);
  });
}
