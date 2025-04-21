class UserModel {
  final String id;
  final String email;
  final String userType; // 'patient' or 'clinician'
  final String name;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.userType,
    required this.name,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      userType: json['userType'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'userType': userType,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}