import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class FirebaseRealtimeService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  /// Watch device state changes in realtime
  Stream<Map<String, dynamic>> watchDeviceState(String deviceId) {
    final ref = _database.ref('devices/$deviceId/state');

    return ref.onValue.asyncMap((event) async {
      final data = event.snapshot.value;

      if (data == null) {
        return <String, dynamic>{};
      }

      // Convert to Map
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }

      return <String, dynamic>{};
    });
  }

  /// Update device state (for control)
  Future<void> updateDeviceState(
      String deviceId, String subDeviceId, Map<String, dynamic> state) async {
    try {
      final ref = _database.ref('devices/$deviceId/state/$subDeviceId');

      // Add timestamp
      final data = {
        ...state,
        'updatedAt': ServerValue.timestamp,
      };

      await ref.update(data);
      debugPrint('Updated $deviceId/$subDeviceId state: $data');
    } catch (e) {
      debugPrint('Error updating device state: $e');
      rethrow;
    }
  }

  /// Update RGB LED color
  Future<void> updateRGBColor(String deviceId, int r, int g, int b) async {
    await updateDeviceState(deviceId, 'rgb', {
      'r': r,
      'g': g,
      'b': b,
    });
  }

  /// Update relay state (on/off)
  Future<void> updateRelayState(
      String deviceId,
      String relayId, // "light1", "fan1", etc.
      bool isOn) async {
    await updateDeviceState(deviceId, relayId, {
      'isOn': isOn,
    });
  }

  /// Watch device online status
  Stream<bool> watchDeviceOnline(String deviceId) {
    final ref = _database.ref('devices/$deviceId/metadata/online');

    return ref.onValue.map((event) {
      final value = event.snapshot.value;
      return value == true;
    });
  }

  /// Watch device last seen timestamp
  Stream<DateTime?> watchDeviceLastSeen(String deviceId) {
    final ref = _database.ref('devices/$deviceId/metadata/lastSeen');

    return ref.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return null;
    });
  }

  /// Get device configuration
  Future<Map<String, dynamic>?> getDeviceConfig(String deviceId) async {
    try {
      final snapshot = await _database.ref('devices/$deviceId/config').get();

      if (snapshot.exists) {
        final data = snapshot.value;
        if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
      }
    } catch (e) {
      debugPrint('Error getting device config: $e');
    }
    return null;
  }

  /// Update device configuration (admin only)
  Future<void> updateDeviceConfig(
      String deviceId, Map<String, dynamic> config) async {
    try {
      final ref = _database.ref('devices/$deviceId/config');

      final data = {
        ...config,
        'lastConfigUpdate': ServerValue.timestamp,
      };

      await ref.update(data);
      debugPrint('Updated device config for $deviceId');
    } catch (e) {
      debugPrint('Error updating device config: $e');
      rethrow;
    }
  }

  /// Initialize device in Firebase RTDB
  Future<void> initializeDevice(String deviceId, String deviceType,
      String homeId, List<String> allowedUsers) async {
    try {
      final ref = _database.ref('devices/$deviceId');

      await ref.set({
        'metadata': {
          'deviceId': deviceId,
          'deviceType': deviceType,
          'homeId': homeId,
          'allowedUsers': allowedUsers,
          'createdAt': ServerValue.timestamp,
          'lastSeen': ServerValue.timestamp,
          'online': false,
        },
        'state': {},
        'config': {
          'backend': 'firebase',
        },
      });

      debugPrint('Initialized device $deviceId in Firebase RTDB');
    } catch (e) {
      debugPrint('Error initializing device: $e');
      rethrow;
    }
  }

  /// Stream all user's devices from RTDB
  Stream<List<String>> watchUserDevices(String userId) {
    // Query devices where user is in allowedUsers
    final ref = _database.ref('devices');

    return ref.onValue.asyncMap((event) async {
      final data = event.snapshot.value;
      if (data == null) return <String>[];

      if (data is! Map) return <String>[];

      final devices = <String>[];

      for (var entry in data.entries) {
        final deviceId = entry.key;
        final deviceData = entry.value;

        if (deviceData is Map) {
          final metadata = deviceData['metadata'];
          if (metadata is Map) {
            final allowedUsers = metadata['allowedUsers'];
            if (allowedUsers is List && allowedUsers.contains(userId)) {
              devices.add(deviceId.toString());
            }
          }
        }
      }

      return devices;
    });
  }

  /// Setup device presence tracking
  /// Call this when ESP32 connects to update online status
  Future<void> setupDevicePresence(String deviceId) async {
    try {
      final ref = _database.ref('devices/$deviceId/metadata');

      // Set online status
      await ref.update({
        'online': true,
        'lastSeen': ServerValue.timestamp,
      });

      // Setup disconnect handler
      final onDisconnectRef = _database.ref('devices/$deviceId/metadata');
      await onDisconnectRef.onDisconnect().update({
        'online': false,
        'lastSeen': ServerValue.timestamp,
      });

      debugPrint('Device presence configured for $deviceId');
    } catch (e) {
      debugPrint('Error setting up device presence: $e');
    }
  }
}
