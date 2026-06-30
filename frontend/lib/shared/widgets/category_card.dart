import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:hdk_core/hdk_core.dart';

const _brandRed = Color(0xFFFF1E1E);
const _deepText = Colors.white;
const _mutedText = Color(0xFFB8B8B8);
const _panel = Color(0xFF111111);
const _stroke = Color(0xFF2A2A2A);

class CategoryCard extends StatelessWidget {
  final Category category;

  const CategoryCard({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _stroke),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: category.image.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFF1E1E1E),
                      child: Icon(
                        Icons.fastfood_rounded,
                        color: _brandRed,
                        size: 24,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: category.image,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _brandRed),
                        ),
                      ),
                      errorWidget: (context, url, error) => const ColoredBox(
                        color: Color(0xFF1E1E1E),
                        child: Icon(
                          Icons.fastfood_rounded,
                          color: _brandRed,
                          size: 24,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            category.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _deepText,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: _mutedText,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
