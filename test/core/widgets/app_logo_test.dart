import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/widgets/app_logo.dart';

void main() {
  Future<String> assetFor(WidgetTester tester, Brightness brightness) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const AppLogo(),
      ),
    );
    // MaterialApp animates theme changes.
    await tester.pumpAndSettle();
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    return (svg.bytesLoader as SvgAssetLoader).assetName;
  }

  testWidgets('picks the variant for the theme', (tester) async {
    expect(await assetFor(tester, Brightness.light), AppLogo.lightAsset);
    expect(await assetFor(tester, Brightness.dark), AppLogo.darkAsset);
  });
}
