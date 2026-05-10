import 'package:flutter/foundation.dart';

class HomeController {
  HomeController({
    this.onCategoryTapped,
    this.onFeaturedTapped,
    this.onRecentOrderTapped,
    this.onStartOrderTapped,
  });

  final void Function(String categoryId)? onCategoryTapped;
  final void Function(String itemName)? onFeaturedTapped;
  final void Function(String orderId)? onRecentOrderTapped;
  final VoidCallback? onStartOrderTapped;

  void tapCategory(String id) => onCategoryTapped?.call(id);
  void tapFeatured(String name) => onFeaturedTapped?.call(name);
  void tapRecentOrder(String id) => onRecentOrderTapped?.call(id);
  void tapStartOrder() => onStartOrderTapped?.call();

  void dispose() {}
}
