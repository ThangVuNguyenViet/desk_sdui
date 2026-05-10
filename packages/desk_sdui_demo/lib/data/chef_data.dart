class ChefSpecialty {
  const ChefSpecialty({
    required this.id,
    required this.name,
    required this.imageUrl,
  });

  final String id;
  final String name;
  final String imageUrl;
}

class ChefDish {
  const ChefDish({
    required this.numberLabel,
    required this.name,
    required this.description,
    required this.price,
    required this.priceLabel,
    required this.imageUrl,
  });

  final String numberLabel;
  final String name;
  final String description;
  final double price;
  final String priceLabel;
  final String imageUrl;
}

class ChefData {
  const ChefData({
    required this.headline,
    required this.bio,
    required this.pullQuote,
    required this.chefName,
    required this.chefRole,
    required this.chefRoleUpper,
    required this.chefPortraitUrl,
    required this.refreshCadence,
    required this.dishes,
  });

  final String headline;
  final String bio;
  final String pullQuote;
  final String chefName;
  final String chefRole;
  final String chefRoleUpper;
  final String chefPortraitUrl;
  final String refreshCadence;
  final List<ChefDish> dishes;
}
