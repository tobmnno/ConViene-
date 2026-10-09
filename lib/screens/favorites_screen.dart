import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/product_art.dart';
import '../widgets/screen_frame.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final favorites = state.favoriteProducts;
    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: ScreenFrame(
        child: favorites.isEmpty
            ? const Center(
                child: Text('Todavia no guardaste productos favoritos.'),
              )
            : ListView.separated(
                itemCount: favorites.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final product = favorites[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    leading: ProductArt(product: product),
                    title: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(product.presentation),
                    trailing: IconButton(
                      tooltip: 'Quitar de favoritos',
                      onPressed: () => state.toggleFavorite(product),
                      icon: const Icon(Icons.favorite, color: AppColors.blue),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      state.searchProducts(
                        product.ean.isNotEmpty ? product.ean : product.name,
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
