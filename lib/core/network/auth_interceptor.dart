import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

/// Attaches the current session's access token to every outgoing request,
/// refreshing it first if it's about to expire — mirrors the web client's
/// `authInterceptor()` (`angular-auth-oidc-client` with `silentRenew` +
/// `useRefreshToken`, wired in `app.config.ts`).
///
/// A `401` gets one refresh-and-retry. If Authentik rejects the refresh
/// token, [AuthController] drops to the login screen; the request fails.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._ref, this._dio);

  final Ref _ref;

  /// The client this interceptor is attached to, for the retry.
  final Dio _dio;

  static const _retriedKey = 'authRetried';

  AuthController get _auth => _ref.read(authControllerProvider.notifier);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final String? token;
    try {
      token = await _auth.getValidAccessToken();
    } catch (e) {
      // The refresh couldn't reach Authentik — almost always no network.
      // Reported as a connection error so the offline banner (and cached
      // listings) kick in; the session is kept.
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: e,
        ),
        true,
      );
      return;
    }
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
    final options = err.requestOptions;
    final sent = options.headers['Authorization'];
    if (err.response?.statusCode != 401 ||
        options.extra[_retriedKey] == true ||
        sent is! String ||
        !_canResend(options.data)) {
      handler.next(err);
      return;
    }

    try {
      final token = await _auth.refreshAfterRejection(
        sent.substring('Bearer '.length),
      );
      if (token == null) {
        handler.next(err); // Session over; already on the login screen.
        return;
      }
      options.extra[_retriedKey] = true;
      // onRequest attaches the new token again on the way out.
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    } catch (_) {
      handler.next(err);
    }
  }

  /// Streamed bodies (chunked upload parts) and multipart forms are
  /// consumed by the first attempt and can't be sent again.
  static bool _canResend(Object? data) => data is! Stream && data is! FormData;
}
