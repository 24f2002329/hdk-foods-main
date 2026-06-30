import 'package:flutter/material.dart';
import 'lottie_or.dart';

/// A premium, custom loading animation widget using the preloader Lottie animation.
/// Falls back gracefully to [CircularProgressIndicator] if the Lottie file is missing.
class HdkPreloader extends StatelessWidget {
  final double? width;
  final double? height;
  final Color? color;

  const HdkPreloader({
    super.key,
    this.width = 250,
    this.height = 250,
    this.color,
  });

  /// A helper constructor that returns a full-page loading screen
  /// styled to match the premium dark theme of the HDK Foods app.
  static Widget page({
    Key? key,
    Color backgroundColor = const Color(0xFF050505),
    double size = 180,
  }) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: HdkPreloader(
          key: key,
          width: size,
          height: size,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brandRed = color ?? const Color(0xFFFF1E1E);

    return LottieOr(
      asset: 'assets/animations/preloader.json',
      width: width,
      height: height,
      fallback: CircularProgressIndicator(
        color: brandRed,
        strokeWidth: 3,
      ),
    );
  }
}
