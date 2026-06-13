class User {
  final int id;
  final String phoneNumber;
  final String name;
  final String role;

  User({
    required this.id,
    required this.phoneNumber,
    required this.name,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      phoneNumber: json['phone_number'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'customer',
    );
  }
}
