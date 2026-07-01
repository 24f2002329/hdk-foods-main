import 'modifier.dart';
export 'modifier.dart';

class Category {
  final int id;
  final String name;
  final String image;

  Category({required this.id, required this.name, this.image = ''});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'],
    name: json['name'] ?? '',
    image: json['image'] ?? '',
  );
}

class Product {
  final int id;
  final int? categoryId;
  final String categoryName;
  final String name;
  final String description;
  final double price;
  final double? strikePrice;
  final String promoTag;
  final String image;
  final bool isAvailable;
  final bool isFeatured;
  final bool isAddon;
  final int preparationTime;
  final double rating;
  final List<ModifierGroup> modifierGroups;

  Product({
    required this.id,
    this.categoryId,
    this.categoryName = '',
    required this.name,
    this.description = '',
    required this.price,
    this.strikePrice,
    this.promoTag = "",
    this.image = '',
    this.isAvailable = true,
    this.isFeatured = false,
    this.isAddon = false,
    this.preparationTime = 15,
    this.rating = 0.0,
    this.modifierGroups = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final cat = json['category'];
    final int? catId = cat is Map
        ? cat['id'] as int?
        : (cat is int ? cat : (json['category_id'] as int?));

    final String catName = cat is Map ? (cat['name'] ?? '') : '';

    final rawModifiers = json['modifier_groups'] as List? ?? [];
    final modifierGroups = rawModifiers
        .map((m) => ModifierGroup.fromJson(m as Map<String, dynamic>))
        .toList();

    return Product(
      id: json['id'],
      categoryId: catId,
      categoryName: catName,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: double.tryParse('${json['price']}') ?? 0.0,
      strikePrice: json['strike_price'] != null
          ? double.tryParse(json['strike_price'].toString())
          : null,
      promoTag: json['promo_tag'] ?? '',
      image: json['image'] ?? '',
      isAvailable: json['is_available'] ?? true,
      isFeatured: json['is_featured'] ?? false,
      isAddon: json['is_addon'] ?? false,
      preparationTime: json['preparation_time'] ?? 15,
      rating: double.tryParse(json['rating']?.toString() ?? '') ?? 0.0,
      modifierGroups: modifierGroups,
    );
  }

  Product copyWith({
    bool? isAvailable,
    String? name,
    double? price,
    String? image,
    String? description,
    bool? isFeatured,
    bool? isAddon,
    int? preparationTime,
    int? categoryId,
    String? categoryName,
    double? rating,
    List<ModifierGroup>? modifierGroups,
  }) => Product(
    id: id,
    categoryId: categoryId ?? this.categoryId,
    categoryName: categoryName ?? this.categoryName,
    name: name ?? this.name,
    description: description ?? this.description,
    price: price ?? this.price,
    strikePrice: strikePrice,
    promoTag: promoTag,
    image: image ?? this.image,
    isAvailable: isAvailable ?? this.isAvailable,
    isFeatured: isFeatured ?? this.isFeatured,
    isAddon: isAddon ?? this.isAddon,
    preparationTime: preparationTime ?? this.preparationTime,
    rating: rating ?? this.rating,
    modifierGroups: modifierGroups ?? this.modifierGroups,
  );
}
