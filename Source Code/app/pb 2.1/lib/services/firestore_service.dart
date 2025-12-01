import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/device_model.dart';
import '../models/permission_model.dart';
import '../models/home_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final bool useMockData;

  FirestoreService({this.useMockData = false});

  static final List<DeviceModel> _mockDevices = [
    DeviceModel(
      id: 'light1',
      name: 'Đèn 1',
      topic: 'Live_room_hub/light1/control',
      type: DeviceType.relay,
      state: DeviceState.relay(isOn: false),
      allowedUsers: ['user1@test.com', 'admin@test.com'],
      lastUpdated: DateTime.now(),
    ),
    DeviceModel(
      id: 'fan1',
      name: 'Quạt 1',
      topic: 'Live_room_hub/fan1/control',
      type: DeviceType.relay,
      state: DeviceState.relay(isOn: false),
      allowedUsers: ['user1@test.com', 'admin@test.com'],
      lastUpdated: DateTime.now(),
    ),
    DeviceModel(
      id: 'light2',
      name: 'Đèn 2',
      topic: 'Live_room_hub/light2/control',
      type: DeviceType.relay,
      state: DeviceState.relay(isOn: false),
      allowedUsers: ['user2@test.com', 'admin@test.com'],
      lastUpdated: DateTime.now(),
    ),
    DeviceModel(
      id: 'fan2',
      name: 'Quạt 2',
      topic: 'Live_room_hub/fan2/control',
      type: DeviceType.relay,
      state: DeviceState.relay(isOn: false),
      allowedUsers: ['user2@test.com', 'admin@test.com'],
      lastUpdated: DateTime.now(),
    ),
    DeviceModel(
      id: 'rgb_led',
      name: 'LED RGB',
      topic: 'Live_room_hub/rgb/control',
      type: DeviceType.rgbLed,
      state: DeviceState.rgb(r: 0, g: 0, b: 0),
      allowedUsers: ['admin@test.com'],
      lastUpdated: DateTime.now(),
    ),
  ];

  static final Map<String, PermissionModel> _mockPermissions = {
    'user1': PermissionModel(
      userId: 'user1',
      devices: ['light1', 'fan1'],
      enabled: true,
    ),
    'user2': PermissionModel(
      userId: 'user2',
      devices: ['light2', 'fan2'],
      enabled: true,
    ),
    'admin': PermissionModel(
      userId: 'admin',
      devices: ['light1', 'fan1', 'light2', 'fan2', 'rgb_led'],
      enabled: true,
    ),
  };

  Future<List<DeviceModel>> getUserDevices(String email) async {
    if (useMockData) {
      return _getMockUserDevices(email);
    } else {
      return _getFirestoreUserDevices(email);
    }
  }

  Future<List<DeviceModel>> _getMockUserDevices(String email) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockDevices
        .where((device) => device.allowedUsers.contains(email))
        .toList();
  }

  Future<List<DeviceModel>> _getFirestoreUserDevices(String email) async {
    try {
      final snapshot = await _firestore
          .collection('devices')
          .where('allowedUsers', arrayContains: email)
          .get();

      return snapshot.docs
          .map((doc) => DeviceModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error getting user devices: $e');
      return [];
    }
  }

  Future<void> updateDeviceState(String deviceId, DeviceState state) async {
    if (useMockData) {
      _updateMockDeviceState(deviceId, state);
    } else {
      await _updateFirestoreDeviceState(deviceId, state);
    }
  }

  void _updateMockDeviceState(String deviceId, DeviceState state) {
    final index = _mockDevices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      _mockDevices[index] = _mockDevices[index].copyWith(
        state: state,
        lastUpdated: DateTime.now(),
      );
    }
  }

  Future<void> _updateFirestoreDeviceState(
      String deviceId, DeviceState state) async {
    try {
      final device = await getDevice(deviceId);
      if (device == null) return;

      final stateMap = device.type == DeviceType.rgbLed
          ? {
              'r': state.rgbColor!.r,
              'g': state.rgbColor!.g,
              'b': state.rgbColor!.b
            }
          : {'isOn': state.isOn};

      await _firestore.collection('devices').doc(deviceId).update({
        'state': stateMap,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating device state: $e');
    }
  }

  Future<DeviceModel?> getDevice(String deviceId) async {
    if (useMockData) {
      return _mockDevices.firstWhere((d) => d.id == deviceId);
    } else {
      try {
        final doc = await _firestore.collection('devices').doc(deviceId).get();
        if (doc.exists) {
          return DeviceModel.fromFirestore(doc.data()!, deviceId);
        }
      } catch (e) {
        debugPrint('Error getting device: $e');
      }
      return null;
    }
  }

  Future<PermissionModel?> getUserPermissions(String userId) async {
    if (useMockData) {
      return _mockPermissions[userId];
    } else {
      try {
        final doc =
            await _firestore.collection('permissions').doc(userId).get();
        if (doc.exists) {
          return PermissionModel.fromFirestore(doc.data()!, userId);
        }
      } catch (e) {
        debugPrint('Error getting permissions: $e');
      }
      return null;
    }
  }

  Future<void> updatePermission(
      PermissionModel permission, String adminId) async {
    if (useMockData) {
      _mockPermissions[permission.userId] = permission.copyWith(
        updatedBy: adminId,
        updatedAt: DateTime.now(),
      );
    } else {
      try {
        await _firestore.collection('permissions').doc(permission.userId).set(
              permission
                  .copyWith(updatedBy: adminId, updatedAt: DateTime.now())
                  .toFirestore(),
            );
      } catch (e) {
        debugPrint('Error updating permission: $e');
      }
    }
  }

  Stream<DeviceModel>? watchDevice(String deviceId) {
    if (useMockData) return null;

    return _firestore
        .collection('devices')
        .doc(deviceId)
        .snapshots()
        .map((doc) => DeviceModel.fromFirestore(doc.data()!, deviceId));
  }

  Stream<List<DeviceModel>>? watchUserDevices(String email) {
    if (useMockData) return null;

    return _firestore
        .collection('devices')
        .where('allowedUsers', arrayContains: email)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DeviceModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Future<HomeModel> createHome(String name, String ownerId) async {
    try {
      final docRef = _firestore.collection('homes').doc();
      final home = HomeModel(
        id: docRef.id,
        name: name,
        ownerId: ownerId,
        members: [ownerId],
        createdAt: DateTime.now(),
      );

      await docRef.set(home.toFirestore());
      return home;
    } catch (e) {
      debugPrint('Error creating home: $e');
      rethrow;
    }
  }

  Future<List<HomeModel>> getUserHomes(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('homes')
          .where('members', arrayContains: userId)
          .get();

      return snapshot.docs
          .map((doc) => HomeModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error getting user homes: $e');
      return [];
    }
  }

  Future<void> initializeSampleData({String? currentUserId}) async {
    if (useMockData) return;

    try {
      String? defaultHomeId;
      if (currentUserId != null) {
        final homes = await getUserHomes(currentUserId);
        if (homes.isEmpty) {
          final home = await createHome('Nhà của tôi', currentUserId);
          defaultHomeId = home.id;
          debugPrint('Đã tạo Home mặc định: ${home.id}');
        } else {
          defaultHomeId = homes.first.id;
        }
      }

      for (var device in _mockDevices) {
        final deviceToCreate = device.copyWith(
          homeId: defaultHomeId,
        );

        debugPrint('Đang tạo device: ${deviceToCreate.id}...');
        await _firestore
            .collection('devices')
            .doc(deviceToCreate.id)
            .set(deviceToCreate.toFirestore())
            .timeout(const Duration(seconds: 5), onTimeout: () {
          throw 'Timeout khi tạo device ${deviceToCreate.id}. Kiểm tra kết nối mạng!';
        });
      }
      debugPrint('Đã khởi tạo dữ liệu mẫu thành công!');
    } catch (e) {
      debugPrint('Lỗi khởi tạo dữ liệu: $e');
      rethrow;
    }
  }
}
