import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final Map<String, Map<String, dynamic>> _mockUsers = {
    'user1@test.com': {
      'password': 'password123',
      'uid': 'user1',
      'displayName': 'User 1',
      'role': 'user',
    },
    'user2@test.com': {
      'password': 'password123',
      'uid': 'user2',
      'displayName': 'User 2',
      'role': 'user',
    },
    'admin@test.com': {
      'password': 'admin123',
      'uid': 'admin',
      'displayName': 'Admin',
      'role': 'admin',
    },
  };

  final bool useMockAuth;

  AuthService({this.useMockAuth = false});

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserModel?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (useMockAuth) {
      return _mockSignIn(email, password);
    } else {
      try {
        final credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (credential.user != null) {
          var userData = await getUserData(credential.user!.uid);

          if (userData == null) {
            final role = _getRoleFromEmail(email);
            userData = UserModel(
              uid: credential.user!.uid,
              email: email,
              displayName: credential.user!.displayName ?? email.split('@')[0],
              role: role,
              createdAt: DateTime.now(),
            );

            // Lưu vào Firestore
            await _firestore
                .collection('users')
                .doc(userData.uid)
                .set(userData.toFirestore());
          }

          return userData;
        }
      } on FirebaseAuthException catch (e) {
        throw _handleAuthException(e);
      }
    }
    return null;
  }

  /// Xác định role
  UserRole _getRoleFromEmail(String email) {
    final lowerEmail = email.toLowerCase();

    if (lowerEmail.contains('admin')) {
      return UserRole.admin;
    }

    if (lowerEmail.contains('user1')) {
      return UserRole.user1;
    }

    return UserRole.user2;
  }

  Future<UserModel?> _mockSignIn(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final mockUser = _mockUsers[email];
    if (mockUser == null || mockUser['password'] != password) {
      throw 'Email hoặc mật khẩu không đúng';
    }

    return UserModel(
      uid: mockUser['uid'],
      email: email,
      displayName: mockUser['displayName'],
      role: mockUser['role'] == 'admin' ? UserRole.admin : UserRole.user,
      createdAt: DateTime.now(),
    );
  }

  /// Logout
  Future<void> signOut() async {
    if (!useMockAuth) {
      await _auth.signOut();
    }
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc.data()!, uid);
      }
    } catch (e) {
      debugPrint('Error getting user data: $e');
    }
    return null;
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Email không tồn tại';
      case 'wrong-password':
        return 'Mật khẩu không đúng';
      case 'invalid-email':
        return 'Email không hợp lệ';
      case 'user-disabled':
        return 'Tài khoản đã bị vô hiệu hóa';
      default:
        return 'Lỗi đăng nhập: ${e.message}';
    }
  }

  Future<UserModel?> createUser({
    required String email,
    required String password,
    required String displayName,
    UserRole role = UserRole.user,
  }) async {
    if (useMockAuth) {
      throw 'Không thể tạo user trong Mock mode';
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final user = UserModel(
          uid: credential.user!.uid,
          email: email,
          displayName: displayName,
          role: role,
          createdAt: DateTime.now(),
        );

        // Lưu vào Firestore
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(user.toFirestore());

        return user;
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
    return null;
  }
}
