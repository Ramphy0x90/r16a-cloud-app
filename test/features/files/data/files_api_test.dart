import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/network/api_exception.dart';
import 'package:r16a_cloud_app/features/files/data/files_api.dart';
import 'package:r16a_cloud_app/features/files/domain/file_sort.dart';

/// Records the outgoing request and replies with a fixed status and body,
/// standing in for the real `r16a-cloud` backend.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({this.json, this.bytes, this.statusCode = 200});

  final Object? json;
  final List<int>? bytes;
  final int statusCode;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
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
}
