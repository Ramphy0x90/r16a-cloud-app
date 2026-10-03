import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';

enum NetworkStatus { online, offline }

/// Whether the backend can be reached, learned from real traffic (see
/// [NetworkStatusInterceptor]) rather than a connectivity plugin: "on Wi-Fi"
/// doesn't mean the server answers. While offline, a cheap probe runs every
/// [probeInterval] so the app notices recovery even when idle.
class NetworkStatusController extends Notifier<NetworkStatus> {
  static const probeInterval = Duration(seconds: 15);

  Timer? _probe;

  @override
  NetworkStatus build() {
    ref.onDispose(() => _probe?.cancel());
    return NetworkStatus.online;
  }

  void reportReachable() {
    _probe?.cancel();
    _probe = null;
    if (state != NetworkStatus.online) state = NetworkStatus.online;
  }

  void reportUnreachable() {
    if (state == NetworkStatus.offline) return;
    state = NetworkStatus.offline;
    _probe ??= Timer.periodic(probeInterval, (_) => checkNow());
  }

  /// One probe; also behind the banner's "Retry".
  Future<void> checkNow() async {
    if (await ref.read(reachabilityProbeProvider)()) {
      reportReachable();
    }
  }
}

final networkStatusProvider =
    NotifierProvider<NetworkStatusController, NetworkStatus>(
      NetworkStatusController.new,
    );

/// `true` when the backend answers at all. Uses a bare Dio — no auth
/// interceptor — so the expected `401` can't sign the user out.
final reachabilityProbeProvider = Provider<Future<bool> Function()>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      validateStatus: (_) => true,
    ),
  );
  ref.onDispose(dio.close);
  return () async {
    try {
      await dio.get<void>('');
      return true;
    } catch (_) {
      return false;
    }
  };
});

/// Feeds [NetworkStatusController] from every API call: any HTTP response
/// means reachable; failing to connect at all means offline.
class NetworkStatusInterceptor extends Interceptor {
  NetworkStatusInterceptor(this._ref);

  final Ref _ref;

  NetworkStatusController get _status =>
      _ref.read(networkStatusProvider.notifier);

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _status.reportReachable();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (err.type) {
      case DioExceptionType.connectionError ||
          DioExceptionType.connectionTimeout:
        _status.reportUnreachable();
      case _ when err.response != null:
        _status.reportReachable();
      case _:
        break;
    }
    handler.next(err);
  }
}
