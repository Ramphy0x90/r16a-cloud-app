// Renders the launcher-icon and splash source PNGs from the logo SVGs.
// Run explicitly (it is not under test/, so `flutter test` skips it):
//
//   flutter test tool/branding/render_branding_test.dart
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
//   cp assets/branding/web/*.png ../r16a-cloud_client/public/icons/
//
// Re-run all of these whenever the logo changes.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _light = 'assets/imgs/domovoy-logo-light.svg';
const _dark = 'assets/imgs/domovoy-logo-dark.svg';
const _darkBackground = Color(0xFF0A0A0B); // AppColors.darkBackground

/// One output: [canvas]px square, the logo drawn [logo]px wide, centered.
class _Spec {
  const _Spec(
    this.file,
    this.asset, {
    required this.canvas,
    required this.logo,
    this.background,
    this.tint,
  });

  final String file;
  final String asset;
  final double canvas;
  final double logo;
  final Color? background;

  /// Recolors the mark (monochrome themed icon).
  final Color? tint;
}

// The mark covers ~77% of its SVG box. Sizes keep it inside each
// platform's safe area: ~48% of the full icon, inside the adaptive icon's
// 66% safe zone, and inside Android 12's 2/3 splash circle.
final _specs = [
  _Spec('icon.png', _dark, canvas: 1024, logo: 640, background: _darkBackground),
  _Spec('icon_foreground.png', _dark, canvas: 1024, logo: 560),
  _Spec('icon_monochrome.png', _dark, canvas: 1024, logo: 560, tint: Colors.white),
  _Spec('splash_light.png', _light, canvas: 768, logo: 768),
  _Spec('splash_dark.png', _dark, canvas: 768, logo: 768),
  _Spec('splash_android12_light.png', _light, canvas: 1152, logo: 768),
  _Spec('splash_android12_dark.png', _dark, canvas: 1152, logo: 768),
  // Web client PWA icons (copy to r16a-cloud_client/public/icons/). Same
  // composition as icon.png, which also keeps the mark inside the 80%
  // "maskable" safe zone.
  // Browser-tab favicons (PNG fallback for the SVG ones): transparent, and
  // the mark drawn larger since tab icons are tiny. Emerald reads on both
  // light and dark tab bars.
  for (final size in [32, 96])
    _Spec(
      'web/favicon-${size}x$size.png',
      _dark,
      canvas: size.toDouble(),
      logo: size * 1.2,
    ),
  for (final size in [72, 96, 128, 144, 152, 192, 384, 512])
    _Spec(
      'web/icon-${size}x$size.png',
      _dark,
      canvas: size.toDouble(),
      logo: size * 0.625,
      background: _darkBackground,
    ),
];

void main() {
  for (final spec in _specs) {
    testWidgets('renders ${spec.file}', (tester) async {
      tester.view
        ..physicalSize = Size.square(spec.canvas)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      final tint = spec.tint;
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: spec.background ?? Colors.transparent,
            child: Center(
              child: SvgPicture.asset(
                spec.asset,
                width: spec.logo,
                height: spec.logo,
                colorFilter: tint == null
                    ? null
                    : ColorFilter.mode(tint, BlendMode.srcIn),
              ),
            ),
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
        File('assets/branding/${spec.file}')
          ..createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
    });
  }
}
