import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackMessage {
  const FeedbackMessage({
    required this.id,
    required this.message,
    required this.senderUid,
    required this.senderName,
    required this.senderEmail,
    required this.createdAt,
    this.imageUrls = const [],
    this.resolved = false,
    this.resolvedAt,
  });

  final String id;
  final String message;
  final String senderUid;
  final String senderName;
  final String senderEmail;
  final DateTime createdAt;
  final List<String> imageUrls;
  final bool resolved;
  final DateTime? resolvedAt;

  factory FeedbackMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FeedbackMessage(
      id: doc.id,
      message: data['message'] as String? ?? '',
      senderUid: data['senderUid'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      senderEmail: data['senderEmail'] as String? ?? '',
      createdAt: _readDate(data['createdAt']),
      imageUrls: (data['imageUrls'] as List?)?.map((item) => '$item').where((item) => item.isNotEmpty).toList() ??
          const [],
      resolved: data['resolved'] as bool? ?? false,
      resolvedAt: data['resolvedAt'] == null ? null : _readDate(data['resolvedAt']),
    );
  }
}

DateTime _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}
