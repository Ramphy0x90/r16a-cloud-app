import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Build-time configuration, all overridable via `--dart-define`.
///
/// Defaults point at the local dev stack (`r16a-cloud` backend +
/// `r16a-cloud-local` Authentik provider) — the same pair the web client's
/// `environment.ts` (dev) talks to. Override for a prod build, e.g.:
///
/// ```
/// flutter run --dart-define=OIDC_ISSUER=https://auth.r16a.cloud/application/o/<prod-slug>/ \
///   --dart-define=OIDC_CLIENT_ID=<prod-client-id> \
///   --dart-define=API_BASE_URL=https://cloud.r16a.cloud/api
/// ```
class Env {
  const Env._();

  /// The `r16a-cloud` backend's API root — mirrors `environment.apiUrl` on
  /// the web client. The Android emulator can't reach the host's
  /// `localhost` (it's a separate virtual device), so it's routed through
  /// the emulator's `10.0.2.2` host alias instead; every other target
  /// (iOS simulator, a real device once `API_BASE_URL` is set explicitly)
  /// uses `localhost`.
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    final host = (!kIsWeb && Platform.isAndroid) ? '10.0.2.2' : 'localhost';
    return 'http://$host:8080/api';
  }

  /// Authentik issuer for this app's OIDC provider (trailing slash matters —
  /// Authentik's discovery document lives at `<issuer>/.well-known/...`).
  static const oidcIssuer = String.fromEnvironment(
    'OIDC_ISSUER',
    defaultValue: 'https://auth.r16a.cloud/application/o/r16a-cloud-local/',
  );

  /// Public client id. Mobile reuses the same `r16a-cloud-local` provider as
  /// the web app — see docs/MOBILE_APP_PLAN.md §2 for why a new provider
  /// isn't needed (the backend pins `issuer-uri`, so mobile just adds a
  /// redirect URI to the existing provider instead of registering a new one).
  static const oidcClientId = String.fromEnvironment(
    'OIDC_CLIENT_ID',
    defaultValue: '2Jati6hlDzX22iHuRMdDdliwLYmU8sLrUWjVbIO4',
  );

  /// Must be registered as a redirect URI on the Authentik provider above,
  /// and match the native scheme registered in the Android/iOS platform
  /// config (`appAuthRedirectScheme` / `CFBundleURLSchemes`).
  static const oidcRedirectUri = 'cloud.r16a.r16acloudapp:/oauth2redirect';

  static const oidcScopes = ['openid', 'profile', 'email', 'offline_access'];
}
