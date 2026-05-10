import 'package:flutter/material.dart';
import '../widgets/app_image.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.name,
    required this.description,
    required this.imageUrl,
    this.showImage = false,
    this.onTap,
  });

  final String name;
  final String description;
  final String imageUrl;
  final bool showImage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showImage) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppImage(url: imageUrl, width: double.infinity, height: 120),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
