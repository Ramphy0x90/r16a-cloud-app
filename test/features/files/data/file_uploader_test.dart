import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/model/file_item.dart';
import 'package:r16a_cloud_app/core/network/api_exception.dart';
import 'package:r16a_cloud_app/features/files/data/file_uploader.dart';
import 'package:r16a_cloud_app/features/files/data/files_api.dart';
import 'package:r16a_cloud_app/features/files/data/upload_source.dart';

import '../fakes.dart';

/// Records the upload calls; parts can be told to fail.
class _UploadApi extends FilesApi {
  _UploadApi({this.partSize = 40, this.failPart}) : super(Dio());

  final int partSize;
  final int? failPart;
  final log = <String>[];

  @override
  Future<FileItem> uploadMultipart({
    required String ownerId,
    String? parentId,
    required UploadSource source,
    void Function(int sentBytes)? onProgress,
  }) async {
    log.add('multipart ${source.name}');
    onProgress?.call(source.size);
    return fakeFile('f');
  }

  @override
  Future<ChunkUploadSession> initChunkedUpload({
    required String ownerId,
    String? parentId,
    required String fileName,
    required int totalSize,
  }) async {
    log.add('init $fileName $totalSize');
    return (uploadId: 'up-1', partSizeBytes: partSize);
  }

  @override
  Future<void> uploadPart(
    String uploadId,
    Stream<List<int>> data,
    int length, {
    void Function(int sentBytes)? onProgress,
  }) async {
    final index = log.where((l) => l.startsWith('part')).length;
    log.add('part $length');
    if (index == failPart) throw const ApiException('boom', statusCode: 500);
    onProgress?.call(length);
  }

  @override
  Future<FileItem> completeChunkedUpload(String uploadId) async {
    log.add('complete $uploadId');
    return fakeFile('f');
  }

  @override
  Future<void> cancelChunkedUpload(String uploadId) async {
    log.add('cancel $uploadId');
  }
}

UploadSource _source(int size) => UploadSource(
  name: 'f.bin',
  size: size,
  openRead: (start, end) => const Stream.empty(),
);

void main() {
  const threshold = FileUploader.chunkThresholdBytes;

  test('partRanges covers the file exactly, last part short', () {
    expect(FileUploader.partRanges(100, 40), [(0, 40), (40, 80), (80, 100)]);
    expect(FileUploader.partRanges(80, 40), [(0, 40), (40, 80)]);
    expect(FileUploader.partRanges(0, 40), isEmpty);
  });

  test('up to 100 MB uses multipart', () async {
    final api = _UploadApi();

    await FileUploader(api).upload(ownerId: 'o', source: _source(threshold));

    expect(api.log, ['multipart f.bin']);
  });

  test('above 100 MB uses a chunked session in order', () async {
    final api = _UploadApi(partSize: 40 * 1024 * 1024);
    final progress = <int>[];

    await FileUploader(api).upload(
      ownerId: 'o',
      source: _source(threshold + 1),
      onProgress: progress.add,
    );

    expect(api.log, [
      'init f.bin ${threshold + 1}',
      'part ${40 * 1024 * 1024}',
      'part ${40 * 1024 * 1024}',
      'part ${20 * 1024 * 1024 + 1}',
      'complete up-1',
    ]);
    // Cumulative across parts.
    expect(progress.last, threshold + 1);
  });

  test('a failed part cancels the session and rethrows', () async {
    final api = _UploadApi(partSize: 60 * 1024 * 1024, failPart: 1);

    await expectLater(
      FileUploader(api).upload(ownerId: 'o', source: _source(threshold + 1)),
      throwsA(isA<ApiException>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(api.log.last, 'cancel up-1');
    expect(api.log, isNot(contains('complete up-1')));
  });
}
