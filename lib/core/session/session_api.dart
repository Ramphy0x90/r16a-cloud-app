import 'package:dio/dio.dart';

import '../network/api_exception.dart';
import 'current_user.dart';

/// Mirrors the web client's `UserService.currentUser$` — the internal
/// user behind the OIDC identity (`GET /api/user/me`).
class SessionApi {
  SessionApi(this._dio);

  final Dio _dio;

  Future<CurrentUser> getCurrentUser() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/user/me');
      return CurrentUser.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
