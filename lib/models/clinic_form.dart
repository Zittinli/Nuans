import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum FormFieldType {
  text('Kısa metin', Icons.short_text),
  multiline('Uzun metin', Icons.notes_outlined),
  number('Sayı', Icons.pin_outlined),
  date('Tarih', Icons.event_outlined),
  boolean('Evet / Hayır', Icons.toggle_on_outlined),
  singleChoice('Tek seçim', Icons.radio_button_checked),
  multiChoice('Çoklu seçim', Icons.checklist_outlined);

  const FormFieldType(this.label, this.icon);
  final String label;
  final IconData icon;

  static FormFieldType fromName(String? name) {
    return FormFieldType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => FormFieldType.text,
    );
  }

  bool get hasOptions =>
      this == FormFieldType.singleChoice || this == FormFieldType.multiChoice;
}

class ClinicFormField {
  const ClinicFormField({
    required this.id,
    required this.label,
    required this.type,
    this.required = false,
    this.options = const [],
  });

  final String id;
  final String label;
  final FormFieldType type;
  final bool required;
  final List<String> options;

  factory ClinicFormField.fromMap(Map<String, dynamic> data) {
    return ClinicFormField(
      id: data['id'] as String? ?? '',
      label: data['label'] as String? ?? '',
      type: FormFieldType.fromName(data['type'] as String?),
      required: data['required'] as bool? ?? false,
      options: (data['options'] as List?)?.map((item) => '$item').toList() ?? const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'type': type.name,
      'required': required,
      'options': options,
    };
  }

  ClinicFormField copyWith({
    String? label,
    FormFieldType? type,
    bool? required,
    List<String>? options,
  }) {
    return ClinicFormField(
      id: id,
      label: label ?? this.label,
      type: type ?? this.type,
      required: required ?? this.required,
      options: options ?? this.options,
    );
  }
}

enum FormSourceKind {
  pdf('PDF'),
  word('Word');

  const FormSourceKind(this.label);
  final String label;

  static FormSourceKind? fromName(String? name) {
    if (name == null || name.isEmpty) return null;
    return FormSourceKind.values.firstWhere(
      (item) => item.name == name,
      orElse: () => FormSourceKind.pdf,
    );
  }
}

class ClinicFormTemplate {
  const ClinicFormTemplate({
    required this.id,
    required this.name,
    this.description,
    required this.fields,
    this.active = true,
    this.sourceFileUrl,
    this.sourceFileName,
    this.sourceFileKind,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final List<ClinicFormField> fields;
  final bool active;
  final String? sourceFileUrl;
  final String? sourceFileName;
  final FormSourceKind? sourceFileKind;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasSourceFile => sourceFileUrl != null && sourceFileUrl!.isNotEmpty;

  factory ClinicFormTemplate.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ClinicFormTemplate(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      fields: (data['fields'] as List? ?? [])
          .whereType<Map>()
          .map((item) => ClinicFormField.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      active: data['active'] as bool? ?? true,
      sourceFileUrl: data['sourceFileUrl'] as String?,
      sourceFileName: data['sourceFileName'] as String?,
      sourceFileKind: FormSourceKind.fromName(data['sourceFileKind'] as String?),
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'fields': fields.map((field) => field.toMap()).toList(),
      'active': active,
      'sourceFileUrl': sourceFileUrl,
      'sourceFileName': sourceFileName,
      'sourceFileKind': sourceFileKind?.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ClinicFormTemplate copyWith({
    String? name,
    String? description,
    List<ClinicFormField>? fields,
    bool? active,
    String? sourceFileUrl,
    String? sourceFileName,
    FormSourceKind? sourceFileKind,
    DateTime? updatedAt,
  }) {
    return ClinicFormTemplate(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      fields: fields ?? this.fields,
      active: active ?? this.active,
      sourceFileUrl: sourceFileUrl ?? this.sourceFileUrl,
      sourceFileName: sourceFileName ?? this.sourceFileName,
      sourceFileKind: sourceFileKind ?? this.sourceFileKind,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum PatientFormSource {
  filled('Dijital form'),
  scanned('Taranmış form');

  const PatientFormSource(this.label);
  final String label;

  static PatientFormSource fromName(String? name) {
    return PatientFormSource.values.firstWhere(
      (item) => item.name == name,
      orElse: () => PatientFormSource.filled,
    );
  }
}

class PatientFormEntry {
  const PatientFormEntry({
    required this.id,
    this.templateId,
    required this.title,
    required this.source,
    required this.values,
    this.scanUrls = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? templateId;
  final String title;
  final PatientFormSource source;
  final Map<String, dynamic> values;
  final List<String> scanUrls;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PatientFormEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PatientFormEntry(
      id: doc.id,
      templateId: data['templateId'] as String?,
      title: data['title'] as String? ?? 'Form',
      source: PatientFormSource.fromName(data['source'] as String?),
      values: Map<String, dynamic>.from(data['values'] as Map? ?? {}),
      scanUrls: (data['scanUrls'] as List?)?.map((item) => '$item').toList() ?? const [],
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'templateId': templateId,
      'title': title,
      'source': source.name,
      'values': values,
      'scanUrls': scanUrls,
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
