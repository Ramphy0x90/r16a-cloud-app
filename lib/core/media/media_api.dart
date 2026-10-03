import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../network/api_exception.dart';

/// Thumbnail sizes accepted by `GET /api/fs/{id}/thumbnail`.
enum ThumbnailSize { small, medium, large }

/// The `/api/fs` endpoints that deliver file content — thumbnails, raw
/// bytes, download links — shared by Files and Photos. Mirrors those
/// methods of the web client's `FileService`.
class MediaApi {
  MediaApi(this._dio);

  final Dio _dio;

  Future<Uint8List> getThumbnail(
    String id, {
    ThumbnailSize size = ThumbnailSize.small,
    Duration? receiveTimeout,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        '/fs/$id/thumbnail',
        queryParameters: {'size': size.name},
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: receiveTimeout,
        ),
      );
      return Uint8List.fromList(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Whole file content in memory — only for previews. Saving to disk goes
  /// through `FileDownloads`.
  Future<Uint8List> downloadBytes(String id, {Duration? receiveTimeout}) async {
    try {
      final response = await _dio.get<List<int>>(
        '/fs/$id/download',
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: receiveTimeout,
        ),
      );
      return Uint8List.fromList(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── Download URLs (fetched by the platform downloader, not Dio) ─────────

  /// `GET /fs/download/token?token=` — needs no bearer header.
  Uri tokenDownloadUri(String token) => Uri.parse(
    '${_dio.options.baseUrl}/fs/download/token',
  ).replace(queryParameters: {'token': token});

  /// `POST /fs/download` with `{ ids }` — bearer-authenticated zip stream.
  Uri get zipDownloadUri => Uri.parse('${_dio.options.baseUrl}/fs/download');

  /// Short-lived token for the unauthenticated `GET /fs/download/token`.
  Future<String> getDownloadToken(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/fs/$id/download-token',
      );
      return response.data!['token'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
