import 'package:flutter/material.dart';
import '../../theme/hdk_theme.dart';

class HdkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool hasGlow;
  final bool hasShadow;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const HdkCard({
    super.key,
    required this.child,
    this.padding,
    this.hasGlow = false,
    this.hasShadow = true,
    this.width,
    this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    List<BoxShadow>? shadows;
    if (hasGlow) {
      shadows = AppShadows.glowShadow;
    } else if (hasShadow) {
      shadows = AppShadows.cardShadow;
    }

    final Widget cardContent = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdBorderRadius,
        border: Border.all(color: AppColors.border),
        boxShadow: shadows,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdBorderRadius,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
