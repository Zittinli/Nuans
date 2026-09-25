import 'package:cloud_firestore/cloud_firestore.dart';

class Appointment {
  const Appointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.startsAt,
    required this.endsAt,
    required this.title,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String patientId;
  final String patientName;
  final DateTime startsAt;
  final DateTime endsAt;
  final String title;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPast => endsAt.isBefore(DateTime.now());

  factory Appointment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final startsAt = _readDate(data['startsAt']);
    return Appointment(
      id: doc.id,
      patientId: data['patientId'] as String? ?? '',
      patientName: data['patientName'] as String? ?? '',
      startsAt: startsAt,
      endsAt: _readDate(data['endsAt'], fallback: startsAt.add(const Duration(minutes: 30))),
      title: data['title'] as String? ?? 'Görüşme',
      notes: data['notes'] as String?,
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'startsAt': Timestamp.fromDate(startsAt),
      'endsAt': Timestamp.fromDate(endsAt),
      'title': title,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

DateTime _readDate(dynamic value, {DateTime? fallback}) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return fallback ?? DateTime.now();
}
