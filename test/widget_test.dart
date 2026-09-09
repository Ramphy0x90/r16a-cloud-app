import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/app/app.dart';

void main() {
  testWidgets('boots into the home shell with the dock', (tester) async {
    await tester.pumpWidget(const R16aCloudApp());

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Files'), findsWidgets);
    expect(find.text('Photos'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);

    await tester.tap(find.text('Photos').last);
    await tester.pumpAndSettle();

    expect(find.text('Your photos and videos, grouped by year.'), findsOneWidget);
  });
}
