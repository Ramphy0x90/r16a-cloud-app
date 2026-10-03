import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Receives every reported error. Assign [AppLogger.reporter] to send them
/// to a crash service later (Sentry, Crashlytics…); by default they go to
/// the debug console / DevTools log only.
typedef ErrorReporter =
    void Function(Object error, StackTrace? stack, {String? reason});

/// Single funnel for errors the app catches or doesn't — the native
/// counterpart of the web client's `console.error` calls, with one place to
/// plug a reporting service in.
abstract final class AppLogger {
  static ErrorReporter reporter = _logToConsole;

  /// Reports a handled failure worth knowing about (e.g. a failed download).
  static void error(Object error, [StackTrace? stack, String? reason]) =>
      reporter(error, stack, reason: reason);

  /// Routes uncaught framework and async errors to [reporter]. Call once,
  /// first thing in `main()`.
  static void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      error(details.exception, details.stack, details.context?.toString());
    };
    WidgetsBinding.instance.platformDispatcher.onError = (exception, stack) {
      error(exception, stack, 'Uncaught async error');
      return true;
    };
  }

  static void _logToConsole(Object error, StackTrace? stack, {String? reason}) {
    developer.log(
      reason ?? 'Error',
      name: 'domovoi',
      error: error,
      stackTrace: stack,
      level: 1000, // SEVERE
    );
    if (kDebugMode) debugPrint('[domovoi] ${reason ?? 'Error'}: $error');
  }
}
