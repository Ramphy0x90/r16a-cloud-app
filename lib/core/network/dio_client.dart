import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import 'auth_interceptor.dart';

/// The shared HTTP client for every call to the `r16a-cloud` backend —
/// equivalent to the web client's single `HttpClient` instance
/// (`provideHttpClient` in `app.config.ts`), base URL plus the auth
/// interceptor attached once, reused by every feature's API class.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  dio.interceptors.add(AuthInterceptor(ref));

  return dio;
});
