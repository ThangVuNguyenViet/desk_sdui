import 'package:flutter/material.dart';
import '../widgets/app_image.dart';

class RecentOrderTile extends StatelessWidget {
  const RecentOrderTile({
    super.key,
    required this.restaurantName,
    required this.items,
    required this.total,
    required this.date,
    required this.imageUrl,
    this.onTap,
  });

  final String restaurantName;
  final String items;
  final double total;
  final String date;
  final String imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AppImage(url: imageUrl, width: 56, height: 56),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurantName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(items, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    Text(
                      '$date · \$${total.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
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
