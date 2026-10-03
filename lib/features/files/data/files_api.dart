import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/file_event.dart';
import '../domain/file_item.dart';
import '../domain/file_page.dart';
import '../domain/file_sort.dart';
import 'upload_source.dart';

/// Thumbnail sizes accepted by `GET /api/fs/{id}/thumbnail`.
enum ThumbnailSize { small, medium, large }

/// Mirrors `ChunkUploadInitResponse` — the server picks the part size.
typedef ChunkUploadSession = ({String uploadId, int partSizeBytes});

/// Mirrors the web client's `FileService` (`services/file.service.ts`) —
/// the `/api/fs` endpoints. Disk downloads run through `FileDownloads`,
/// which uses the URLs built here.
class FilesApi {
  FilesApi(this._dio);

  final Dio _dio;

  /// Default page size, same as the web `FilesPage.pageSize`.
  static const pageSize = 50;

  Future<FileCursorPage> getFiles({
    required String ownerId,
    String? parentId,
    FileSortField sortField = FileSortField.name,
    FileSortDirection sortDirection = FileSortDirection.asc,
    String? cursor,
    int limit = pageSize,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/fs',
        queryParameters: {
          'ownerId': ownerId,
          'sort': sortField.name,
          'dir': sortDirection.name,
          'limit': limit,
          'parentId': ?parentId,
          'cursor': ?cursor,
        },
      );
      return FileCursorPage.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// `GET /api/fs/shared-with-me` — a Spring `Page`, folders first, then
  /// the chosen sort (same `sort` params as the web client).
  Future<List<FileItem>> getFilesSharedWithMe({
    FileSortField sortField = FileSortField.name,
    FileSortDirection sortDirection = FileSortDirection.asc,
    int page = 0,
    int size = pageSize,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/fs/shared-with-me',
        queryParameters: {
          'page': page,
          'size': size,
          'sort': [
            'isDirectory,desc',
            '${sortField.name},${sortDirection.name}',
          ],
        },
        options: Options(listFormat: ListFormat.multi),
      );
      return parseFileList(response.data!['content']);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<FileItem> createFolder({
    required String ownerId,
    required String name,
    String? parentId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/fs',
        data: {
          'name': name,
          'ownerId': ownerId,
          'parentId': parentId,
          'isDirectory': true,
        },
      );
      return FileItem.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<FileItem> rename(String id, String name) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/fs/$id',
        data: {'name': name},
      );
      return FileItem.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<FileItem> updateSharing(String id, List<String> sharedWithIds) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/fs/$id/sharing',
        data: {'sharedWithIds': sharedWithIds},
      );
      return FileItem.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// A 404 means it is already gone — treated as success, like the web
  /// client's `confirmDelete`.
  Future<void> delete(String id) async {
    try {
      await _dio.delete<void>('/fs/$id');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return;
      throw ApiException.fromDioException(e);
    }
  }

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

  /// Whole file content in memory — only for previews. Real downloads to
  /// disk land with the transfer step.
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

  // ── Uploads ─────────────────────────────────────────────────────────────
  // The server finishes uploads with blurhash / metadata work, so responses
  // can take a while: generous receive timeouts on the finishing calls.

  static const _finishTimeout = Duration(minutes: 5);

  /// `POST /fs/upload` (multipart). [onProgress] gets file bytes sent,
  /// scaled from Dio's multipart totals.
  Future<FileItem> uploadMultipart({
    required String ownerId,
    String? parentId,
    required UploadSource source,
    void Function(int sentBytes)? onProgress,
  }) async {
    try {
      final form = FormData.fromMap({
        'ownerId': ownerId,
        'parentId': ?parentId,
        'file': MultipartFile.fromStream(
          () => source.openRead(0, source.size),
          source.size,
          filename: source.name,
        ),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/fs/upload',
        data: form,
        options: Options(receiveTimeout: _finishTimeout),
        onSendProgress: onProgress == null
            ? null
            : (sent, total) =>
                  onProgress(total <= 0 ? 0 : (sent * source.size) ~/ total),
      );
      return FileItem.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// `POST /fs/upload/init` — same body as the web's `uploadFileChunked`.
  Future<ChunkUploadSession> initChunkedUpload({
    required String ownerId,
    String? parentId,
    required String fileName,
    required int totalSize,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/fs/upload/init',
        data: {
          'ownerId': ownerId,
          'parentId': parentId,
          'fileName': fileName,
          'totalSize': totalSize,
          'partSizeBytes': null,
          'description': null,
          'visibility': null,
          'sharedWithIds': null,
        },
      );
      return (
        uploadId: response.data!['uploadId'] as String,
        partSizeBytes: (response.data!['partSizeBytes'] as num).toInt(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// `PUT /fs/upload/{id}/part` — raw octet-stream body of exactly
  /// [length] bytes; parts must be sent in order.
  Future<void> uploadPart(
    String uploadId,
    Stream<List<int>> data,
    int length, {
    void Function(int sentBytes)? onProgress,
  }) async {
    try {
      await _dio.put<void>(
        '/fs/upload/$uploadId/part',
        data: data,
        options: Options(
          contentType: 'application/octet-stream',
          headers: {Headers.contentLengthHeader: length},
        ),
        onSendProgress: onProgress == null
            ? null
            : (sent, _) => onProgress(sent),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<FileItem> completeChunkedUpload(String uploadId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/fs/upload/$uploadId/complete',
        data: const <String, dynamic>{},
        options: Options(receiveTimeout: _finishTimeout),
      );
      return FileItem.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// `DELETE /fs/upload/{id}` — drops a failed session's partial data.
  Future<void> cancelChunkedUpload(String uploadId) async {
    try {
      await _dio.delete<void>('/fs/upload/$uploadId');
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

  /// Delta-sync feed; [since] is epoch milliseconds.
  Future<FileEventsPage> getFileEvents({
    required String ownerId,
    required int since,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/fs/events',
        queryParameters: {'ownerId': ownerId, 'since': since, 'limit': limit},
      );
      return FileEventsPage.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
