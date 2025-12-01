class PermissionModel {
  final String userId;
  final List<String> devices;
  final bool enabled;
  final String? updatedBy;
  final DateTime? updatedAt;

  PermissionModel({
    required this.userId,
    required this.devices,
    required this.enabled,
    this.updatedBy,
    this.updatedAt,
  });

  factory PermissionModel.fromFirestore(
      Map<String, dynamic> data, String userId) {
    return PermissionModel(
      userId: userId,
      devices: List<String>.from(data['devices'] ?? []),
      enabled: data['enabled'] ?? true,
      updatedBy: data['updatedBy'],
      updatedAt: (data['updatedAt'] as dynamic).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'devices': devices,
      'enabled': enabled,
      'updatedBy': updatedBy,
      'updatedAt': updatedAt ?? DateTime.now(),
    };
  }

  bool hasAccessTo(String deviceId) {
    return enabled && devices.contains(deviceId);
  }

  PermissionModel copyWith({
    String? userId,
    List<String>? devices,
    bool? enabled,
    String? updatedBy,
    DateTime? updatedAt,
  }) {
    return PermissionModel(
      userId: userId ?? this.userId,
      devices: devices ?? this.devices,
      enabled: enabled ?? this.enabled,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
