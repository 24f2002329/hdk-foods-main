import 'package:flutter/material.dart';

class QuantitySelector extends StatelessWidget {
  final int quantity;
  final VoidCallback? onDecreasePressed;
  final VoidCallback? onIncreasePressed;
  final double width;
  final double height;
  final Color brandColor;
  final Color panelColor;
  final Color strokeColor;

  const QuantitySelector({
    super.key,
    required this.quantity,
    required this.onDecreasePressed,
    required this.onIncreasePressed,
    this.width = 96,
    this.height = 34,
    this.brandColor = const Color(0xFFFF1E1E),
    this.panelColor = const Color(0xFF1E1E1E),
    this.strokeColor = const Color(0xFF2A2A2A),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: strokeColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StepperButton(
            icon: Icons.remove_rounded,
            onPressed: onDecreasePressed,
            color: brandColor,
          ),
          Text(
            quantity.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            onPressed: onIncreasePressed,
            color: brandColor,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  const _StepperButton({
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 34,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: color,
        iconSize: 18,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
