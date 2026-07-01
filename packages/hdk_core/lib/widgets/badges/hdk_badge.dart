import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';

enum HdkBadgeType { primary, success, warning, error, neutral }

class HdkBadge extends StatelessWidget {
  final String label;
  final HdkBadgeType type;
  final bool isSmall;

  const HdkBadge({
    super.key,
    required this.label,
    this.type = HdkBadgeType.neutral,
    this.isSmall = false,
  });

  Color _getBackgroundColor() {
    switch (type) {
      case HdkBadgeType.primary:
        return AppColors.primary.withValues(alpha: 0.15);
      case HdkBadgeType.success:
        return AppColors.success.withValues(alpha: 0.15);
      case HdkBadgeType.warning:
        return AppColors.warning.withValues(alpha: 0.15);
      case HdkBadgeType.error:
        return AppColors.error.withValues(alpha: 0.15);
      case HdkBadgeType.neutral:
        return AppColors.border;
    }
  }

  Color _getTextColor() {
    switch (type) {
      case HdkBadgeType.primary:
        return AppColors.primary;
      case HdkBadgeType.success:
        return AppColors.success;
      case HdkBadgeType.warning:
        return AppColors.warning;
      case HdkBadgeType.error:
        return AppColors.error;
      case HdkBadgeType.neutral:
        return AppColors.mutedText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8.0 : 12.0,
        vertical: isSmall ? 4.0 : 6.0,
      ),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: AppRadius.xsBorderRadius,
        border: Border.all(
          color: _getTextColor().withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: _getTextColor(),
          fontWeight: FontWeight.bold,
          fontSize: isSmall ? 10 : 12,
        ),
      ),
    );
  }
}
