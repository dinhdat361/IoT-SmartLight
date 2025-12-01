import 'package:cloud_firestore/cloud_firestore.dart';

class HomeModel {
  final String id;
  final String name;
  final String ownerId;
  final List<String> members;
  final DateTime createdAt;

  HomeModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.members,
    required this.createdAt,
  });

  factory HomeModel.fromFirestore(Map<String, dynamic> data, String id) {
    return HomeModel(
      id: id,
      name: data['name'] ?? 'My Home',
      ownerId: data['ownerId'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'ownerId': ownerId,
      'members': members,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  HomeModel copyWith({
    String? name,
    List<String>? members,
  }) {
    return HomeModel(
      id: id,
      name: name ?? this.name,
      ownerId: ownerId,
      members: members ?? this.members,
      createdAt: createdAt,
    );
  }
}
