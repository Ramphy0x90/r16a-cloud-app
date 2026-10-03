import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/features/photos/data/photos_api.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.json);

  final Object json;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(json),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _file(String name) => {
  'id': name,
  'name': name,
  'description': null,
  'fsPath': '/$name',
  'isDirectory': false,
  'visibility': 'SHARED',
  'parentId': null,
  'ownerId': 'u2',
  'ownerDisplayName': 'Friend',
  'sharedWithIds': ['owner-1'],
  'createdAt': '2025-05-01T10:00:00Z',
  'updatedAt': '2025-05-01T10:00:00Z',
  'takenAt': null,
  'blurHash': null,
};

(PhotosApi, _StubAdapter) _apiWith(Object json) {
  final adapter = _StubAdapter(json);
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = adapter;
  return (PhotosApi(dio), adapter);
}

void main() {
  test('getPhotoYears parses the year counts', () async {
    final (api, adapter) = _apiWith([
      {'year': 2025, 'count': 12},
      {'year': 2023, 'count': 1},
    ]);

    final years = await api.getPhotoYears('owner-1');

    expect(adapter.lastRequest?.path, '/photos/years');
    expect(adapter.lastRequest?.queryParameters, {'ownerId': 'owner-1'});
    expect(years.map((y) => (y.year, y.count)), [(2025, 12), (2023, 1)]);
  });

  test('getPhotos pages a year with the web page size', () async {
    final (api, adapter) = _apiWith({
      'content': [_file('a.jpg')],
      'nextCursor': 'c2',
      'hasMore': true,
    });

    final page = await api.getPhotos(
      ownerId: 'owner-1',
      year: 2025,
      cursor: 'c1',
    );

    expect(adapter.lastRequest?.path, '/photos');
    expect(adapter.lastRequest?.queryParameters, {
      'ownerId': 'owner-1',
      'year': 2025,
      'limit': 60,
      'cursor': 'c1',
    });
    expect(page.nextCursor, 'c2');
  });

  test('getSharedMedia reads 500 shared items and keeps media only', () async {
    final (api, adapter) = _apiWith({
      'content': [_file('a.jpg'), _file('notes.pdf'), _file('clip.mov')],
    });

    final media = await api.getSharedMedia();

    expect(adapter.lastRequest?.path, '/fs/shared-with-me');
    expect(
      adapter.lastRequest?.uri.query,
      'page=0&size=500&sort=isDirectory%2Cdesc&sort=name%2Casc',
    );
    expect(media.map((f) => f.name), ['a.jpg', 'clip.mov']);
  });
}
