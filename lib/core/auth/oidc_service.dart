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

  /// Exchanges [current]'s refresh token for a fresh access token.
  ///
  /// Returns `null` only when Authentik rejects the refresh token (expired,
  /// revoked: an OAuth error such as `invalid_grant`); the session is over
  /// then. Anything else (offline, timeout, IdP down) is rethrown so the
  /// caller keeps the session and tries again later.
  Future<StoredTokens?> refresh(StoredTokens current) async {
    try {
      final response = await _appAuth.token(
        TokenRequest(
          Env.oidcClientId,
          Env.oidcRedirectUri,
          issuer: Env.oidcIssuer,
          scopes: Env.oidcScopes,
          refreshToken: current.refreshToken,
        ),
      );

      // Without refresh-token rotation the response carries no new refresh
      // (or id) token; keep the ones we have.
      return _toStoredTokens(response, previous: current);
    } on FlutterAppAuthPlatformException catch (e) {
      if (_rejectedGrantErrors.contains(e.platformErrorDetails.error)) {
        return null;
      }
      rethrow;
    }
  }

  /// Token-endpoint errors (RFC 6749 §5.2) meaning the refresh token will
  /// never work again.
  static const _rejectedGrantErrors = {
    'invalid_grant',
    'invalid_client',
    'unauthorized_client',
  };

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

  StoredTokens _toStoredTokens(
    TokenResponse response, {
    StoredTokens? previous,
  }) {
    final accessToken = response.accessToken;
    final expiry = response.accessTokenExpirationDateTime;
    if (accessToken == null || expiry == null) {
      throw StateError('Token response missing accessToken/expiry.');
    }

    return StoredTokens(
      accessToken: accessToken,
      refreshToken: response.refreshToken ?? previous?.refreshToken,
      idToken: response.idToken ?? previous?.idToken,
      accessTokenExpiry: expiry,
    );
  }
}
