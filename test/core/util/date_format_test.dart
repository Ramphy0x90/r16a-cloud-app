import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/util/date_format.dart';

void main() {
  test('formatDateTime uses a 4-digit year, like the web list view', () {
    expect(formatDateTime(DateTime(2026, 3, 7, 9, 5)), '07/03/2026 09:05');
  });
}
