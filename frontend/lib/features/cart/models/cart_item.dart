import '../../../shared/models/product.dart';

class CartItem {
  final Product product;
  final int quantity;

  const CartItem({
    required this.product,
    required this.quantity,
  });

  CartItem copyWith({Product? product, int? quantity}) => CartItem(
        product: product ?? this.product,
        quantity: quantity ?? this.quantity,
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
        'quantity': quantity,
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
        ),
        quantity: json['quantity'] ?? 1,
      );
}
