import 'package:flutter/material.dart';
import 'colors.dart';
import 'app_theme.dart';

export 'colors.dart';
export 'app_theme.dart';
export 'typography.dart';
export 'spacing.dart';
export 'radius.dart';
export 'elevation.dart';
export 'animation.dart';
export 'app_icons.dart';

class HdkTheme {
  static const Color primaryColor = AppColors.brandRed;
  static const Color backgroundColor = AppColors.background;
  static const Color surfaceColor = AppColors.surface;
  static const Color cardColor = AppColors.panel;
  static const Color borderSideColor = AppColors.border;

  static ThemeData get darkTheme => AppTheme.darkTheme;
}
