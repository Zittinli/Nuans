import 'package:cloud_firestore/cloud_firestore.dart';

class Doctor {
  const Doctor({
    required this.id,
    required this.fullName,
    required this.email,
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final String email;
  final DateTime createdAt;

  factory Doctor.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Doctor(
      id: doc.id,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      createdAt: _readDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

DateTime _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}
