import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/network/api_exception.dart';
import 'package:r16a_cloud_app/core/session/session_providers.dart';
import 'package:r16a_cloud_app/features/files/data/file_uploader.dart';
import 'package:r16a_cloud_app/features/files/data/files_api.dart';
import 'package:r16a_cloud_app/features/files/data/upload_source.dart';
import 'package:r16a_cloud_app/features/files/domain/file_item.dart';
import 'package:r16a_cloud_app/features/files/presentation/files_providers.dart';
import 'package:r16a_cloud_app/features/files/presentation/upload_controller.dart';

import '../fakes.dart';

/// Each upload stays pending until the test answers it.
class _ManualUploader extends FileUploader {
  _ManualUploader() : super(FilesApi(Dio()));

  final pending = <String, Completer<FileItem>>{};
  final progress = <String, void Function(int)>{};
  final parents = <String?>[];

  @override
  Future<FileItem> upload({
    required String ownerId,
    String? parentId,
    required UploadSource source,
    void Function(int sentBytes)? onProgress,
  }) {
    parents.add(parentId);
    if (onProgress != null) progress[source.name] = onProgress;
    return (pending[source.name] = Completer<FileItem>()).future;
  }
}

UploadSource _source(String name, int size) => UploadSource(
  name: name,
  size: size,
  openRead: (start, end) => const Stream.empty(),
);

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeFilesApi api;
  late _ManualUploader uploader;
  late ProviderContainer container;

  UploadState state() => container.read(uploadControllerProvider);
  UploadController controller() =>
      container.read(uploadControllerProvider.notifier);

  setUp(() async {
    api = FakeFilesApi();
    uploader = _ManualUploader();
    container = ProviderContainer(
      overrides: [
        filesApiProvider.overrideWithValue(api),
        fileUploaderProvider.overrideWithValue(uploader),
        sessionApiProvider.overrideWithValue(FakeSessionApi()),
      ],
    );
    // Files screen alive with the root folder open.
    container.listen(filesControllerProvider, (_, _) {});
    await _settle();
    api.calls.single.response.complete(fakePage([]));
    await _settle();
  });

  tearDown(() => container.dispose());

  test('runs two at a time and reports overall progress', () async {
    final done = controller().upload([
      _source('a', 100),
      _source('b', 100),
      _source('c', 200),
    ]);
    await _settle();

    expect(uploader.pending.keys, ['a', 'b']);
    expect(state().uploading, isTrue);
    expect(state().progress!.fileCount, 3);

    uploader.progress['a']!(50);
    expect(state().progress!.overallLoaded, 50);
    expect(state().progress!.fraction, 50 / 400);

    uploader.pending['a']!.complete(fakeFile('a'));
    await _settle();
    expect(uploader.pending.keys, ['a', 'b', 'c']);
    expect(state().progress!.currentIndex, 3);
    expect(state().progress!.currentName, 'c');

    uploader.pending['b']!.complete(fakeFile('b'));
    uploader.pending['c']!.complete(fakeFile('c'));
    await done;

    expect(state().uploading, isFalse);
    expect(state().errors, isEmpty);
  });

  test('collects per-file errors without stopping the batch', () async {
    final done = controller().upload([_source('a', 1), _source('b', 1)]);
    await _settle();

    uploader.pending['a']!.completeError(
      const ApiException('dup', statusCode: 409),
    );
    uploader.pending['b']!.completeError(Exception('io'));
    await done;

    expect(state().errors, [
      'a: A file with that name already exists.',
      'b: Upload failed',
    ]);

    controller().dismissErrors();
    expect(state().errors, isEmpty);
  });

  test('uploads into the given folder and refreshes the open one', () async {
    final callsBefore = api.calls.length;
    final done = controller().upload([_source('a', 1)]);
    await _settle();
    expect(uploader.parents, [null]);

    uploader.pending['a']!.complete(fakeFile('a'));
    await done;
    await _settle();
    // Root is open: its cache was dropped and it reloads.
    expect(api.calls.length, callsBefore + 1);
    api.calls.last.response.complete(fakePage([fakeFile('a')]));
    await _settle();

    expect(container.read(filesControllerProvider).items.single.id, 'a');
  });

  test('ignores a second batch while one is running', () async {
    controller().upload([_source('a', 1)]);
    controller().upload([_source('b', 1)]);
    await _settle();

    expect(uploader.pending.keys, ['a']);
  });
}
