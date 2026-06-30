import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Renders a Lottie asset animation, gracefully falling back to [fallback]
/// (the previous static icon / spinner) when the `.json` file is missing or
/// fails to load. This lets the UI ship before the animation files are added —
/// see `assets/animations/README.md` for the expected filenames.
class LottieOr extends StatelessWidget {
  final String asset;
  final Widget fallback;
  final double? width;
  final double? height;
  final bool repeat;
  final BoxFit fit;

  const LottieOr({
    super.key,
    required this.asset,
    required this.fallback,
    this.width,
    this.height,
    this.repeat = true,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      asset,
      width: width,
      height: height,
      repeat: repeat,
      fit: fit,
      // If the asset isn't bundled yet (or is invalid), show the fallback
      // instead of a red error box.
      errorBuilder: (context, error, stackTrace) => SizedBox(
        width: width,
        height: height,
        child: Center(child: fallback),
      ),
    );
  }
}
