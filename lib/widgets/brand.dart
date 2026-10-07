import 'package:flutter/material.dart';

/// App logo (transparent PNG, cropped to the artwork). [size] is the width; height follows the
/// logo's aspect ratio. [white] uses the white variant for dark/blue backgrounds.
class BrandLogo extends StatelessWidget {
  final double size;
  final bool white;
  const BrandLogo({super.key, this.size = 72, this.white = false});

  @override
  Widget build(BuildContext context) => Image.asset(
        white ? 'assets/logo_white.png' : 'assets/logo.png',
        width: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
}
