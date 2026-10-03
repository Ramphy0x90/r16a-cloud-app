import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

/// Build-time configuration, all overridable via `--dart-define`.
///
/// Defaults point at the local dev stack (`r16a-cloud` backend +
/// `r16a-cloud-local` Authentik provider) — the same pair the web client's
/// `environment.ts` (dev) talks to. Prod values live in `config/prod.json`
/// (mirrors `environment.prod.ts`):
///
/// ```
/// flutter build apk --release --dart-define-from-file=config/prod.json
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

  /// Public privacy policy (served by the web client at `/privacy`); the
  /// app stores require it, and the app links to it.
  static const privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://domovoi.cloud/privacy',
  );

  /// Fails fast when a release build would fall back to the local dev
  /// defaults (a forgotten `--dart-define-from-file`), instead of shipping
  /// an app that silently talks to `http://localhost`.
  static void checkReleaseConfig() {
    if (!kReleaseMode) return;
    const configured =
        bool.hasEnvironment('API_BASE_URL') &&
        bool.hasEnvironment('OIDC_ISSUER') &&
        bool.hasEnvironment('OIDC_CLIENT_ID');
    if (!configured || !apiBaseUrl.startsWith('https://')) {
      throw StateError(
        'Release build without prod config. Build with '
        '--dart-define-from-file=config/prod.json (API must be https).',
      );
    }
  }
}
