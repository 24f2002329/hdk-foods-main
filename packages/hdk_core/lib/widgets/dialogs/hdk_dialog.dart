import 'package:flutter/material.dart';
import '../../theme/hdk_theme.dart';
import '../buttons/hdk_button.dart';

class HdkDialog extends StatelessWidget {
  final String title;
  final String content;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool isDestructive;

  const HdkDialog({
    super.key,
    required this.title,
    required this.content,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.isDestructive = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String content,
    String? primaryActionLabel,
    VoidCallback? onPrimaryAction,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryAction,
    bool isDestructive = false,
  }) {
    return showDialog(
      context: context,
      builder: (context) => HdkDialog(
        title: title,
        content: content,
        primaryActionLabel: primaryActionLabel,
        onPrimaryAction: onPrimaryAction,
        secondaryActionLabel: secondaryActionLabel,
        onSecondaryAction: onSecondaryAction,
        isDestructive: isDestructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgBorderRadius,
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: AppTypography.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              content,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.mutedText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (secondaryActionLabel != null)
                  Expanded(
                    child: HdkButton(
                      label: secondaryActionLabel!,
                      isOutlined: true,
                      onPressed:
                          onSecondaryAction ??
                          () => Navigator.of(context).pop(),
                    ),
                  ),
                if (secondaryActionLabel != null && primaryActionLabel != null)
                  const SizedBox(width: 12),
                if (primaryActionLabel != null)
                  Expanded(
                    child: HdkButton(
                      label: primaryActionLabel!,
                      onPressed: onPrimaryAction,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
