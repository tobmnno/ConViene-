import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';

class ProductArt extends StatelessWidget {
  const ProductArt({super.key, required this.product, this.size = 74});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (product.imageUrl.trim().isNotEmpty) {
      return _NetworkProductArt(product: product, size: size);
    }
    return _FallbackProductArt(product: product, size: size);
  }
}

class _NetworkProductArt extends StatelessWidget {
  const _NetworkProductArt({required this.product, required this.size});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = _FallbackProductArt(product: product, size: size * 0.84);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          product.imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => fallback,
          loadingBuilder: (context, child, progress) {
            if (progress == null) {
              return child;
            }
            return fallback;
          },
        ),
      ),
    );
  }
}

class _FallbackProductArt extends StatelessWidget {
  const _FallbackProductArt({required this.product, required this.size});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsForTag(product.imageTag);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Container(
          width: size * 0.44,
          height: size * 0.68,
          decoration: BoxDecoration(
            color: colors.main,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22102A56),
                blurRadius: 8,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                height: size * 0.16,
                margin: EdgeInsets.all(size * 0.05),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Icon(
                _iconForTag(product.imageTag),
                color: colors.accent,
                size: size * 0.20,
              ),
              Container(
                height: size * 0.13,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _ProductArtColors _colorsForTag(String tag) {
    return switch (tag) {
      'milk' => const _ProductArtColors(
        background: Color(0xFFEAF2FF),
        main: Color(0xFF1C68E8),
        accent: Color(0xFFFFFFFF),
      ),
      'coffee' => const _ProductArtColors(
        background: Color(0xFFEAF7EA),
        main: Color(0xFF254B2F),
        accent: Color(0xFFD6B66F),
      ),
      'yerba' => const _ProductArtColors(
        background: Color(0xFFFFF4E5),
        main: Color(0xFF0F5C43),
        accent: Color(0xFFFFB020),
      ),
      'bread' => const _ProductArtColors(
        background: Color(0xFFFFF0E6),
        main: Color(0xFFFFB020),
        accent: Color(0xFFB54708),
      ),
      'oil' => const _ProductArtColors(
        background: Color(0xFFFFFBEA),
        main: Color(0xFFFEC84B),
        accent: Color(0xFF16B364),
      ),
      _ => const _ProductArtColors(
        background: AppColors.softBlue,
        main: AppColors.blue,
        accent: AppColors.white,
      ),
    };
  }

  IconData _iconForTag(String tag) {
    return switch (tag) {
      'milk' => Icons.water_drop,
      'coffee' => Icons.coffee,
      'yerba' => Icons.eco,
      'bread' => Icons.bakery_dining,
      'oil' => Icons.water_drop,
      _ => Icons.shopping_bag,
    };
  }
}

class _ProductArtColors {
  const _ProductArtColors({
    required this.background,
    required this.main,
    required this.accent,
  });

  final Color background;
  final Color main;
  final Color accent;
}
