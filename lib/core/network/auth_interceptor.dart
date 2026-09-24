import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

/// Attaches the current session's access token to every outgoing request,
/// refreshing it first if it's expired — mirrors the web client's
/// `authInterceptor()` (`angular-auth-oidc-client`, wired in `app.config.ts`).
///
/// A response that still comes back `401` means the session is no longer
/// valid server-side (revoked, clock skew, etc.); that's handled by dropping
/// to the login screen via [AuthController], same as the resource-server
/// contract in `SecurityConfig.java` expects.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._ref);

  final Ref _ref;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _ref
        .read(authControllerProvider.notifier)
        .getValidAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      await _ref.read(authControllerProvider.notifier).logout();
    }
    handler.next(err);
  }
}
