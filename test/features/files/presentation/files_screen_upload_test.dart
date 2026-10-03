import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/media/media_providers.dart';
import 'package:r16a_cloud_app/core/model/file_item.dart';
import 'package:r16a_cloud_app/core/session/session_providers.dart';
import 'package:r16a_cloud_app/features/files/data/file_uploader.dart';
import 'package:r16a_cloud_app/features/files/data/files_api.dart';
import 'package:r16a_cloud_app/features/files/data/upload_source.dart';
import 'package:r16a_cloud_app/features/files/presentation/files_providers.dart';
import 'package:r16a_cloud_app/features/files/presentation/files_screen.dart';
import 'package:r16a_cloud_app/features/files/presentation/upload_picker.dart';

import '../fakes.dart';

class _ManualUploader extends FileUploader {
  _ManualUploader() : super(FilesApi(Dio()));

  final pending = <String, Completer<FileItem>>{};

  @override
  Future<FileItem> upload({
    required String ownerId,
    String? parentId,
    required UploadSource source,
    void Function(int sentBytes)? onProgress,
  }) => (pending[source.name] = Completer<FileItem>()).future;
}

UploadSource _source(String name) => UploadSource(
  name: name,
  size: 10,
  openRead: (start, end) => const Stream.empty(),
);

void main() {
  late FakeFilesApi api;
  late FakeFileDownloads downloads;
  late _ManualUploader uploader;
  late List<UploadPick> picks;

  setUp(() {
    api = FakeFilesApi();
    downloads = FakeFileDownloads();
    uploader = _ManualUploader();
    picks = [];
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filesApiProvider.overrideWithValue(api),
          mediaApiProvider.overrideWithValue(FakeMediaApi()),
          fileDownloadsProvider.overrideWithValue(downloads),
          sessionApiProvider.overrideWithValue(FakeSessionApi()),
          fileUploaderProvider.overrideWithValue(uploader),
          uploadPickerProvider.overrideWithValue((pick) async {
            picks.add(pick);
            return [_source('a.txt'), _source('b.txt')];
          }),
        ],
        child: const MaterialApp(home: FilesScreen()),
      ),
    );
    await tester.pump();
    api.calls.last.response.complete(fakePage([]));
    await tester.pumpAndSettle();
  }

  testWidgets('upload shows progress, then a dismissible error banner', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Upload'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Photos & videos'));
    await tester.pumpAndSettle();

    expect(picks, [UploadPick.media]);
    expect(find.text('Uploading'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    final button = find.ancestor(
      of: find.byIcon(Icons.upload_rounded),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(button).onPressed, isNull);

    uploader.pending['a.txt']!.complete(fakeFile('a'));
    uploader.pending['b.txt']!.completeError(Exception('io'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Uploading'), findsNothing);
    expect(find.text('Some uploads failed'), findsOneWidget);
    expect(find.text('b.txt: Upload failed'), findsOneWidget);
    expect(tester.widget<IconButton>(button).onPressed, isNotNull);

    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    expect(find.text('Some uploads failed'), findsNothing);
  });

  testWidgets('no Upload button on the Shared tab', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Shared'));
    await tester.pump();
    api.sharedCalls.single.complete([]);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Upload'), findsNothing);
  });
}
