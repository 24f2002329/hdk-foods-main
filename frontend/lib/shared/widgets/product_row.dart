import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:hdk_core/hdk_core.dart';
import 'fly_to_cart.dart';
import 'rating_badge.dart';
import 'quantity_selector.dart';
import 'shimmer_image_placeholder.dart';

const _brandRed = Color(0xFFFF1E1E);
const _deepText = Colors.white;
const _mutedText = Color(0xFFB8B8B8);
const _panel = Color(0xFF111111);
const _panelAlt = Color(0xFF1E1E1E);
const _stroke = Color(0xFF2A2A2A);

class ProductRow extends StatefulWidget {
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
  State<ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends State<ProductRow> {
  final GlobalKey _imageKey = GlobalKey();

  Product get product => widget.product;
  int get quantity => widget.quantity;
  VoidCallback? get onAddPressed => widget.onAddPressed;
  VoidCallback? get onIncreasePressed => widget.onIncreasePressed;
  VoidCallback? get onDecreasePressed => widget.onDecreasePressed;

  void _onAdd() {
    final ctx = _imageKey.currentContext;
    if (ctx != null && product.image.isNotEmpty) {
      FlyToCart.run(sourceContext: ctx, imageUrl: product.image);
    }
    onAddPressed?.call();
  }

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
              key: _imageKey,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 92,
                height: 92,
                child: product.image.isEmpty
                    ? const _ProductImageFallback()
                    : CachedNetworkImage(
                        imageUrl: product.image,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const ShimmerImagePlaceholder(
                          borderRadius: 0,
                        ),
                        errorWidget: (context, url, error) =>
                            const _ProductImageFallback(),
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
                      RatingBadge(rating: product.rating),
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
                        QuantitySelector(
                          quantity: quantity,
                          onDecreasePressed: onDecreasePressed,
                          onIncreasePressed: onIncreasePressed ?? onAddPressed,
                          width: 104,
                          panelColor: _panelAlt,
                          strokeColor: _stroke,
                        )
                      else
                        SizedBox(
                          height: 34,
                          child: FilledButton.icon(
                            onPressed: onAddPressed == null ? null : _onAdd,
                            style: FilledButton.styleFrom(
                              backgroundColor: _brandRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
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
