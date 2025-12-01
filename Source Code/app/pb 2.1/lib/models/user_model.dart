class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${data['role']}',
        orElse: () => UserRole.user,
      ),
      createdAt: (data['createdAt'] as dynamic).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role.toString().split('.').last,
      'createdAt': createdAt,
    };
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isUser1 => role == UserRole.user1;
  bool get isUser2 => role == UserRole.user2;
}

enum UserRole {
  user1,
  user2,
  admin,
  user,
}
