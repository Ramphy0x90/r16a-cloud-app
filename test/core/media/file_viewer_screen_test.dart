import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/app/theme/app_colors.dart';
import 'package:r16a_cloud_app/app/theme/app_theme.dart';
import 'package:r16a_cloud_app/core/media/file_viewer_screen.dart';
import 'package:r16a_cloud_app/core/media/media_providers.dart';
import 'package:r16a_cloud_app/core/model/file_item.dart';

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

  Future<void> pumpViewer(
    WidgetTester tester, {
    String secondExtension = 'jpg',
    Future<Uri> Function(FileItem)? videoSource,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaApiProvider.overrideWithValue(FakeMediaApi()),
          fileDownloadsProvider.overrideWithValue(downloads),
          if (videoSource != null)
            videoSourceProvider.overrideWithValue(videoSource),
        ],
        child: MaterialApp(
          home: FileViewerScreen(
            files: [
              fakeFile('a', extension: 'jpg'),
              fakeFile('b', extension: secondExtension),
            ],
            initialIndex: 1,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the title stays light on the dark bar in the light theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaApiProvider.overrideWithValue(FakeMediaApi()),
          fileDownloadsProvider.overrideWithValue(downloads),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: FileViewerScreen(
            files: [fakeFile('a', extension: 'jpg')],
            initialIndex: 0,
          ),
        ),
      ),
    );
    await tester.pump();

    final style = DefaultTextStyle.of(tester.element(find.text('a.jpg'))).style;
    expect(style.color, AppColors.darkForeground);
  });

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

  testWidgets('a video shows its placeholder while the stream is set up', (
    tester,
  ) async {
    final source = Completer<Uri>();
    await pumpViewer(
      tester,
      secondExtension: 'mp4',
      videoSource: (_) => source.future,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Could not play this video.'), findsNothing);
  });

  testWidgets('a video that cannot play offers another app', (tester) async {
    await pumpViewer(
      tester,
      secondExtension: 'mkv',
      videoSource: (_) async => throw Exception('unsupported'),
    );
    await tester.pump();

    expect(find.text('Could not play this video.'), findsOneWidget);

    await tester.tap(find.text('Open with another app'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(downloads.fetched, ['b']);
    expect(downloads.opened, hasLength(1));
  });

  testWidgets('the video source is a download-token link', (tester) async {
    final container = ProviderContainer(
      overrides: [mediaApiProvider.overrideWithValue(FakeMediaApi())],
    );
    addTearDown(container.dispose);

    final uri = await container.read(videoSourceProvider)(
      fakeFile('v1', extension: 'mp4'),
    );

    expect(uri.path, endsWith('/fs/download/token'));
    expect(uri.queryParameters, {'token': 'tkn-v1'});
  });
}
