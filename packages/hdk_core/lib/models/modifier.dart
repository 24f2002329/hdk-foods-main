class ModifierOption {
  final int id;
  final String name;
  final double extraPrice;
  final bool isAvailable;
  final String image;
  final int sortOrder;

  ModifierOption({
    required this.id,
    required this.name,
    required this.extraPrice,
    this.isAvailable = true,
    this.image = "",
    this.sortOrder = 0,
  });

  factory ModifierOption.fromJson(Map<String, dynamic> json) {
    return ModifierOption(
      id: json["id"] as int,
      name: json["name"] ?? "",
      extraPrice: double.parse(json["extra_price"].toString()),
      isAvailable: json["is_available"] ?? true,
      image: json["image"] ?? "",
      sortOrder: json["sort_order"] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "extra_price": extraPrice,
      "is_available": isAvailable,
      "image": image,
      "sort_order": sortOrder,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModifierOption &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          extraPrice == other.extraPrice;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ extraPrice.hashCode;
}

class ModifierGroup {
  final int id;
  final String name;
  final String selectionType; // 'SINGLE' or 'MULTIPLE'
  final bool required;
  final int minSelection;
  final int maxSelection;
  final int displayOrder;
  final String description;
  final List<ModifierOption> options;

  ModifierGroup({
    required this.id,
    required this.name,
    required this.selectionType,
    required this.required,
    required this.minSelection,
    required this.maxSelection,
    required this.displayOrder,
    required this.description,
    required this.options,
  });

  bool get isSingleSelect => selectionType == "SINGLE";

  factory ModifierGroup.fromJson(Map<String, dynamic> json) {
    final rawOptions = json["options"] as List? ?? [];
    return ModifierGroup(
      id: json["id"] as int,
      name: json["name"] ?? "",
      selectionType: json["selection_type"] ?? "SINGLE",
      required: json["required"] ?? false,
      minSelection: json["min_selection"] ?? 0,
      maxSelection: json["max_selection"] ?? 1,
      displayOrder: json["display_order"] ?? 0,
      description: json["description"] ?? "",
      options: rawOptions
          .map((o) => ModifierOption.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "selection_type": selectionType,
      "required": required,
      "min_selection": minSelection,
      "max_selection": maxSelection,
      "display_order": displayOrder,
      "description": description,
      "options": options.map((o) => o.toJson()).toList(),
    };
  }
}
