class Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final String image;
  final bool isAvailable;

  Product({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.image = '',
    this.isAvailable = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'],
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        price: double.tryParse('${json['price']}') ?? 0,
        image: json['image'] ?? '',
        isAvailable: json['is_available'] ?? true,
      );
}
