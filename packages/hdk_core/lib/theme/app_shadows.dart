import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppShadows {
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get glowShadow => [
        BoxShadow(
          color: AppColors.brandRed.withValues(alpha: 0.3),
          blurRadius: 15,
          spreadRadius: 2,
        ),
      ];
}
