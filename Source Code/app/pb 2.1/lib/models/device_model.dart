enum DeviceType {
  relay,
  rgbLed,
}

class DeviceModel {
  final String id;
  final String name;
  final String topic;
  final DeviceType type;
  final DeviceState state;
  final String? homeId;
  @Deprecated(
      'Use home-based permissions instead. This field will be removed in a future version.')
  final List<String> allowedUsers;
  final DateTime lastUpdated;

  DeviceModel({
    required this.id,
    required this.name,
    required this.topic,
    required this.type,
    required this.state,
    this.homeId,
    required this.allowedUsers,
    required this.lastUpdated,
  });

  factory DeviceModel.fromFirestore(Map<String, dynamic> data, String id) {
    final typeStr = data['type'] ?? 'relay';
    final type = typeStr == 'rgbLed' ? DeviceType.rgbLed : DeviceType.relay;

    final stateData = data['state'] as Map<String, dynamic>? ?? {};
    final state = type == DeviceType.rgbLed
        ? DeviceState.rgb(
            r: stateData['r'] ?? 0,
            g: stateData['g'] ?? 0,
            b: stateData['b'] ?? 0,
          )
        : DeviceState.relay(isOn: stateData['isOn'] ?? false);

    return DeviceModel(
      id: id,
      name: data['name'] ?? '',
      topic: data['topic'] ?? '',
      type: type,
      state: state,
      homeId: data['homeId'],
      allowedUsers: List<String>.from(data['allowedUsers'] ?? []),
      lastUpdated: (data['lastUpdated'] as dynamic).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    final stateMap = type == DeviceType.rgbLed
        ? {
            'r': state.rgbColor!.r,
            'g': state.rgbColor!.g,
            'b': state.rgbColor!.b
          }
        : {'isOn': state.isOn};

    return {
      'name': name,
      'topic': topic,
      'type': type == DeviceType.rgbLed ? 'rgbLed' : 'relay',
      'state': stateMap,
      'homeId': homeId,
      'allowedUsers': allowedUsers,
      'lastUpdated': lastUpdated,
    };
  }

  DeviceModel copyWith({
    String? id,
    String? name,
    String? topic,
    DeviceType? type,
    DeviceState? state,
    String? homeId,
    List<String>? allowedUsers,
    DateTime? lastUpdated,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      topic: topic ?? this.topic,
      type: type ?? this.type,
      state: state ?? this.state,
      homeId: homeId ?? this.homeId,
      allowedUsers: allowedUsers ?? this.allowedUsers,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  bool canUserControl(String userId) {
    return allowedUsers.contains(userId);
  }
}

class DeviceState {
  final bool isOn;
  final RGBColor? rgbColor;

  DeviceState._({
    required this.isOn,
    this.rgbColor,
  });

  factory DeviceState.relay({required bool isOn}) {
    return DeviceState._(isOn: isOn);
  }

  factory DeviceState.rgb({required int r, required int g, required int b}) {
    final isOn = r > 0 || g > 0 || b > 0;
    return DeviceState._(
      isOn: isOn,
      rgbColor: RGBColor(r: r, g: g, b: b),
    );
  }

  DeviceState copyWith({bool? isOn, RGBColor? rgbColor}) {
    return DeviceState._(
      isOn: isOn ?? this.isOn,
      rgbColor: rgbColor ?? this.rgbColor,
    );
  }
}

class RGBColor {
  final int r;
  final int g;
  final int b;

  RGBColor({
    required this.r,
    required this.g,
    required this.b,
  });

  RGBColor copyWith({int? r, int? g, int? b}) {
    return RGBColor(
      r: r ?? this.r,
      g: g ?? this.g,
      b: b ?? this.b,
    );
  }

  Map<String, dynamic> toJson() {
    return {'r': r, 'g': g, 'b': b};
  }

  @override
  String toString() => 'RGB($r, $g, $b)';
}
