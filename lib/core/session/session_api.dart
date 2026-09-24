import 'package:dio/dio.dart';

import '../network/api_exception.dart';
import 'current_user.dart';
import 'user_preferences.dart';

/// Mirrors the web client's `UserService` — the internal user behind the
/// OIDC identity (`GET /api/user/me`) and its preferences
/// (`PATCH /api/user/me/preferences`).
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

  Future<CurrentUser> updatePreferences(UserPreferences preferences) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/user/me/preferences',
        data: {
          'preferences': {
            'preferredTheme': preferences.theme.name,
            'defaultViewMode': preferences.defaultViewMode.name,
            'encryptFilesByDefault': preferences.encryptFilesByDefault,
          },
        },
      );
      return CurrentUser.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
