// Renders the Google Play store graphics from the logo SVG and app fonts.
// Run explicitly (it is not under test/, so `flutter test` skips it):
//
//   flutter test tool/branding/render_store_graphics_test.dart
//
// Outputs (upload in Play Console → Store presence → Main store listing):
//   assets/branding/store/play_icon_512.png      App icon, 512×512
//   assets/branding/store/feature_graphic.png    Feature graphic, 1024×500
//
// Re-run whenever the logo, colors or tagline change.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _logo = 'assets/imgs/domovoy-logo-dark.svg';

// AppColors.darkBackground / darkPrimary / darkForeground.
const _background = Color(0xFF0A0A0B);
const _primary = Color(0xFF10B981);
const _foreground = Color(0xFFFAFAFA);

/// Same wording as the store listing's short description.
const _tagline = 'Your files and photos, on your own cloud.';

Future<void> _loadFont(String family, String asset) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(asset));
  await loader.load();
}

Future<void> _render(
  WidgetTester tester, {
  required Size size,
  required String file,
  required Widget child,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: ColoredBox(color: _background, child: child),
      ),
    ),
  );
  // The SVG loads asynchronously from the asset bundle.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
  expect(find.byType(SvgPicture), findsOneWidget);

  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('assets/branding/store/$file')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await _loadFont('Sixtyfour', 'assets/fonts/Sixtyfour-Regular.ttf');
    await _loadFont('Rubik', 'assets/fonts/Rubik-Regular.ttf');
  });

  // Same composition as the launcher icon (assets/branding/icon.png).
  testWidgets('renders play_icon_512.png', (tester) async {
    await _render(
      tester,
      size: const Size.square(512),
      file: 'play_icon_512.png',
      child: Center(child: SvgPicture.asset(_logo, width: 320, height: 320)),
    );
  });

  // Play may crop the edges or overlay a play button in the middle, so the
  // content stays well inside the frame.
  testWidgets('renders feature_graphic.png', (tester) async {
    await _render(
      tester,
      size: const Size(1024, 500),
      file: 'feature_graphic.png',
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(_logo, width: 220, height: 220),
            const SizedBox(width: 32),
            const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Domovoi',
                  style: TextStyle(
                    fontFamily: 'Sixtyfour',
                    fontSize: 64,
                    color: _primary,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  _tagline,
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: 28,
                    color: _foreground,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  });
}
