import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/features/files/data/file_downloads.dart';
import 'package:r16a_cloud_app/features/files/data/files_api.dart';

import '../fakes.dart';

/// Only the download token call is used by [FileDownloads.requestFor].
class _TokenApi extends FilesApi {
  _TokenApi() : super(Dio(BaseOptions(baseUrl: 'https://cloud.test/api')));

  @override
  Future<String> getDownloadToken(String id) async => 'tk/$id';
}

void main() {
  final downloads = FileDownloads(
    _TokenApi(),
    () async => 'bearer-1',
    now: () => DateTime.fromMillisecondsSinceEpoch(1759500000000),
  );

  test('one plain file uses the signed token link, no auth header', () async {
    final request = await downloads.requestFor([fakeFile('a')]);

    expect(
      request.url,
      'https://cloud.test/api/fs/download/token?token=tk%2Fa',
    );
    expect(request.filename, 'a.txt');
    expect(request.headers, isEmpty);
    expect(request.post, isNull);
  });

  test('a folder is zipped under its own name', () async {
    final request = await downloads.requestFor([
      fakeFile('docs', isDirectory: true),
    ]);

    expect(request.url, 'https://cloud.test/api/fs/download');
    expect(request.filename, 'docs.zip');
    expect(request.post, {
      'ids': ['docs'],
    });
    expect(request.headers, {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer bearer-1',
    });
  });

  test('several files are zipped under the web fallback name', () async {
    final request = await downloads.requestFor([fakeFile('a'), fakeFile('b')]);

    expect(request.filename, 'download_1759500000000.zip');
    expect(request.post, {
      'ids': ['a', 'b'],
    });
  });
}
