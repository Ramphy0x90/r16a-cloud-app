import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/session/session_api.dart';
import 'package:r16a_cloud_app/core/session/user_preferences.dart';

/// Records the outgoing request and replies with a fixed body, standing in
/// for the real `r16a-cloud` backend.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.responseJson);

  final Map<String, dynamic> responseJson;
  RequestOptions? lastRequest;
  Object? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    lastBody = options.data;
    return ResponseBody.fromString(
      jsonEncode(responseJson),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _userJson({
  String theme = 'dark',
  String viewMode = 'list',
  bool encrypt = true,
}) {
  return {
    'id': 'user-1',
    'username': 'ramphy',
    'displayName': 'Ramphy Aquino Nova',
    'email': 'ramphy@example.com',
    'preferences': {
      'preferredTheme': theme,
      'defaultViewMode': viewMode,
      'encryptFilesByDefault': encrypt,
    },
  };
}

void main() {
  test('updatePreferences PATCHes the exact backend contract shape', () async {
    final adapter = _StubAdapter(_userJson());
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    final api = SessionApi(dio);

    await api.updatePreferences(
      const UserPreferences(
        theme: AppThemePreference.dark,
        defaultViewMode: DefaultFileView.list,
        encryptFilesByDefault: true,
      ),
    );

    expect(adapter.lastRequest?.method, 'PATCH');
    expect(adapter.lastRequest?.path, '/user/me/preferences');
    // Must match `UpdateMyPreferencesRequest` / `UserPreferencesPatchRequest`
    // on the backend exactly: { preferences: { preferredTheme, defaultViewMode, encryptFilesByDefault } }.
    expect(adapter.lastBody, {
      'preferences': {
        'preferredTheme': 'dark',
        'defaultViewMode': 'list',
        'encryptFilesByDefault': true,
      },
    });
  });

  test('parses the preferences returned by GET /user/me and PATCH alike', () async {
    final adapter = _StubAdapter(_userJson(theme: 'light', viewMode: 'grid', encrypt: false));
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    final api = SessionApi(dio);

    final user = await api.getCurrentUser();

    expect(user.id, 'user-1');
    expect(user.displayName, 'Ramphy Aquino Nova');
    expect(user.preferences.theme, AppThemePreference.light);
    expect(user.preferences.defaultViewMode, DefaultFileView.grid);
    expect(user.preferences.encryptFilesByDefault, false);
  });
}
