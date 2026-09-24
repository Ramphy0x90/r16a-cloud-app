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

  Future<void> _restoreSession() async {
    try {
      final token = await getValidAccessToken();
      state = AuthState(
        status: token != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
      );
    } catch (_) {
      // Secure storage unavailable/corrupt, refresh failed unexpectedly,
      // etc. — fail safe to the login screen rather than getting stuck on
      // the splash screen forever.
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Returns a non-expired access token, refreshing the stored one if
  /// needed. Returns `null` (and drops to [AuthStatus.unauthenticated]) if
  /// there's no session or the refresh token is gone/rejected.
  ///
  /// This is the single place that decides "is the session still good" —
  /// used both at launch (`_restoreSession`) and by the network layer's
  /// auth interceptor before every request.
  Future<String?> getValidAccessToken() async {
    final tokens = await _tokenStore.read();
    if (tokens == null) return null;

    if (!tokens.isExpired) return tokens.accessToken;

    final refreshToken = tokens.refreshToken;
    if (refreshToken == null) {
      await _tokenStore.clear();
      state = const AuthState(status: AuthStatus.unauthenticated);
      return null;
    }

    final refreshed = await _oidc.refresh(refreshToken);
    if (refreshed == null) {
      await _tokenStore.clear();
      state = const AuthState(status: AuthStatus.unauthenticated);
      return null;
    }

    await _tokenStore.save(refreshed);
    return refreshed.accessToken;
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

  Future<void> logout() async {
    final tokens = await _tokenStore.read();
    await _oidc.logout(idToken: tokens?.idToken);
    await _tokenStore.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
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
