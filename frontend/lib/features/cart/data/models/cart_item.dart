import 'package:hdk_core/hdk_core.dart';

class SelectedModifier {
  final String groupName;
  final String optionName;
  final double price;

  SelectedModifier({
    required this.groupName,
    required this.optionName,
    required this.price,
  });

  Map<String, dynamic> toJson() => {
    'group': groupName,
    'option': optionName,
    'price': price,
  };

  factory SelectedModifier.fromJson(Map<String, dynamic> json) =>
      SelectedModifier(
        groupName: json['group'] ?? '',
        optionName: json['option'] ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedModifier &&
          runtimeType == other.runtimeType &&
          groupName == other.groupName &&
          optionName == other.optionName &&
          price == other.price;

  @override
  int get hashCode => groupName.hashCode ^ optionName.hashCode ^ price.hashCode;
}

class CartItem {
  final Product product;
  final int quantity;
  final List<SelectedModifier> selectedModifiers;
  final String? notes;

  const CartItem({
    required this.product,
    required this.quantity,
    this.selectedModifiers = const [],
    this.notes,
  });

  String get cartId =>
      '${product.id}_${selectedModifiers.map((m) => '${m.groupName}:${m.optionName}').join(',')}_${notes ?? ""}';

  // Dynamic getters for backwards-compatibility
  String? get size {
    for (final m in selectedModifiers) {
      if (m.groupName.toLowerCase().contains("size")) {
        return m.optionName;
      }
    }
    return null;
  }

  String? get spiceLevel {
    for (final m in selectedModifiers) {
      if (m.groupName.toLowerCase().contains("spice")) {
        return m.optionName;
      }
    }
    return null;
  }

  List<String> get customizations {
    final list = <String>[];
    for (final m in selectedModifiers) {
      final grp = m.groupName.toLowerCase();
      if (!grp.contains("size") && !grp.contains("spice")) {
        list.add('${m.groupName}: ${m.optionName}');
      }
    }
    return list;
  }

  double get customizationPrice =>
      selectedModifiers.fold(0.0, (sum, m) => sum + m.price);

  double get unitPrice => product.price + customizationPrice;

  double get totalPrice => unitPrice * quantity;

  CartItem copyWith({
    Product? product,
    int? quantity,
    List<SelectedModifier>? selectedModifiers,
    String? notes,
  }) => CartItem(
    product: product ?? this.product,
    quantity: quantity ?? this.quantity,
    selectedModifiers: selectedModifiers ?? this.selectedModifiers,
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
    'selectedModifiers': selectedModifiers.map((m) => m.toJson()).toList(),
    'notes': notes,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final rawModifiers = json['selectedModifiers'] as List? ?? [];
    final List<SelectedModifier> modifiers = rawModifiers
        .map((m) => SelectedModifier.fromJson(m as Map<String, dynamic>))
        .toList();

    // Support legacy format migration if present
    if (modifiers.isEmpty) {
      if (json['size'] != null) {
        modifiers.add(
          SelectedModifier(
            groupName: "Size",
            optionName: json['size'],
            price: (json['customizationPrice'] as num?)?.toDouble() ?? 0.0,
          ),
        );
      }
      if (json['spiceLevel'] != null) {
        modifiers.add(
          SelectedModifier(
            groupName: "Spice Level",
            optionName: json['spiceLevel'],
            price: 0.0,
          ),
        );
      }
      if (json['customizations'] != null) {
        final legacyCusts = List<String>.from(json['customizations']);
        for (final c in legacyCusts) {
          final parts = c.split(": ");
          modifiers.add(
            SelectedModifier(
              groupName: parts.length > 1 ? parts[0] : "Extra",
              optionName: parts.length > 1 ? parts[1] : c,
              price: 0.0,
            ),
          );
        }
      }
    }

    return CartItem(
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
        modifierGroups: [],
      ),
      quantity: json['quantity'] ?? 1,
      selectedModifiers: modifiers,
      notes: json['notes'],
    );
  }
}
