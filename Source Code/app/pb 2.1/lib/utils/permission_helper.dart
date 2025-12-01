import '../models/user_model.dart';
import '../models/device_model.dart';

class PermissionHelper {
  static bool canControlDevice(UserModel user, DeviceModel device) {
    if (user.isAdmin) return true;

    return device.allowedUsers.contains(user.uid);
  }

  static bool canViewDevice(UserModel user, DeviceModel device) {
    if (user.isAdmin) return true;

    return canControlDevice(user, device);
  }

  static bool canManageUsers(UserModel user) {
    return user.isAdmin;
  }

  static bool canConfigureSystem(UserModel user) {
    return user.isAdmin;
  }

  static bool canManageDevices(UserModel user) {
    return user.isAdmin;
  }

  static bool canAssignPermissions(UserModel user) {
    return user.isAdmin;
  }

  static bool canViewLogs(UserModel user) {
    return user.isAdmin;
  }

  static bool canAccessHome(UserModel user, String homeId) {
    if (user.isAdmin) return true;

    return true;
  }

  static String getPermissionLevel(UserModel user, DeviceModel device) {
    if (user.isAdmin) {
      return 'Full Access (Admin)';
    } else if (canControlDevice(user, device)) {
      return 'Can Control';
    } else {
      return 'No Access';
    }
  }

  static bool canControlSubDevice(
      UserModel user, DeviceModel parentDevice, String subDeviceId) {
    if (user.isAdmin) return true;

    if (!canControlDevice(user, parentDevice)) {
      return false;
    }
    return true;
  }

  static String getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.user1:
        return 'User 1';
      case UserRole.user2:
        return 'User 2';
      case UserRole.user:
        return 'User';
    }
  }

  static int getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 0xFFE91E63; // Pink - Admin
      case UserRole.user1:
        return 0xFF2196F3; // Blue - User1
      case UserRole.user2:
        return 0xFF4CAF50; // Green - User2
      case UserRole.user:
        return 0xFF9E9E9E; // Grey - Generic user
    }
  }
}
