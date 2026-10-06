import 'package:cloud_firestore/cloud_firestore.dart';

/// Varsayılan kategori kodları (ilk kurulum).
const kDefaultFormCategoryCodes = ['Anamnez', 'AKB', 'DDY', 'DiL', 'EDB', 'KSB', 'MKB'];

class FormCategory {
  const FormCategory({
    required this.id,
    required this.name,
    this.description,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FormCategory.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FormCategory(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      description: data['description'] as String?,
      sortOrder: data['sortOrder'] as int? ?? 0,
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'sortOrder': sortOrder,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  FormCategory copyWith({
    String? name,
    String? description,
    int? sortOrder,
    DateTime? updatedAt,
  }) {
    return FormCategory(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
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
