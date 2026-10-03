import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/media/media_api.dart';
import 'package:r16a_cloud_app/core/media/media_images.dart';
import 'package:r16a_cloud_app/core/media/thumbnail_cache.dart';

import '../../features/files/fakes.dart';

void main() {
  late FakeMediaApi api;

  setUp(() => api = FakeMediaApi());

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
    final cache = ThumbnailCache(MediaApi(Dio()));

    expect(
      FilePreviewImage(fakeFile('a', extension: 'jpg'), api),
      FilePreviewImage(fakeFile('a', extension: 'jpg'), FakeMediaApi()),
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
