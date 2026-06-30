import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:hdk_core/hdk_core.dart';

const _brandRed = Color(0xFFFF1E1E);
const _deepText = Colors.white;
const _mutedText = Color(0xFFB8B8B8);
const _panel = Color(0xFF111111);
const _panelAlt = Color(0xFF1E1E1E);
const _stroke = Color(0xFF2A2A2A);

class CategoryGridCard extends StatelessWidget {
  final Category category;
  final int itemCount;
  final VoidCallback? onTap;

  const CategoryGridCard({
    super.key,
    required this.category,
    this.itemCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _panel,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.5,
                child: category.image.isEmpty
                    ? const _CategoryImageFallback()
                    : CachedNetworkImage(
                        imageUrl: category.image,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _brandRed),
                          ),
                        ),
                        errorWidget: (context, url, error) => const _CategoryImageFallback(),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _deepText,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.restaurant_menu_rounded,
                          color: _brandRed,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                          style: const TextStyle(
                            color: _mutedText,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
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
      ),
    );
  }
}

class _CategoryImageFallback extends StatelessWidget {
  const _CategoryImageFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: _panelAlt,
      child: Center(
        child: Icon(Icons.fastfood_rounded, color: _brandRed, size: 38),
      ),
    );
  }
}
