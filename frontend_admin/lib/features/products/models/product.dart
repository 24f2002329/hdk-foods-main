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
  final int categoryId;
  final String categoryName;
  final String name;
  final String description;
  final double price;
  final String image;
  final bool isAvailable;
  final bool isFeatured;
  final bool isAddon;
  final int preparationTime;
  final List<ModifierGroup> modifierGroups;

  Product({
    required this.id,
    required this.categoryId,
    this.categoryName = '',
    required this.name,
    this.description = '',
    required this.price,
    this.image = '',
    this.isAvailable = true,
    this.isFeatured = false,
    this.isAddon = false,
    this.preparationTime = 15,
    required this.modifierGroups,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final cat = json['category'];
    final rawModifiers = json['modifier_groups'] as List? ?? [];
    final modifierGroups = rawModifiers
        .map((m) => ModifierGroup.fromJson(m as Map<String, dynamic>))
        .toList();

    return Product(
      id: json['id'],
      categoryId: cat is Map ? cat['id'] : (json['category_id'] ?? 0),
      categoryName: cat is Map ? (cat['name'] ?? '') : '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: double.tryParse('${json['price']}') ?? 0,
      image: json['image'] ?? '',
      isAvailable: json['is_available'] ?? true,
      isFeatured: json['is_featured'] ?? false,
      isAddon: json['is_addon'] ?? false,
      preparationTime: json['preparation_time'] ?? 15,
      modifierGroups: modifierGroups,
    );
  }

  Product copyWith({bool? isAvailable}) => Product(
        id: id,
        categoryId: categoryId,
        categoryName: categoryName,
        name: name,
        description: description,
        price: price,
        image: image,
        isAvailable: isAvailable ?? this.isAvailable,
        isFeatured: isFeatured,
        isAddon: isAddon,
        preparationTime: preparationTime,
        modifierGroups: modifierGroups,
      );
}
