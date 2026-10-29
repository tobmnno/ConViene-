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
        color: AppColors.surface,
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
            return DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.softBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(child: Icon(Icons.image_outlined, size: 20)),
            );
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: AppColors.textGray,
          size: size * 0.4,
        ),
      ),
    );
  }
}
