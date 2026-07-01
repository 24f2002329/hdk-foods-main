import 'package:flutter/material.dart';

class RatingBadge extends StatelessWidget {
  final double rating;
  final double size;
  final Color goldColor;

  const RatingBadge({
    super.key,
    required this.rating,
    this.size = 15,
    this.goldColor = const Color(0xFFFFC107),
  });

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) {
      return Text(
        'New',
        style: TextStyle(
          color: goldColor,
          fontSize: size - 3,
          fontWeight: FontWeight.w900,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, color: goldColor, size: size),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            color: goldColor,
            fontSize: size - 3,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
