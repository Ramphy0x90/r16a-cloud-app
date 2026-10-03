import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/logging/app_logger.dart';

void main() {
  late ErrorReporter original;
  late List<(Object, String?)> reported;

  setUp(() {
    original = AppLogger.reporter;
    reported = [];
    AppLogger.reporter = (error, stack, {reason}) =>
        reported.add((error, reason));
  });

  tearDown(() => AppLogger.reporter = original);

  test('error goes to the configured reporter', () {
    AppLogger.error(StateError('boom'), StackTrace.current, 'Download failed');

    expect(reported.single.$1, isA<StateError>());
    expect(reported.single.$2, 'Download failed');
  });
}
