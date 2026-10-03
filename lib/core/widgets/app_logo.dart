import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The Domovoi mark, in the variant drawn for the current theme (each uses
/// that theme's primary color).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 64});

  static const lightAsset = 'assets/imgs/domovoy-logo-light.svg';
  static const darkAsset = 'assets/imgs/domovoy-logo-dark.svg';

  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SvgPicture.asset(
      dark ? darkAsset : lightAsset,
      width: size,
      height: size,
      semanticsLabel: 'Domovoi',
    );
  }
}
