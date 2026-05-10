import 'package:flutter/material.dart';
import '../data/home_data.dart';
import '../controllers/home_controller.dart';
import '../widgets/product_card.dart';
import '../widgets/category_tile.dart';

Widget renderHomeCategoriesOriginal(HomeData data, HomeController controller) {
  return Scaffold(
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const SizedBox(height: 24),
        Flexible(
          child: _buildFeaturedItems(data, controller),
        ),
        if (data.showCategories) _buildCategories(data, controller),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: controller.tapStartOrder,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(data.startOrderLabel),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    ),
  );
}

Widget _buildFeaturedItems(HomeData data, HomeController controller) {
  final items = data.featuredItems.isEmpty
      ? <FeaturedItem>[]
      : [data.featuredItems.first];
  return PageView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) {
      final item = items[index];
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ProductCard(
          name: item.name,
          description: item.description,
          imageUrl: item.imageUrl,
          showImage: false,
          onTap: () => controller.tapFeatured(item.name),
        ),
      );
    },
  );
}

Widget _buildCategories(HomeData data, HomeController controller) {
  if (data.categories.isEmpty) return const SizedBox();
  return Container(
    height: 120,
    margin: const EdgeInsets.only(top: 24),
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: data.categories.length,
      separatorBuilder: (context, index) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        final category = data.categories[index];
        return CategoryTile(
          name: category.name,
          imageUrl: category.imageUrl,
          onTap: () => controller.tapCategory(category.id),
        );
      },
    ),
  );
}
