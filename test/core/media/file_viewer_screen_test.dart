import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/media/file_viewer_screen.dart';
import 'package:r16a_cloud_app/core/media/media_providers.dart';

import '../../features/files/fakes.dart';

void main() {
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
  late FakeFileDownloads downloads;
  late List<MethodCall> shares;

  setUp(() {
    downloads = FakeFileDownloads();
    shares = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
          shares.add(call);
          return 'dev.fluttercommunity.plus/share/unavailable';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null);
  });

  Future<void> pumpViewer(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaApiProvider.overrideWithValue(FakeMediaApi()),
          fileDownloadsProvider.overrideWithValue(downloads),
        ],
        child: MaterialApp(
          home: FileViewerScreen(
            files: [
              fakeFile('a', extension: 'jpg'),
              fakeFile('b', extension: 'jpg'),
            ],
            initialIndex: 1,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Download saves the image on screen', (tester) async {
    await pumpViewer(tester);

    await tester.tap(find.byTooltip('Download'));
    await tester.pump();
    await tester.pump();

    expect(downloads.saved, [
      ['b'],
    ]);
    expect(find.text('Saved to Downloads'), findsOneWidget);
  });

  testWidgets('Share via… hands a local copy to the share sheet', (
    tester,
  ) async {
    await pumpViewer(tester);

    await tester.tap(find.byTooltip('Share via…'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(downloads.fetched, ['b']);
    expect(shares.single.method, 'share');
    expect(shares.single.arguments.toString(), contains('/tmp/b.jpg'));
  });
}
