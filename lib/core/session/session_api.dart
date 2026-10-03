import 'package:dio/dio.dart';

import '../network/api_exception.dart';
import 'current_user.dart';
import 'user_preferences.dart';
import 'user_summary.dart';

/// Mirrors the web client's `UserService` — the internal user behind the
/// OIDC identity (`GET /api/user/me`) and its preferences
/// (`PATCH /api/user/me/preferences`), plus the user list
/// (`GET /api/user`).
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

  /// Mirrors `UserService.getUsers()` — first page of 200, used by the
  /// share picker.
  Future<List<UserSummary>> listUsers({int page = 0, int size = 200}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/user',
        queryParameters: {'page': page, 'size': size},
      );
      return (response.data!['content'] as List<dynamic>)
          .map((e) => UserSummary.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// `DELETE /api/user/me` — erases the account and everything it owns on
  /// the server. The caller signs out afterwards.
  Future<void> deleteAccount() async {
    try {
      await _dio.delete<void>('/user/me');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<CurrentUser> updatePreferences(UserPreferences preferences) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/user/me/preferences',
        data: {
          'preferences': {
            'preferredTheme': preferences.theme.name,
            'defaultViewMode': preferences.defaultViewMode.name,
          },
        },
      );
      return CurrentUser.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
