import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/auth/auth_controller.dart';
import 'package:r16a_cloud_app/core/auth/auth_state.dart';
import 'package:r16a_cloud_app/core/auth/oidc_service.dart';
import 'package:r16a_cloud_app/core/auth/token_store.dart';
import 'package:r16a_cloud_app/core/network/dio_client.dart';

/// In-memory [TokenStore] — no real secure-storage platform channel.
class _FakeTokenStore implements TokenStore {
  _FakeTokenStore([this._tokens]);

  StoredTokens? _tokens;

  @override
  Future<StoredTokens?> read() async => _tokens;

  @override
  Future<void> save(StoredTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}

/// Stubs the refresh exchange without touching AppAuth's platform channel.
class _FakeOidcService extends OidcService {
  _FakeOidcService({this.refreshResult}) : super(const FlutterAppAuth());

  final StoredTokens? refreshResult;

  @override
  Future<StoredTokens?> refresh(String refreshToken) async => refreshResult;
}

/// Records the request it received and replies with a canned response,
/// standing in for the real network.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.statusCode);

  final int statusCode;
  Map<String, dynamic>? lastHeaders;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastHeaders = options.headers;
    return ResponseBody.fromString(
      '{}',
      statusCode,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

StoredTokens _tokenExpiringIn(
  Duration delta, {
  String access = 'access',
  String? refresh,
}) {
  return StoredTokens(
    accessToken: access,
    refreshToken: refresh,
    idToken: null,
    accessTokenExpiry: DateTime.now().add(delta),
  );
}

void main() {
  test(
    'attaches the current access token as the Authorization header',
    () async {
      final container = ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(
            _FakeTokenStore(
              _tokenExpiringIn(const Duration(minutes: 5), access: 'abc123'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final dio = container.read(dioProvider);
      final adapter = _RecordingAdapter(200);
      dio.httpClientAdapter = adapter;

      await dio.get('/user/me');

      expect(adapter.lastHeaders?['Authorization'], 'Bearer abc123');
    },
  );

  test('refreshes an expired access token before attaching it', () async {
    final tokenStore = _FakeTokenStore(
      _tokenExpiringIn(
        const Duration(minutes: -5),
        access: 'stale',
        refresh: 'refresh-1',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokenStore),
        oidcServiceProvider.overrideWithValue(
          _FakeOidcService(
            refreshResult: _tokenExpiringIn(
              const Duration(minutes: 5),
              access: 'fresh',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final dio = container.read(dioProvider);
    final adapter = _RecordingAdapter(200);
    dio.httpClientAdapter = adapter;

    await dio.get('/user/me');

    expect(adapter.lastHeaders?['Authorization'], 'Bearer fresh');
    expect((await tokenStore.read())?.accessToken, 'fresh');
  });

  test(
    'drops the session when the server rejects the request with 401',
    () async {
      final container = ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(
            _FakeTokenStore(_tokenExpiringIn(const Duration(minutes: 5))),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Prime the session so it starts authenticated, same as the interceptor
      // would find it mid-app-lifetime.
      await container
          .read(authControllerProvider.notifier)
          .getValidAccessToken();

      final dio = container.read(dioProvider);
      dio.httpClientAdapter = _RecordingAdapter(401);

      await expectLater(dio.get('/user/me'), throwsA(isA<DioException>()));
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
    },
  );
}
