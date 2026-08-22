import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum NoteType {
  examination('Muayene', Icons.health_and_safety_outlined),
  followUp('Kontrol', Icons.event_repeat_outlined),
  lab('Laboratuvar', Icons.biotech_outlined),
  prescription('Reçete', Icons.medication_outlined),
  other('Diğer', Icons.notes_outlined);

  const NoteType(this.label, this.icon);
  final String label;
  final IconData icon;

  static NoteType fromName(String? name) {
    return NoteType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => NoteType.other,
    );
  }
}

class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final NoteType type;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Note.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Note(
      id: doc.id,
      title: data['title'] as String? ?? '',
      content: data['content'] as String? ?? '',
      type: NoteType.fromName(data['type'] as String?),
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'type': type.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

DateTime _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}
