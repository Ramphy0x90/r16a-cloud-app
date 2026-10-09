import 'dart:async';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_state.dart';
import 'oidc_service.dart';
import 'token_store.dart';

final oidcServiceProvider = Provider(
  (ref) => OidcService(const FlutterAppAuth()),
);

/// Owns the app's session: restoring it on launch, driving interactive
/// login/logout, and silently refreshing an expired access token.
///
/// Every other feature reads `authControllerProvider.select((s) => s.status)`
/// rather than talking to [OidcService]/[TokenStore] directly.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // build() must be synchronous; kick the async restore off as a
    // fire-and-forget continuation that assigns `state` when it resolves.
    unawaited(_restoreSession());
    return const AuthState();
  }

  OidcService get _oidc => ref.read(oidcServiceProvider);
  TokenStore get _tokenStore => ref.read(tokenStoreProvider);

  /// Refresh this long before expiry, so a token checked as valid can't
  /// expire on its way to the backend.
  static const refreshMargin = Duration(seconds: 30);

  /// The refresh in flight. Concurrent callers share it: parallel refreshes
  /// with one refresh token would race (and fail under token rotation).
  Future<String?>? _refreshing;

  Future<void> _restoreSession() async {
    try {
      final token = await getValidAccessToken();
      state = AuthState(
        status: token != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
      );
    } catch (_) {
      // Refresh couldn't reach Authentik (offline) — keep a stored session
      // so cached content still shows; requests refresh once back online.
      // No session, or storage unavailable/corrupt: fail safe to the login
      // screen rather than getting stuck on the splash screen forever.
      final hasSession = await _tokenStore.read().catchError((_) => null);
      state = AuthState(
        status: hasSession != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
      );
    }
  }

  /// Returns an access token valid for at least [refreshMargin], refreshing
  /// the stored one if needed. Returns `null` (and drops to
  /// [AuthStatus.unauthenticated]) if there's no session or Authentik
  /// rejected the refresh token. Throws if the refresh couldn't be done
  /// (offline); the session is kept.
  ///
  /// This is the single place that decides "is the session still good" —
  /// used both at launch (`_restoreSession`) and by the network layer's
  /// auth interceptor before every request.
  Future<String?> getValidAccessToken() async {
    final tokens = await _tokenStore.read();
    if (tokens == null) return null;
    if (DateTime.now().add(refreshMargin).isBefore(tokens.accessTokenExpiry)) {
      return tokens.accessToken;
    }
    return _refresh();
  }

  /// For a request the backend answered `401` although it carried
  /// [rejectedToken]: a token another request already replaced is reused,
  /// otherwise the session is refreshed. Same results as
  /// [getValidAccessToken].
  Future<String?> refreshAfterRejection(String rejectedToken) async {
    final tokens = await _tokenStore.read();
    if (tokens == null) return null;
    if (tokens.accessToken != rejectedToken) return tokens.accessToken;
    return _refresh();
  }

  Future<String?> _refresh() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<String?> _doRefresh() async {
    final tokens = await _tokenStore.read();
    if (tokens == null) return null;
    final refreshed = tokens.refreshToken == null
        ? null
        : await _oidc.refresh(tokens);
    if (refreshed == null) {
      await _endLocalSession();
      return null;
    }
    await _tokenStore.save(refreshed);
    return refreshed.accessToken;
  }

  /// The session is over (refresh token gone or rejected): back to the
  /// login screen. No IdP end-session — that opens the browser, and the
  /// Authentik session is either already gone or still valid for a quick
  /// re-login.
  Future<void> _endLocalSession() async {
    await _tokenStore.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> login() async {
    state = const AuthState(status: AuthStatus.unknown);
    try {
      final tokens = await _oidc.login();
      await _tokenStore.save(tokens);
      state = const AuthState(status: AuthStatus.authenticated);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: _messageFor(e),
      );
    }
  }

  /// User-initiated sign-out: also ends the Authentik session (through
  /// the browser), then clears the local one.
  Future<void> logout() async {
    final tokens = await _tokenStore.read();
    await _oidc.logout(idToken: tokens?.idToken);
    await _endLocalSession();
  }

  String _messageFor(Object error) {
    if (error is FlutterAppAuthUserCancelledException) {
      return 'Sign-in was cancelled.';
    }
    return 'Could not sign in. Please try again.';
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
