import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/features/files/data/files_api.dart';
import 'package:r16a_cloud_app/features/files/data/thumbnail_cache.dart';
import 'package:r16a_cloud_app/features/files/presentation/file_images.dart';

import '../fakes.dart';

void main() {
  late FakeFilesApi api;

  setUp(() => api = FakeFilesApi());

  test('preview downloads the raw file for regular images', () {
    FilePreviewImage(fakeFile('a', extension: 'jpg'), api).loadBytes();

    expect(api.downloadCalls, ['a']);
    expect(api.thumbnailCalls, isEmpty);
  });

  test('preview uses the large server-converted thumbnail for HEIC', () {
    FilePreviewImage(
      fakeFile('a', extension: 'HEIC'),
      api,
    ).loadBytes().ignore();

    expect(api.downloadCalls, isEmpty);
    expect(api.thumbnailCalls, [('a', ThumbnailSize.large)]);
  });

  test('providers are keyed by file id only', () {
    final cache = ThumbnailCache(FilesApi(Dio()));

    expect(
      FilePreviewImage(fakeFile('a', extension: 'jpg'), api),
      FilePreviewImage(fakeFile('a', extension: 'jpg'), FakeFilesApi()),
    );
    expect(
      FileThumbnailImage('a', cache),
      FileThumbnailImage('a', ThumbnailCache(api)),
    );
    expect(
      FileThumbnailImage('a', cache),
      isNot(FileThumbnailImage('b', cache)),
    );
  });

  test('a missing thumbnail fails the load so the tile falls back', () async {
    final image = FileThumbnailImage('a', ThumbnailCache(api));

    await expectLater(image.loadBytes(), throwsStateError);
  });
}
