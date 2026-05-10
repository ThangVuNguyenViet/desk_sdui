import 'package:flutter/material.dart';
import '../data/home_data.dart';
import '../controllers/home_controller.dart';
import '../widgets/recent_order_tile.dart';

Widget renderHomeRecentOrderOriginal(HomeData data, HomeController controller) {
  return Stack(
    children: [
      Container(
        color: Colors.grey[200],
      ),
      Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.white,
                ),
                child: Text(
                  data.orderAgainText,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final order in data.recentOrders) ...[
                    RecentOrderTile(
                      restaurantName: order.restaurantName,
                      items: order.items,
                      total: order.total,
                      date: order.date,
                      imageUrl: order.imageUrl,
                      onTap: () => controller.tapRecentOrder(order.id),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
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
      ),
    ],
  );
}
