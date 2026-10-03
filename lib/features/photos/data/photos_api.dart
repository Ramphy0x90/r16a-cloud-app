import 'package:dio/dio.dart';

import '../../../core/model/file_item.dart';
import '../../../core/network/api_exception.dart';
import '../../files/domain/file_page.dart';
import '../domain/photo_year.dart';

/// Mirrors the web client's `PhotosService` (`services/photos.service.ts`)
/// — `/api/photos` — plus the shared-with-me lookup the web `PhotosPage`
/// makes through `FileService` to merge other users' media into the years.
class PhotosApi {
  PhotosApi(this._dio);

  final Dio _dio;

  /// Default page size of `GET /photos`, same as the web.
  static const pageSize = 60;

  /// How many shared items the web `PhotosPage` reads (one page).
  static const sharedLimit = 500;

  Future<List<PhotoYear>> getPhotoYears(String ownerId) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/photos/years',
        queryParameters: {'ownerId': ownerId},
      );
      return response.data!
          .map((e) => PhotoYear.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<FileCursorPage> getPhotos({
    required String ownerId,
    required int year,
    String? cursor,
    int limit = pageSize,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/photos',
        queryParameters: {
          'ownerId': ownerId,
          'year': year,
          'limit': limit,
          'cursor': ?cursor,
        },
      );
      return FileCursorPage.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Images and videos shared with the caller — the web's
  /// `getFilesSharedWithMe('name', 'asc', 0, 500)` filtered to media.
  Future<List<FileItem>> getSharedMedia() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/fs/shared-with-me',
        queryParameters: {
          'page': 0,
          'size': sharedLimit,
          'sort': ['isDirectory,desc', 'name,asc'],
        },
        options: Options(listFormat: ListFormat.multi),
      );
      return parseFileList(
        response.data!['content'],
      ).where((f) => f.isImage || f.isVideo).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
