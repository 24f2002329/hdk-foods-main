import 'package:flutter/material.dart';
import '../../theme/hdk_theme.dart';

class HdkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final double? width;
  final double height;

  const HdkButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.prefixIcon,
    this.suffixIcon,
    this.width,
    this.height = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null || isLoading;

    final Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading) ...[
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
        ] else ...[
          if (prefixIcon != null) ...[
            Icon(prefixIcon, size: 18),
            const SizedBox(width: 8),
          ],
        ],
        Text(
          label,
          style: AppTypography.buttonText.copyWith(
            color: isOutlined
                ? (isDisabled ? AppColors.mutedText : AppColors.primary)
                : Colors.white,
          ),
        ),
        if (!isLoading && suffixIcon != null) ...[
          const SizedBox(width: 8),
          Icon(suffixIcon, size: 18),
        ],
      ],
    );

    final double btnWidth = width ?? double.infinity;

    if (isOutlined) {
      return SizedBox(
        width: btnWidth,
        height: height,
        child: OutlinedButton(
          onPressed: isDisabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(
              color: isDisabled ? AppColors.border : AppColors.primary,
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.mdBorderRadius,
            ),
          ),
          child: content,
        ),
      );
    }

    return SizedBox(
      width: btnWidth,
      height: height,
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.border,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorderRadius),
          elevation: 0,
        ),
        child: content,
      ),
    );
  }
}
