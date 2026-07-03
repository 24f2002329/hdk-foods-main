import 'package:flutter/material.dart';
import '../../theme/hdk_theme.dart';

class HdkChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool>? onSelected;
  final Widget? avatar;

  const HdkChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onSelected,
    this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      avatar: avatar,
      labelStyle: AppTypography.bodySmall.copyWith(
        color: isSelected ? Colors.white : AppColors.mutedText,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      disabledColor: AppColors.border,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.smBorderRadius,
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
        ),
      ),
    );
  }
}
