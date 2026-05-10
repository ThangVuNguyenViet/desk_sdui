import 'package:desk_sdui_demo/data/chef_data.dart';
import 'package:desk_sdui_demo/data/home_data.dart';

const chefFixture = ChefData(
  headline: "Chef's Table",
  bio:
      'A culinary journey through seasonal ingredients and timeless techniques. Every dish tells a story of tradition and innovation.',
  pullQuote:
      'Cooking is about patience, passion, and the pursuit of flavor that lingers in memory.',
  chefName: 'Anna Moretti',
  chefRole: 'Executive Chef',
  chefPortraitUrl: 'assets/chef_portrait.png',
  refreshCadence: 'Menu updates seasonally',
  dishes: [
    ChefDish(
      numberLabel: 'NO. 1',
      name: 'Truffle Risotto',
      description: 'Arborio rice, black truffle, parmesan, white wine reduction',
      price: 34,
      imageUrl: 'assets/dish1.png',
    ),
    ChefDish(
      numberLabel: 'NO. 2',
      name: 'Seared Scallops',
      description: 'Pan-seared diver scallops, cauliflower puree, brown butter',
      price: 42,
      imageUrl: 'assets/dish2.png',
    ),
    ChefDish(
      numberLabel: 'NO. 3',
      name: 'Wagyu Tartare',
      description: 'Hand-cut wagyu, quail egg, capers, sourdough crisps',
      price: 28,
      imageUrl: 'assets/dish3.png',
    ),
  ],
);

const homeFixtureBase = HomeData(
  greeting: 'Hi, Guest',
  points: '24 PTS',
  bannerImageUrl: 'assets/banner.png',
  backgroundImageUrl: 'assets/bg_dashboard.png',
  featuredItems: [
    FeaturedItem(
      name: 'Classic Burger',
      description: 'Angus beef, aged cheddar, truffle aioli, brioche bun',
      imageUrl: 'assets/burger.png',
    ),
    FeaturedItem(
      name: 'Caesar Salad',
      description: 'Romaine, parmesan, croutons, house-made dressing',
      imageUrl: 'assets/salad.png',
    ),
    FeaturedItem(
      name: 'Margherita Pizza',
      description: 'San Marzano tomatoes, fresh mozzarella, basil',
      imageUrl: 'assets/pizza.png',
    ),
  ],
  categories: [
    CategoryItem(id: 'c1', name: 'Burgers', imageUrl: 'assets/cat_burgers.png'),
    CategoryItem(id: 'c2', name: 'Salads', imageUrl: 'assets/cat_salads.png'),
    CategoryItem(id: 'c3', name: 'Pizza', imageUrl: 'assets/cat_pizza.png'),
    CategoryItem(id: 'c4', name: 'Drinks', imageUrl: 'assets/cat_drinks.png'),
  ],
  recentOrders: [
    RecentOrder(
      id: 'o1',
      restaurantName: 'Burger Joint',
      items: 'Classic Burger x2, Fries',
      total: 28.50,
      date: 'Dec 15',
      imageUrl: 'assets/order1.png',
    ),
    RecentOrder(
      id: 'o2',
      restaurantName: 'Pizza Palace',
      items: 'Margherita Pizza, Garlic Bread',
      total: 22.00,
      date: 'Dec 12',
      imageUrl: 'assets/order2.png',
    ),
  ],
  orderAgainText: 'Recent Orders',
  startOrderLabel: 'START ORDER',
  showCategories: true,
  showRecentOrders: true,
  showFeatured: true,
);
