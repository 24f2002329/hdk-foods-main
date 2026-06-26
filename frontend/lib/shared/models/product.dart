import 'modifier.dart';
export 'modifier.dart';

class Product {
  final int id;
  final String name;
  final String description;
  final String image;
  final double price;
  final double? strikePrice;
  final String promoTag;

  final bool isFeatured;
  final bool isAddon;
  final int preparationTime;
  final int? categoryId;
  final double rating;
  final bool isAvailable;
  final List<ModifierGroup> modifierGroups;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    required this.price,
    this.strikePrice,
    this.promoTag = "",
    required this.isFeatured,
    this.isAddon = false,
    required this.preparationTime,
    this.categoryId,
    this.rating = 0,
    this.isAvailable = true,
    required this.modifierGroups,
  });

  factory Product.fromJson(
    Map<String, dynamic> json,
  ) {
    final category = json["category"];
    final int? categoryId = category is Map
        ? category["id"] as int?
        : (category is int ? category : null);

    final rawModifiers = json["modifier_groups"] as List? ?? [];
    final modifierGroups = rawModifiers
        .map((m) => ModifierGroup.fromJson(m as Map<String, dynamic>))
        .toList();

    return Product(
      id: json["id"],
      name: json["name"],
      description: json["description"] ?? "",
      image: json["image"] ?? "",
      price: double.parse(
        json["price"].toString(),
      ),
      strikePrice: json["strike_price"] != null
          ? double.tryParse(json["strike_price"].toString())
          : null,
      promoTag: json["promo_tag"] ?? "",
      isFeatured: json["is_featured"] ?? false,
      isAddon: json["is_addon"] ?? false,
      preparationTime: json["preparation_time"] ?? 15,
      categoryId: categoryId,
      rating: double.tryParse(
            json["rating"]?.toString() ?? "",
          ) ??
          0,
      isAvailable: json["is_available"] ?? true,
      modifierGroups: modifierGroups,
    );
  }
}