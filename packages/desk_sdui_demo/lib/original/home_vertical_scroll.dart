import 'package:flutter/material.dart';
import '../data/home_data.dart';
import '../controllers/home_controller.dart';
import '../widgets/product_card.dart';

Widget renderHomeScrollOriginal(HomeData data, HomeController controller) {
  return Scaffold(
    body: Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.greeting,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: Text(data.points),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 102,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.image, size: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                for (final item in data.featuredItems) ...[
                  ProductCard(
                    name: item.name,
                    description: item.description,
                    imageUrl: item.imageUrl,
                    showImage: true,
                    onTap: () => controller.tapFeatured(item.name),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
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
      ],
    ),
  );
}
