import 'dart:async';
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

/// Stubs the refresh exchange and IdP logout without AppAuth's platform
/// channel. [onRefresh] returns the new tokens, `null` (rejected) or throws.
class _FakeOidcService extends OidcService {
  _FakeOidcService({required this.onRefresh}) : super(const FlutterAppAuth());

  final Future<StoredTokens?> Function() onRefresh;
  var refreshCalls = 0;
  var logoutCalls = 0;

  @override
  Future<StoredTokens?> refresh(StoredTokens current) {
    refreshCalls++;
    return onRefresh();
  }

  @override
  Future<void> logout({String? idToken}) async => logoutCalls++;
}

/// Replies with [statuses] in turn (the last one repeats), recording the
/// Authorization header of every request.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.statuses);

  final List<int> statuses;
  final sentTokens = <Object?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sentTokens.add(options.headers['Authorization']);
    final status =
        statuses[(sentTokens.length - 1).clamp(0, statuses.length - 1)];
    return ResponseBody.fromString(
      '{}',
      status,
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
  String? refresh = 'refresh-1',
}) {
  return StoredTokens(
    accessToken: access,
    refreshToken: refresh,
    idToken: null,
    accessTokenExpiry: DateTime.now().add(delta),
  );
}

final _fresh = _tokenExpiringIn(const Duration(minutes: 5), access: 'fresh');

void main() {
  late _FakeTokenStore tokenStore;
  late _FakeOidcService oidc;
  late ProviderContainer container;
  late _RecordingAdapter adapter;

  Dio setUp({
    required StoredTokens? tokens,
    Future<StoredTokens?> Function()? onRefresh,
    List<int> statuses = const [200],
  }) {
    tokenStore = _FakeTokenStore(tokens);
    oidc = _FakeOidcService(onRefresh: onRefresh ?? () async => _fresh);
    container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokenStore),
        oidcServiceProvider.overrideWithValue(oidc),
      ],
    );
    addTearDown(container.dispose);
    adapter = _RecordingAdapter(statuses);
    return container.read(dioProvider)..httpClientAdapter = adapter;
  }

  /// Lets the controller's launch-time session restore settle.
  Future<void> restored() async {
    container.read(authControllerProvider);
    await pumpEventQueue();
  }

  test(
    'attaches the current access token as the Authorization header',
    () async {
      final dio = setUp(
        tokens: _tokenExpiringIn(const Duration(minutes: 5), access: 'abc123'),
      );

      await dio.get('/user/me');

      expect(adapter.sentTokens, ['Bearer abc123']);
      expect(oidc.refreshCalls, 0);
    },
  );

  test('refreshes an expired access token before attaching it', () async {
    final dio = setUp(
      tokens: _tokenExpiringIn(const Duration(minutes: -5), access: 'stale'),
    );

    await dio.get('/user/me');

    expect(adapter.sentTokens, ['Bearer fresh']);
    expect((await tokenStore.read())?.accessToken, 'fresh');
  });

  test('refreshes a token that expires within the safety margin', () async {
    final dio = setUp(
      tokens: _tokenExpiringIn(const Duration(seconds: 10), access: 'old'),
    );

    await dio.get('/user/me');

    expect(adapter.sentTokens, ['Bearer fresh']);
  });

  test('parallel requests share a single refresh', () async {
    final refresh = Completer<StoredTokens?>();
    final dio = setUp(
      tokens: _tokenExpiringIn(const Duration(minutes: -5), access: 'stale'),
      onRefresh: () => refresh.future,
    );

    final requests = [for (var i = 0; i < 4; i++) dio.get('/fs/$i')];
    await pumpEventQueue();
    refresh.complete(_fresh);
    await Future.wait(requests);

    expect(oidc.refreshCalls, 1);
    expect(adapter.sentTokens, List.filled(4, 'Bearer fresh'));
  });

  test('a 401 refreshes once and retries with the new token', () async {
    final dio = setUp(
      tokens: _tokenExpiringIn(const Duration(minutes: 5), access: 'revoked'),
      statuses: [401, 200],
    );
    await restored();

    final response = await dio.get('/user/me');

    expect(response.statusCode, 200);
    expect(adapter.sentTokens, ['Bearer revoked', 'Bearer fresh']);
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.authenticated,
    );
  });

  test('a second 401 after the retry is returned, not retried again', () async {
    final dio = setUp(
      tokens: _tokenExpiringIn(const Duration(minutes: 5)),
      statuses: [401],
    );

    await expectLater(dio.get('/user/me'), throwsA(isA<DioException>()));
    expect(adapter.sentTokens, hasLength(2));
  });

  test(
    'a rejected refresh token ends the session locally, without the browser',
    () async {
      final dio = setUp(
        tokens: _tokenExpiringIn(const Duration(minutes: 5)),
        onRefresh: () async => null,
        statuses: [401],
      );
      await restored();

      await expectLater(dio.get('/user/me'), throwsA(isA<DioException>()));

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
      expect(await tokenStore.read(), isNull);
      expect(oidc.logoutCalls, 0);
      expect(adapter.sentTokens, hasLength(1));
    },
  );

  test('a refresh that cannot reach Authentik keeps the session', () async {
    final stale = _tokenExpiringIn(const Duration(minutes: -5));
    final dio = setUp(
      tokens: stale,
      onRefresh: () async => throw Exception('offline'),
    );
    await restored();

    await expectLater(
      dio.get('/user/me'),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.connectionError,
        ),
      ),
    );

    expect(adapter.sentTokens, isEmpty);
    expect(await tokenStore.read(), same(stale));
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.authenticated,
    );
  });

  test('user logout ends the IdP session and clears tokens', () async {
    setUp(tokens: _tokenExpiringIn(const Duration(minutes: 5)));
    await restored();

    await container.read(authControllerProvider.notifier).logout();

    expect(oidc.logoutCalls, 1);
    expect(await tokenStore.read(), isNull);
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.unauthenticated,
    );
  });
}
