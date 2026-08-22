import 'package:cloud_firestore/cloud_firestore.dart';

class Patient {
  const Patient({
    required this.id,
    required this.fullName,
    this.identityNumber,
    this.birthDate,
    required this.gender,
    this.phone,
    this.diagnosis,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String fullName;
  final String? identityNumber;
  final DateTime? birthDate;
  final String gender;
  final String? phone;
  final String? diagnosis;
  final DateTime createdAt;
  final DateTime updatedAt;

  int? get age {
    final date = birthDate;
    if (date == null) return null;
    final now = DateTime.now();
    var years = now.year - date.year;
    if (now.month < date.month ||
        (now.month == date.month && now.day < date.day)) {
      years--;
    }
    return years;
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory Patient.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Patient(
      id: doc.id,
      fullName: data['fullName'] as String? ?? '',
      identityNumber: data['identityNumber'] as String?,
      birthDate: _readNullableDate(data['birthDate']),
      gender: data['gender'] as String? ?? 'Belirtilmedi',
      phone: data['phone'] as String?,
      diagnosis: data['diagnosis'] as String?,
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'identityNumber': identityNumber,
      'birthDate': birthDate == null ? null : Timestamp.fromDate(birthDate!),
      'gender': gender,
      'phone': phone,
      'diagnosis': diagnosis,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Patient copyWith({
    String? fullName,
    String? identityNumber,
    DateTime? birthDate,
    String? gender,
    String? phone,
    String? diagnosis,
    DateTime? updatedAt,
  }) {
    return Patient(
      id: id,
      fullName: fullName ?? this.fullName,
      identityNumber: identityNumber ?? this.identityNumber,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      diagnosis: diagnosis ?? this.diagnosis,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

DateTime _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}

DateTime? _readNullableDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
