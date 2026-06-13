import 'package:flutter/material.dart';

import '../models/product.dart';

const _brandRed = Color(0xFFFF1E1E);
const _deepText = Colors.white;
const _mutedText = Color(0xFFB8B8B8);
const _panel = Color(0xFF111111);
const _panelAlt = Color(0xFF1E1E1E);
const _stroke = Color(0xFF2A2A2A);
const _gold = Color(0xFFFFC107);

class ProductCard extends StatelessWidget {
  final Product product;
  final int quantity;
  final VoidCallback? onAddPressed;
  final VoidCallback? onIncreasePressed;
  final VoidCallback? onDecreasePressed;

  const ProductCard({
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.14,
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
              Positioned(
                left: 10,
                bottom: 10,
                child: _InfoChip(
                  icon: Icons.schedule_rounded,
                  label: '${product.preparationTime} min',
                ),
              ),
              if (product.isFeatured)
                const Positioned(
                  top: 10,
                  right: 10,
                  child: _InfoChip(
                    icon: Icons.star_rounded,
                    label: 'Top',
                    dark: true,
                  ),
                ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(
                    Icons.favorite_border_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
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
                      fontSize: 13,
                      height: 1.16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (product.rating > 0) ...[
                        const Icon(Icons.star_rounded, color: _gold, size: 14),
                        const SizedBox(width: 3),
                        Text(
                          product.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: _gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ] else
                        const Text(
                          'New',
                          style: TextStyle(
                            color: _gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${product.preparationTime} min',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _mutedText,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  if (product.description.isNotEmpty)
                    Text(
                      product.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    const Text(
                      'Freshly prepared',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _mutedText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const Spacer(),
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
                            fontSize: 14,
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
                          width: 48,
                          height: 34,
                          child: IconButton.filled(
                            onPressed: onAddPressed,
                            style: IconButton.styleFrom(
                              backgroundColor: _brandRed,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
        child: Icon(Icons.restaurant_rounded, color: _brandRed, size: 42),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool dark;

  const _InfoChip({required this.icon, required this.label, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: dark ? _brandRed : Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: dark ? _brandRed : Colors.white24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: dark ? Colors.white : _brandRed, size: 13),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
      width: 88,
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
              fontSize: 14,
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
      width: 32,
      height: 38,
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
