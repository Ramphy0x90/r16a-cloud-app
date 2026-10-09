import 'package:dio/dio.dart';

import '../../../core/model/file_item.dart';
import '../../../core/network/api_exception.dart';
import '../domain/dashboard_metrics.dart';

/// Mirrors the web client's `FileService.getDashboard` (`GET /api/fs/dashboard`),
/// plus `GET /api/fs/{id}` to open a recent file (web rows aren't tappable).
class DashboardApi {
  DashboardApi(this._dio);

  final Dio _dio;

  Future<DashboardResponse> getDashboard(String ownerId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/fs/dashboard',
        queryParameters: {'ownerId': ownerId},
      );
      return DashboardResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// `GET /fs/{id}` — the full [FileItem] behind a `RecentFileItem`.
  Future<FileItem> getFile(String id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/fs/$id');
      return FileItem.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
