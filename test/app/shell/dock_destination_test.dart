import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/app/shell/dock_destination.dart';
import 'package:r16a_cloud_app/core/navigation/home_tab.dart';

void main() {
  test('HomeTab follows the dock order', () {
    expect(
      HomeTab.values.map((t) => t.name),
      dockDestinations.map((d) => d.label.toLowerCase()),
    );
  });
}
