import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/media/media_api.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({this.json, this.bytes});

  final Object? json;
  final List<int>? bytes;
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
        200,
        headers: {
          'content-type': ['image/jpeg'],
        },
      );
    }
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

(MediaApi, _StubAdapter) _apiWith(_StubAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://cloud.test/api'))
    ..httpClientAdapter = adapter;
  return (MediaApi(dio), adapter);
}

void main() {
  test('getThumbnail returns raw bytes for the requested size', () async {
    final (api, adapter) = _apiWith(_StubAdapter(bytes: [1, 2, 3]));

    final bytes = await api.getThumbnail('f1', size: ThumbnailSize.large);

    expect(adapter.lastRequest?.path, '/fs/f1/thumbnail');
    expect(adapter.lastRequest?.queryParameters, {'size': 'large'});
    expect(bytes, [1, 2, 3]);
  });

  test('downloadBytes fetches the raw file', () async {
    final (api, adapter) = _apiWith(_StubAdapter(bytes: [9]));

    expect(await api.downloadBytes('f1'), [9]);
    expect(adapter.lastRequest?.path, '/fs/f1/download');
  });

  test('getDownloadToken reads the token', () async {
    final (api, adapter) = _apiWith(_StubAdapter(json: {'token': 'tkn'}));

    expect(await api.getDownloadToken('f1'), 'tkn');
    expect(adapter.lastRequest?.path, '/fs/f1/download-token');
  });

  test('download URLs hang off the API base URL', () {
    final (api, _) = _apiWith(_StubAdapter());

    expect(
      api.tokenDownloadUri('a b').toString(),
      'https://cloud.test/api/fs/download/token?token=a+b',
    );
    expect(api.zipDownloadUri.toString(), 'https://cloud.test/api/fs/download');
  });
}
