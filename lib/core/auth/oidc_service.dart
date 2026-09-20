import 'package:flutter_appauth/flutter_appauth.dart';

import '../config/env.dart';
import 'token_store.dart';

/// Thin wrapper around `flutter_appauth` (Authorization Code + PKCE against
/// Authentik). Purely does OIDC I/O and returns [StoredTokens] — it never
/// touches persistence itself; `AuthController` owns that via [TokenStore]
/// so each concern stays independently testable.
class OidcService {
  OidcService(this._appAuth);

  final FlutterAppAuth _appAuth;

  /// Runs the interactive login flow (system browser / ASWebAuthentication)
  /// and returns the resulting tokens.
  ///
  /// Throws if the user cancels or the exchange fails — callers decide how
  /// to surface that (see `AuthController`).
  Future<StoredTokens> login() async {
    final response = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        Env.oidcClientId,
        Env.oidcRedirectUri,
        issuer: Env.oidcIssuer,
        scopes: Env.oidcScopes,
      ),
    );

    return _toStoredTokens(response);
  }

  /// Exchanges a refresh token for a fresh access token.
  /// Returns `null` if the exchange fails (expired/revoked refresh token) —
  /// caller should fall back to login.
  Future<StoredTokens?> refresh(String refreshToken) async {
    try {
      final response = await _appAuth.token(
        TokenRequest(
          Env.oidcClientId,
          Env.oidcRedirectUri,
          issuer: Env.oidcIssuer,
          scopes: Env.oidcScopes,
          refreshToken: refreshToken,
        ),
      );

      return _toStoredTokens(response);
    } catch (_) {
      return null;
    }
  }

  /// Ends the Authentik session. Best-effort — callers should clear local
  /// tokens regardless of whether this succeeds (offline logout).
  Future<void> logout({String? idToken}) async {
    try {
      await _appAuth.endSession(
        EndSessionRequest(
          idTokenHint: idToken,
          issuer: Env.oidcIssuer,
          postLogoutRedirectUrl: Env.oidcRedirectUri,
        ),
      );
    } catch (_) {
      // Ignored — the session may already be gone, or the IdP unreachable.
    }
  }

  StoredTokens _toStoredTokens(TokenResponse response) {
    final accessToken = response.accessToken;
    final expiry = response.accessTokenExpirationDateTime;
    if (accessToken == null || expiry == null) {
      throw StateError('Token response missing accessToken/expiry.');
    }

    return StoredTokens(
      accessToken: accessToken,
      refreshToken: response.refreshToken,
      idToken: response.idToken,
      accessTokenExpiry: expiry,
    );
  }
}
