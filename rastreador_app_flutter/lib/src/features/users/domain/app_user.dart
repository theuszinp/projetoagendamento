import 'user_role.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isApproved = true,
  });

  final int id;
  final String name;
  final String email;
  final UserRole role;
  final bool isApproved;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: _parseInt(json['id']),
      name: (json['name'] ?? 'Usuário').toString(),
      email: (json['email'] ?? '').toString(),
      role: UserRole.fromApi((json['role'] ?? '').toString()),
      isApproved: (json['approved'] ?? true) == true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'email': email,
      'role': role.apiValue,
      'approved': isApproved,
    };
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString()) ?? 0;
  }
}
