import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/dashboard_metrics.dart';

/// Mirrors the web client's `FileService.getDashboard` (`GET /api/fs/dashboard`).
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
}
