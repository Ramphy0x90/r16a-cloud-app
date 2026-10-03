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
}) {
  return {
    'id': 'user-1',
    'username': 'ramphy',
    'displayName': 'Ramphy Aquino Nova',
    'email': 'ramphy@example.com',
    'preferences': {
      'preferredTheme': theme,
      'defaultViewMode': viewMode,
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
      ),
    );

    expect(adapter.lastRequest?.method, 'PATCH');
    expect(adapter.lastRequest?.path, '/user/me/preferences');
    // Must match `UpdateMyPreferencesRequest` / `UserPreferencesPatchRequest`
    // on the backend exactly: { preferences: { preferredTheme, defaultViewMode } }.
    expect(adapter.lastBody, {
      'preferences': {
        'preferredTheme': 'dark',
        'defaultViewMode': 'list',
      },
    });
  });

  test('parses the preferences returned by GET /user/me and PATCH alike', () async {
    final adapter = _StubAdapter(_userJson(theme: 'light', viewMode: 'grid'));
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    final api = SessionApi(dio);

    final user = await api.getCurrentUser();

    expect(user.id, 'user-1');
    expect(user.displayName, 'Ramphy Aquino Nova');
    expect(user.preferences.theme, AppThemePreference.light);
    expect(user.preferences.defaultViewMode, DefaultFileView.grid);
  });

  test('listUsers requests the first 200 users and reads content', () async {
    final adapter = _StubAdapter({
      'content': [
        {'id': 'u2', 'username': 'jdoe', 'displayName': null, 'email': 'j@x.io'},
        {'id': 'u3', 'username': 'amy', 'displayName': 'Amy', 'email': 'a@x.io'},
      ],
      'totalElements': 2,
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;

    final users = await SessionApi(dio).listUsers();

    expect(adapter.lastRequest?.path, '/user');
    expect(adapter.lastRequest?.queryParameters, {'page': 0, 'size': 200});
    expect(users.map((u) => u.label), ['jdoe', 'Amy']);
  });

  test('deleteAccount sends DELETE /user/me', () async {
    final adapter = _StubAdapter(const {});
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;

    await SessionApi(dio).deleteAccount();

    expect(adapter.lastRequest?.method, 'DELETE');
    expect(adapter.lastRequest?.path, '/user/me');
  });
}
