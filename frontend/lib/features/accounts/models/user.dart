class User {
  final int id;
  final String phoneNumber;
  final String name;
  final String role;
  final int loyaltyCoins;

  User({
    required this.id,
    required this.phoneNumber,
    required this.name,
    required this.role,
    this.loyaltyCoins = 0,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      phoneNumber: json['phone_number'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'customer',
      loyaltyCoins: json['loyalty_coins'] ?? 0,
    );
  }
}
