import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/file_event.dart';
import '../domain/file_item.dart';
import '../domain/file_page.dart';
import '../domain/file_sort.dart';

/// Thumbnail sizes accepted by `GET /api/fs/{id}/thumbnail`.
enum ThumbnailSize { small, medium, large }

/// Mirrors the web client's `FileService` (`services/file.service.ts`) —
/// the `/api/fs` endpoints. Upload and download land with their own phase
/// steps.
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
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        '/fs/$id/thumbnail',
        queryParameters: {'size': size.name},
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

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
