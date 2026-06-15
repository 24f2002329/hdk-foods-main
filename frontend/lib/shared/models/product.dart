class Product {
  final int id;
  final String name;
  final String description;
  final String image;
  final double price;

  final bool isFeatured;
  final bool isAddon;
  final int preparationTime;
  final int? categoryId;
  final double rating;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    required this.price,
    required this.isFeatured,
    this.isAddon = false,
    required this.preparationTime,
    this.categoryId,
    this.rating = 0,
  });

  factory Product.fromJson(
    Map<String, dynamic> json,
  ) {
    final category = json["category"];
    final int? categoryId = category is Map
        ? category["id"] as int?
        : (category is int ? category : null);

    return Product(
      id: json["id"],

      name: json["name"],

      description:
          json["description"] ?? "",

      image:
          json["image"] ?? "",

      price: double.parse(
        json["price"].toString(),
      ),

      isFeatured:
          json["is_featured"] ?? false,

      isAddon:
          json["is_addon"] ?? false,

      preparationTime:
          json["preparation_time"] ?? 15,

      categoryId: categoryId,

      rating: double.tryParse(
            json["rating"]?.toString() ?? "",
          ) ??
          0,
    );
  }
}