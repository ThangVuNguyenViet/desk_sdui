class FeaturedItem {
  const FeaturedItem({
    required this.name,
    required this.description,
    required this.imageUrl,
  });

  final String name;
  final String description;
  final String imageUrl;
}

class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.name,
    required this.imageUrl,
  });

  final String id;
  final String name;
  final String imageUrl;
}

class RecentOrder {
  const RecentOrder({
    required this.id,
    required this.restaurantName,
    required this.items,
    required this.total,
    required this.date,
    required this.imageUrl,
  });

  final String id;
  final String restaurantName;
  final String items;
  final double total;
  final String date;
  final String imageUrl;
}

class HomeData {
  const HomeData({
    required this.greeting,
    required this.points,
    required this.bannerImageUrl,
    required this.backgroundImageUrl,
    required this.featuredItems,
    required this.categories,
    required this.recentOrders,
    required this.orderAgainText,
    required this.startOrderLabel,
    required this.showCategories,
    required this.showRecentOrders,
    required this.showFeatured,
  });

  final String greeting;
  final String points;
  final String bannerImageUrl;
  final String backgroundImageUrl;
  final List<FeaturedItem> featuredItems;
  final List<CategoryItem> categories;
  final List<RecentOrder> recentOrders;
  final String orderAgainText;
  final String startOrderLabel;
  final bool showCategories;
  final bool showRecentOrders;
  final bool showFeatured;
}
