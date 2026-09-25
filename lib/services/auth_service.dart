import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/admin_config.dart';
import '../models/doctor.dart';
import '../utils/disposable_email.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.userChanges();

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  CollectionReference<Map<String, dynamic>> get _doctors =>
      _db.collection('doctors');

  Future<void> signIn({required String email, required String password}) async {
    final trimmedEmail = email.trim();
    if (isDisposableEmail(trimmedEmail)) {
      throw AuthFailure(
        'Tek kullanımlık e-posta adresleriyle giriş yapılamaz.',
      );
    }
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );
      await credential.user?.reload();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(mapAuthError(error));
    }
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    if (isDisposableEmail(trimmedEmail)) {
      throw AuthFailure(
        'Tek kullanımlık e-posta adresleriyle kayıt olunamaz. Lütfen kalıcı bir e-posta kullanın.',
      );
    }
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw AuthFailure('Kayıt tamamlanamadı. Lütfen tekrar deneyin.');
      }
      await user.updateDisplayName(fullName.trim());
      await user.sendEmailVerification();
      final doctor = Doctor(
        id: user.uid,
        fullName: fullName.trim(),
        email: trimmedEmail,
        createdAt: DateTime.now(),
      );
      await _doctors.doc(user.uid).set(doctor.toMap());
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(mapAuthError(error));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(mapAuthError(error));
    }
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthFailure('Oturum açık değil.');
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(mapAuthError(error));
    }
  }

  Future<bool> reloadAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw AuthFailure('Oturum açık değil.');
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(mapAuthError(error));
    }
  }

  Future<void> signOut() => _auth.signOut();

  Stream<Doctor?> watchProfile() {
    final uid = currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _doctors.doc(uid).snapshots().map((doc) {
      if (doc.exists) return Doctor.fromDoc(doc);
      final user = _auth.currentUser;
      if (isSuperAdminEmail(user?.email)) {
        return Doctor(
          id: uid,
          fullName: user?.displayName ?? 'Yönetici',
          email: user?.email ?? kSuperAdminEmail,
          createdAt: DateTime.now(),
        );
      }
      return null;
    });
  }
}

class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

String mapAuthError(FirebaseAuthException error) {
  switch (error.code) {
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'E-posta veya şifre hatalı.';
    case 'email-already-in-use':
      return 'Bu e-posta adresi zaten kayıtlı.';
    case 'weak-password':
      return 'Şifre en az 6 karakter olmalı.';
    case 'invalid-email':
      return 'Geçerli bir e-posta adresi girin.';
    case 'requires-recent-login':
      return 'Şifre değiştirmek için mevcut şifrenizi tekrar girin.';
    case 'too-many-requests':
      return 'Çok fazla deneme yapıldı. Lütfen sonra tekrar deneyin.';
    case 'network-request-failed':
      return 'İnternet bağlantısı yok.';
    default:
      return 'Bir hata oluştu. Lütfen tekrar deneyin.';
  }
}
