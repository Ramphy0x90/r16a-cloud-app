import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/features/dashboard/data/dashboard_api.dart';

/// Records the outgoing request and replies with a fixed body, standing in
/// for the real `r16a-cloud` backend.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.responseJson);

  final Map<String, dynamic> responseJson;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(responseJson),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('getDashboard requests the owner-scoped endpoint and parses the payload', () async {
    final adapter = _StubAdapter({
      'metrics': {
        'uploadedFiles': 128,
        'usedStorageBytes': 4300000000,
        'sharedFiles': 6,
        'uploadedPhotos': 342,
      },
      'recentFiles': [
        {
          'id': 'f1',
          'name': 'Q3-roadmap.pdf',
          'visibility': 'PRIVATE',
          'sizeBytes': 842000,
          'updatedAt': '2026-09-24T14:32:00Z',
        },
      ],
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    final api = DashboardApi(dio);

    final dashboard = await api.getDashboard('owner-1');

    expect(adapter.lastRequest?.method, 'GET');
    expect(adapter.lastRequest?.path, '/fs/dashboard');
    expect(adapter.lastRequest?.queryParameters, {'ownerId': 'owner-1'});

    expect(dashboard.metrics.uploadedFiles, 128);
    expect(dashboard.metrics.usedStorageBytes, 4300000000);
    expect(dashboard.recentFiles, hasLength(1));
    expect(dashboard.recentFiles.single.name, 'Q3-roadmap.pdf');
  });

  test('getFile requests /fs/{id} and parses a FileItem', () async {
    final adapter = _StubAdapter({
      'id': 'f1',
      'name': 'beach.jpg',
      'description': null,
      'fsPath': '/beach.jpg',
      'isDirectory': false,
      'visibility': 'PRIVATE',
      'parentId': 'folder-1',
      'ownerId': 'owner-1',
      'ownerDisplayName': 'Owner',
      'sharedWithIds': <String>[],
      'createdAt': '2026-09-24T14:32:00Z',
      'updatedAt': '2026-09-24T14:32:00Z',
      'takenAt': null,
      'blurHash': null,
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;

    final file = await DashboardApi(dio).getFile('f1');

    expect(adapter.lastRequest?.method, 'GET');
    expect(adapter.lastRequest?.path, '/fs/f1');
    expect(file.name, 'beach.jpg');
    expect(file.isImage, isTrue);
  });
}
