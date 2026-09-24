import 'package:dio/dio.dart';

/// Normalized error surfaced by the network layer, independent of the
/// underlying HTTP client.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromDioException(DioException e) {
    final statusCode = e.response?.statusCode;

    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const ApiException(
        'The connection timed out. Please try again.',
      ),
      DioExceptionType.connectionError => const ApiException(
        'Could not reach the server. Check your connection.',
      ),
      DioExceptionType.badResponse => ApiException(
        'The server responded with an error (${statusCode ?? '?'}).',
        statusCode: statusCode,
      ),
      DioExceptionType.cancel => const ApiException('Request was cancelled.'),
      _ => ApiException(e.message ?? 'Unexpected network error.'),
    };
  }

  @override
  String toString() => message;
}
