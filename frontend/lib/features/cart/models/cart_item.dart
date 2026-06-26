import '../../../shared/models/product.dart';

class CartItem {
  final Product product;
  final int quantity;
  final String? size;
  final String? spiceLevel;
  final List<String> customizations;
  final double customizationPrice;
  final String? notes;

  const CartItem({
    required this.product,
    required this.quantity,
    this.size,
    this.spiceLevel,
    this.customizations = const [],
    this.customizationPrice = 0.0,
    this.notes,
  });

  String get cartId => '${product.id}_${size ?? ""}_${spiceLevel ?? ""}_${customizations.join(",")}_${notes ?? ""}';

  double get unitPrice => product.price + customizationPrice;

  double get totalPrice => unitPrice * quantity;

  CartItem copyWith({
    Product? product,
    int? quantity,
    String? size,
    String? spiceLevel,
    List<String>? customizations,
    double? customizationPrice,
    String? notes,
  }) =>
      CartItem(
        product: product ?? this.product,
        quantity: quantity ?? this.quantity,
        size: size ?? this.size,
        spiceLevel: spiceLevel ?? this.spiceLevel,
        customizations: customizations ?? this.customizations,
        customizationPrice: customizationPrice ?? this.customizationPrice,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => {
        'productId': product.id,
        'name': product.name,
        'description': product.description,
        'image': product.image,
        'price': product.price,
        'isFeatured': product.isFeatured,
        'isAddon': product.isAddon,
        'preparationTime': product.preparationTime,
        'categoryId': product.categoryId,
        'rating': product.rating,
        'isAvailable': product.isAvailable,
        'quantity': quantity,
        'size': size,
        'spiceLevel': spiceLevel,
        'customizations': customizations,
        'customizationPrice': customizationPrice,
        'notes': notes,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        product: Product(
          id: json['productId'],
          name: json['name'] ?? '',
          description: json['description'] ?? '',
          image: json['image'] ?? '',
          price: (json['price'] as num).toDouble(),
          isFeatured: json['isFeatured'] ?? false,
          isAddon: json['isAddon'] ?? false,
          preparationTime: json['preparationTime'] ?? 15,
          categoryId: json['categoryId'],
          rating: (json['rating'] as num?)?.toDouble() ?? 0,
          isAvailable: json['isAvailable'] ?? true,
        ),
        quantity: json['quantity'] ?? 1,
        size: json['size'],
        spiceLevel: json['spiceLevel'],
        customizations: List<String>.from(json['customizations'] ?? []),
        customizationPrice: (json['customizationPrice'] as num?)?.toDouble() ?? 0.0,
        notes: json['notes'],
      );
}
