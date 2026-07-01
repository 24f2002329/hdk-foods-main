import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_theme.dart';

export 'app_colors.dart';
export 'app_theme.dart';
export 'app_typography.dart';
export 'app_spacing.dart';
export 'app_radius.dart';
export 'app_shadows.dart';
export 'app_icons.dart';

class HdkTheme {
  static const Color primaryColor = AppColors.brandRed;
  static const Color backgroundColor = AppColors.background;
  static const Color surfaceColor = AppColors.surface;
  static const Color cardColor = AppColors.panel;
  static const Color borderSideColor = AppColors.border;

  static ThemeData get darkTheme => AppTheme.darkTheme;
}
