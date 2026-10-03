import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/network/api_exception.dart';
import 'package:r16a_cloud_app/features/files/data/files_api.dart';
import 'package:r16a_cloud_app/features/files/data/upload_source.dart';
import 'package:r16a_cloud_app/features/files/domain/file_sort.dart';

/// Records the outgoing request and replies with a fixed status and body,
/// standing in for the real `r16a-cloud` backend.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({
    this.json,
    this.bytes,
    this.statusCode = 200,
    this.extraHeaders = const {},
  });

  final Object? json;
  final List<int>? bytes;
  final int statusCode;
  final Map<String, List<String>> extraHeaders;
  RequestOptions? lastRequest;

  /// Raw request body bytes (streamed bodies such as uploads).
  List<int> lastBody = const [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    lastBody = requestStream == null
        ? const []
        : await requestStream.expand((chunk) => chunk).toList();
    if (bytes != null) {
      return ResponseBody.fromBytes(
        bytes!,
        statusCode,
        headers: {
          'content-type': ['image/jpeg'],
        },
      );
    }
    return ResponseBody.fromString(
      json == null ? '' : jsonEncode(json),
      statusCode,
      headers: {
        'content-type': ['application/json'],
        ...extraHeaders,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _fileJson({
  String id = 'f1',
  String name = 'notes.txt',
  bool isDirectory = false,
  String? parentId,
}) => {
  'id': id,
  'name': name,
  'description': null,
  'fsPath': '/x/$name',
  'isDirectory': isDirectory,
  'visibility': 'PRIVATE',
  'parentId': parentId,
  'ownerId': 'owner-1',
  'ownerDisplayName': 'Owner',
  'sharedWithIds': <String>[],
  'createdAt': '2026-09-24T14:32:00Z',
  'updatedAt': '2026-09-25T10:00:00Z',
  'takenAt': null,
  'blurHash': null,
};

(FilesApi, _StubAdapter) _apiWith(_StubAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = adapter;
  return (FilesApi(dio), adapter);
}

void main() {
  group('getFiles', () {
    test('root listing omits parentId and cursor', () async {
      final (api, adapter) = _apiWith(
        _StubAdapter(
          json: {
            'content': [_fileJson(name: 'Docs', isDirectory: true)],
            'nextCursor': 'c2',
            'hasMore': true,
          },
        ),
      );

      final page = await api.getFiles(ownerId: 'owner-1');

      expect(adapter.lastRequest?.path, '/fs');
      expect(adapter.lastRequest?.queryParameters, {
        'ownerId': 'owner-1',
        'sort': 'name',
        'dir': 'asc',
        'limit': 50,
      });
      expect(page.content.single.isDirectory, isTrue);
      expect(page.nextCursor, 'c2');
      expect(page.hasMore, isTrue);
    });

    test('folder page sends parentId, cursor and sort', () async {
      final (api, adapter) = _apiWith(
        _StubAdapter(
          json: {'content': <Object>[], 'nextCursor': null, 'hasMore': false},
        ),
      );

      final page = await api.getFiles(
        ownerId: 'owner-1',
        parentId: 'p1',
        sortField: FileSortField.updatedAt,
        sortDirection: FileSortDirection.desc,
        cursor: 'c2',
      );

      expect(adapter.lastRequest?.queryParameters, {
        'ownerId': 'owner-1',
        'sort': 'updatedAt',
        'dir': 'desc',
        'limit': 50,
        'parentId': 'p1',
        'cursor': 'c2',
      });
      expect(page.content, isEmpty);
      expect(page.nextCursor, isNull);
    });
  });

  test(
    'getFilesSharedWithMe sends folders-first sort and reads content',
    () async {
      final (api, adapter) = _apiWith(
        _StubAdapter(
          json: {
            'content': [_fileJson()],
            'totalElements': 1,
          },
        ),
      );

      final files = await api.getFilesSharedWithMe(
        sortField: FileSortField.updatedAt,
      );

      expect(adapter.lastRequest?.path, '/fs/shared-with-me');
      expect(
        adapter.lastRequest?.uri.query,
        'page=0&size=50&sort=isDirectory%2Cdesc&sort=updatedAt%2Casc',
      );
      expect(files.single.name, 'notes.txt');
    },
  );

  test('createFolder posts a directory request', () async {
    final (api, adapter) = _apiWith(
      _StubAdapter(
        json: _fileJson(name: 'New', isDirectory: true, parentId: 'p1'),
      ),
    );

    final folder = await api.createFolder(
      ownerId: 'owner-1',
      name: 'New',
      parentId: 'p1',
    );

    expect(adapter.lastRequest?.method, 'POST');
    expect(adapter.lastRequest?.path, '/fs');
    expect(adapter.lastRequest?.data, {
      'name': 'New',
      'ownerId': 'owner-1',
      'parentId': 'p1',
      'isDirectory': true,
    });
    expect(folder.parentId, 'p1');
  });

  test('rename puts only the name', () async {
    final (api, adapter) = _apiWith(
      _StubAdapter(json: _fileJson(name: 'b.txt')),
    );

    await api.rename('f1', 'b.txt');

    expect(adapter.lastRequest?.method, 'PUT');
    expect(adapter.lastRequest?.path, '/fs/f1');
    expect(adapter.lastRequest?.data, {'name': 'b.txt'});
  });

  test('updateSharing patches sharedWithIds', () async {
    final (api, adapter) = _apiWith(_StubAdapter(json: _fileJson()));

    await api.updateSharing('f1', ['u2']);

    expect(adapter.lastRequest?.method, 'PATCH');
    expect(adapter.lastRequest?.path, '/fs/f1/sharing');
    expect(adapter.lastRequest?.data, {
      'sharedWithIds': ['u2'],
    });
  });

  group('delete', () {
    test('treats 404 as success', () async {
      final (api, _) = _apiWith(_StubAdapter(statusCode: 404));

      await expectLater(api.delete('f1'), completes);
    });

    test('rethrows other failures as ApiException', () async {
      final (api, _) = _apiWith(_StubAdapter(statusCode: 500));

      await expectLater(
        api.delete('f1'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });

  test('getThumbnail returns raw bytes for the requested size', () async {
    final (api, adapter) = _apiWith(_StubAdapter(bytes: [1, 2, 3]));

    final bytes = await api.getThumbnail('f1', size: ThumbnailSize.large);

    expect(adapter.lastRequest?.path, '/fs/f1/thumbnail');
    expect(adapter.lastRequest?.queryParameters, {'size': 'large'});
    expect(bytes, [1, 2, 3]);
  });

  test('getDownloadToken reads the token', () async {
    final (api, adapter) = _apiWith(_StubAdapter(json: {'token': 'tkn'}));

    expect(await api.getDownloadToken('f1'), 'tkn');
    expect(adapter.lastRequest?.path, '/fs/f1/download-token');
  });

  test('getFileEvents parses the delta-sync page', () async {
    final (api, adapter) = _apiWith(
      _StubAdapter(
        json: {
          'events': [
            {
              'fileId': 'f1',
              'parentId': null,
              'fileName': 'a.txt',
              'eventType': 'CREATED',
              'occurredAt': 1759000000000,
            },
          ],
          'nextCursor': 1759000000001,
          'hasMore': false,
        },
      ),
    );

    final page = await api.getFileEvents(ownerId: 'owner-1', since: 1);

    expect(adapter.lastRequest?.queryParameters, {
      'ownerId': 'owner-1',
      'since': 1,
      'limit': 100,
    });
    expect(page.events.single.parentId, isNull);
    expect(page.nextCursor, 1759000000001);
  });

  group('uploads', () {
    final content = utf8.encode('hello world');
    final source = UploadSource(
      name: 'notes.txt',
      size: content.length,
      openRead: (start, end) => Stream.value(content.sublist(start, end)),
    );

    test('multipart sends ownerId, parentId and the file', () async {
      final (api, adapter) = _apiWith(_StubAdapter(json: _fileJson()));
      final progress = <int>[];

      await api.uploadMultipart(
        ownerId: 'owner-1',
        parentId: 'p1',
        source: source,
        onProgress: progress.add,
      );

      expect(adapter.lastRequest?.method, 'POST');
      expect(adapter.lastRequest?.path, '/fs/upload');
      final body = utf8.decode(adapter.lastBody);
      expect(body, contains('name="ownerId"\r\n\r\nowner-1'));
      expect(body, contains('name="parentId"\r\n\r\np1'));
      expect(body, contains('filename="notes.txt"'));
      expect(body, contains('hello world'));
      expect(progress.last, content.length);
    });

    test('multipart omits parentId at root', () async {
      final (api, adapter) = _apiWith(_StubAdapter(json: _fileJson()));

      await api.uploadMultipart(ownerId: 'owner-1', source: source);

      expect(utf8.decode(adapter.lastBody), isNot(contains('parentId')));
    });

    test('init sends the web body and reads the session', () async {
      final (api, adapter) = _apiWith(
        _StubAdapter(json: {'uploadId': 'up-1', 'partSizeBytes': 8388608}),
      );

      final session = await api.initChunkedUpload(
        ownerId: 'owner-1',
        fileName: 'big.mov',
        totalSize: 200,
      );

      expect(adapter.lastRequest?.path, '/fs/upload/init');
      expect(adapter.lastRequest?.data, {
        'ownerId': 'owner-1',
        'parentId': null,
        'fileName': 'big.mov',
        'totalSize': 200,
        'partSizeBytes': null,
        'description': null,
        'visibility': null,
        'sharedWithIds': null,
      });
      expect(session.uploadId, 'up-1');
      expect(session.partSizeBytes, 8388608);
    });

    test('part is a raw octet-stream body with its exact length', () async {
      final (api, adapter) = _apiWith(_StubAdapter(statusCode: 204));

      await api.uploadPart('up-1', source.openRead(6, 11), 5);

      expect(adapter.lastRequest?.method, 'PUT');
      expect(adapter.lastRequest?.path, '/fs/upload/up-1/part');
      expect(adapter.lastRequest?.contentType, 'application/octet-stream');
      expect(adapter.lastRequest?.headers[Headers.contentLengthHeader], 5);
      expect(utf8.decode(adapter.lastBody), 'world');
    });

    test('complete posts to the session', () async {
      final (api, adapter) = _apiWith(_StubAdapter(json: _fileJson()));

      await api.completeChunkedUpload('up-1');

      expect(adapter.lastRequest?.method, 'POST');
      expect(adapter.lastRequest?.path, '/fs/upload/up-1/complete');
    });
  });

  group('ETag revalidation', () {
    test('sends If-None-Match and reports 304 as not modified', () async {
      final (api, adapter) = _apiWith(
        _StubAdapter(
          statusCode: 304,
          extraHeaders: {
            'etag': ['"o:root:1"'],
          },
        ),
      );

      final result = await api.getFilesRevalidating(
        ownerId: 'owner-1',
        ifNoneMatch: '"o:root:1"',
      );

      expect(adapter.lastRequest?.headers['If-None-Match'], '"o:root:1"');
      expect(result.page, isNull);
      expect(result.etag, '"o:root:1"');
    });

    test('a 200 returns the page and its ETag, no header when unset', () async {
      final (api, adapter) = _apiWith(
        _StubAdapter(
          json: {'content': <Object>[], 'nextCursor': null, 'hasMore': false},
          extraHeaders: {
            'etag': ['"o:root:2"'],
          },
        ),
      );

      final result = await api.getFilesRevalidating(ownerId: 'owner-1');

      expect(
        adapter.lastRequest?.headers.containsKey('If-None-Match'),
        isFalse,
      );
      expect(result.page, isNotNull);
      expect(result.etag, '"o:root:2"');
    });
  });
}
