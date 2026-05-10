import 'package:flutter/material.dart';
import '../data/home_data.dart';
import '../controllers/home_controller.dart';
import '../widgets/product_card.dart';

Widget renderHomeBasicOriginal(HomeData data, HomeController controller) {
  return Scaffold(
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const SizedBox(height: 24),
        Flexible(
          child: _buildFeaturedItems(data, controller),
        ),
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
  return PageView.builder(
    itemCount: data.featuredItems.length,
    itemBuilder: (context, index) {
      final item = data.featuredItems[index];
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
