import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/doctor.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  CollectionReference<Map<String, dynamic>> get _doctors =>
      _db.collection('doctors');

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(mapAuthError(error));
    }
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw AuthFailure('Kayıt tamamlanamadı. Lütfen tekrar deneyin.');
      }
      await user.updateDisplayName(fullName.trim());
      final doctor = Doctor(
        id: user.uid,
        fullName: fullName.trim(),
        email: email.trim(),
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

  Future<void> signOut() => _auth.signOut();

  Stream<Doctor?> watchProfile() {
    final uid = currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _doctors.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Doctor.fromDoc(doc);
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
    case 'too-many-requests':
      return 'Çok fazla deneme yapıldı. Lütfen sonra tekrar deneyin.';
    case 'network-request-failed':
      return 'İnternet bağlantısı yok.';
    default:
      return 'Bir hata oluştu. Lütfen tekrar deneyin.';
  }
}
