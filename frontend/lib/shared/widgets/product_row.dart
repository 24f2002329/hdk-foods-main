import 'package:flutter/material.dart';

import '../models/product.dart';

const _brandRed = Color(0xFFFF1E1E);
const _deepText = Colors.white;
const _mutedText = Color(0xFFB8B8B8);
const _panel = Color(0xFF111111);
const _panelAlt = Color(0xFF1E1E1E);
const _stroke = Color(0xFF2A2A2A);
const _gold = Color(0xFFFFC107);

class ProductRow extends StatelessWidget {
  final Product product;
  final int quantity;
  final VoidCallback? onAddPressed;
  final VoidCallback? onIncreasePressed;
  final VoidCallback? onDecreasePressed;

  const ProductRow({
    super.key,
    required this.product,
    this.quantity = 0,
    this.onAddPressed,
    this.onIncreasePressed,
    this.onDecreasePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 92,
                height: 92,
                child: product.image.isEmpty
                    ? const _ProductImageFallback()
                    : Image.network(
                        product.image,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const _ProductImageFallback();
                        },
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _deepText,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ProductRating(rating: product.rating),
                      const SizedBox(width: 8),
                      Text(
                        '${product.preparationTime} min',
                        style: const TextStyle(
                          color: _mutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '₹${product.price.toStringAsFixed(0)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _deepText,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (quantity > 0)
                        _QuantityStepper(
                          quantity: quantity,
                          onDecreasePressed: onDecreasePressed,
                          onIncreasePressed: onIncreasePressed ?? onAddPressed,
                        )
                      else
                        SizedBox(
                          height: 34,
                          child: FilledButton.icon(
                            onPressed: onAddPressed,
                            style: FilledButton.styleFrom(
                              backgroundColor: _brandRed,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text(
                              'Add',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductRating extends StatelessWidget {
  final double rating;
  final double size;

  const ProductRating({super.key, required this.rating, this.size = 15});

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) {
      return Text(
        'New',
        style: TextStyle(
          color: _gold,
          fontSize: size - 3,
          fontWeight: FontWeight.w900,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, color: _gold, size: size),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            color: _gold,
            fontSize: size - 3,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: _panelAlt,
      child: Center(
        child: Icon(Icons.restaurant_rounded, color: _brandRed, size: 34),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback? onDecreasePressed;
  final VoidCallback? onIncreasePressed;

  const _QuantityStepper({
    required this.quantity,
    required this.onDecreasePressed,
    required this.onIncreasePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 34,
      decoration: BoxDecoration(
        color: _panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StepperButton(
            icon: Icons.remove_rounded,
            onPressed: onDecreasePressed,
          ),
          Text(
            quantity.toString(),
            style: const TextStyle(
              color: _deepText,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          _StepperButton(icon: Icons.add_rounded, onPressed: onIncreasePressed),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _StepperButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 34,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: _brandRed,
        iconSize: 18,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
