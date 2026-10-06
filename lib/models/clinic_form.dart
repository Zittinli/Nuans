import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum FormFieldType {
  text('Kısa metin', Icons.short_text),
  multiline('Uzun metin', Icons.notes_outlined),
  number('Sayı', Icons.pin_outlined),
  date('Tarih', Icons.event_outlined),
  boolean('Evet / Hayır', Icons.toggle_on_outlined),
  singleChoice('Tek seçim', Icons.radio_button_checked),
  multiChoice('Çoklu seçim', Icons.checklist_outlined),
  rating('Puan 1–5', Icons.star_rate_outlined),
  table('Tablo', Icons.table_chart_outlined),
  section('Bölüm açılışı', Icons.web_asset_outlined),
  sectionEnd('Bölüm kapanışı', Icons.vertical_align_bottom);

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

  bool get isTable => this == FormFieldType.table;

  bool get isSection => this == FormFieldType.section;

  bool get isSectionEnd => this == FormFieldType.sectionEnd;

  bool get isInput => !isSection && !isSectionEnd;

  static const columnTypes = <FormFieldType>[
    FormFieldType.text,
    FormFieldType.number,
    FormFieldType.date,
    FormFieldType.boolean,
  ];

  static const extraChoices = <FormFieldType>[
    FormFieldType.text,
    FormFieldType.multiline,
    FormFieldType.number,
    FormFieldType.date,
    FormFieldType.boolean,
    FormFieldType.rating,
  ];
}

class FormFieldOption {
  const FormFieldOption({
    required this.id,
    required this.label,
    this.extraType,
    this.isOther = false,
  });

  final String id;
  final String label;
  final FormFieldType? extraType;
  final bool isOther;

  bool get hasExtra => extraType != null || isOther;

  FormFieldType get resolvedExtraType => extraType ?? FormFieldType.text;

  factory FormFieldOption.fromRaw(dynamic raw, int index) {
    if (raw is Map) {
      final data = Map<String, dynamic>.from(raw);
      final extraName = data['extraType'] as String?;
      return FormFieldOption(
        id: data['id'] as String? ?? 'opt_$index',
        label: data['label'] as String? ?? '',
        extraType: extraName == null || extraName.isEmpty
            ? null
            : FormFieldType.extraChoices.contains(FormFieldType.fromName(extraName))
                ? FormFieldType.fromName(extraName)
                : FormFieldType.text,
        isOther: data['isOther'] as bool? ?? false,
      );
    }
    return FormFieldOption(id: 'opt_$index', label: '$raw');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'extraType': extraType?.name,
      'isOther': isOther,
    };
  }

  FormFieldOption copyWith({
    String? label,
    FormFieldType? extraType,
    bool? isOther,
    bool clearExtra = false,
  }) {
    return FormFieldOption(
      id: id,
      label: label ?? this.label,
      extraType: clearExtra ? extraType : (extraType ?? this.extraType),
      isOther: isOther ?? this.isOther,
    );
  }
}

class FormSectionBlock {
  const FormSectionBlock({this.header, required this.fields});

  final ClinicFormField? header;
  final List<ClinicFormField> fields;
}

List<FormSectionBlock> splitFormSections(List<ClinicFormField> fields) {
  final blocks = <FormSectionBlock>[];
  ClinicFormField? header;
  var body = <ClinicFormField>[];

  void flush() {
    if (header == null && body.isEmpty) return;
    blocks.add(FormSectionBlock(header: header, fields: body));
    body = <ClinicFormField>[];
  }

  for (final field in fields) {
    if (field.type.isSection) {
      flush();
      header = field;
    } else if (field.type.isSectionEnd) {
      flush();
      header = null;
    } else {
      body.add(field);
    }
  }
  flush();
  return blocks;
}

class ChoiceAnswer {
  static List<String> selectedIds(dynamic raw, List<FormFieldOption> options) {
    if (raw is Map) {
      final selected = raw['selected'];
      if (selected is List) return selected.map((item) => '$item').toList();
      if (selected is String && selected.isNotEmpty) return [selected];
    }
    if (raw is List) {
      return raw.map((item) => idForLabel(options, '$item')).toList();
    }
    if (raw is String && raw.isNotEmpty) {
      return [idForLabel(options, raw)];
    }
    return const [];
  }

  static String idForLabel(List<FormFieldOption> options, String value) {
    final byId = options.where((item) => item.id == value);
    if (byId.isNotEmpty) return byId.first.id;
    final byLabel = options.where((item) => item.label == value);
    if (byLabel.isNotEmpty) return byLabel.first.id;
    return value;
  }

  static dynamic extra(dynamic raw, String optionId) {
    if (raw is Map) {
      final extras = raw['extras'];
      if (extras is Map) return extras[optionId];
    }
    return null;
  }

  static Map<String, dynamic> extrasMap(dynamic raw) {
    if (raw is Map) {
      final extras = raw['extras'];
      if (extras is Map) return Map<String, dynamic>.from(extras);
    }
    return <String, dynamic>{};
  }

  static Map<String, dynamic> encode({
    required List<String> selected,
    required Map<String, dynamic> extras,
  }) {
    return {
      'selected': selected,
      'extras': extras,
    };
  }

  static List<FormFieldOption> selectedOptions(ClinicFormField field, dynamic raw) {
    final ids = selectedIds(raw, field.options);
    return field.options.where((item) => ids.contains(item.id)).toList();
  }
}

class TableAnswer {
  static const rowIdKey = '_row';

  static List<Map<String, String>> rows(dynamic raw) {
    final source = raw is Map ? raw['rows'] : raw;
    if (source is! List) return const [];
    final result = <Map<String, String>>[];
    for (var i = 0; i < source.length; i++) {
      final item = source[i];
      if (item is! Map) continue;
      final row = <String, String>{};
      item.forEach((key, value) {
        row['$key'] = value == null ? '' : '$value';
      });
      row.putIfAbsent(rowIdKey, () => 'row_$i');
      result.add(row);
    }
    return result;
  }

  static Map<String, dynamic> encode(List<Map<String, String>> rows) => {'rows': rows};

  static Map<String, String> blankRow(List<FormFieldOption> columns) {
    return {
      rowIdKey: 'row_${DateTime.now().microsecondsSinceEpoch}',
      for (final column in columns) column.id: '',
    };
  }

  static bool rowHasContent(Map<String, String> row) {
    return row.entries.any(
      (item) => item.key != rowIdKey && item.value.trim().isNotEmpty && item.value != 'false',
    );
  }

  static String cellText(FormFieldOption column, String? raw) {
    final type = column.extraType ?? FormFieldType.text;
    if (type == FormFieldType.boolean) {
      if (raw == 'true') return 'Evet';
      if (raw == 'false') return 'Hayır';
      return '—';
    }
    if (raw == null || raw.trim().isEmpty) return '—';
    return raw;
  }
}

String formatFormFieldValue(ClinicFormField field, dynamic value) {
  if (field.type.isSection || field.type.isSectionEnd) return '';
  if (field.type.isTable) {
    final filled = TableAnswer.rows(value).where(TableAnswer.rowHasContent).toList();
    if (filled.isEmpty) return '—';
    return filled
        .map(
          (row) => field.options
              .map((column) => '${column.label}: ${TableAnswer.cellText(column, row[column.id])}')
              .join(', '),
        )
        .join('\n');
  }
  if (field.type.hasOptions) {
    final selected = ChoiceAnswer.selectedOptions(field, value);
    if (selected.isEmpty) {
      if (value == null || '$value'.trim().isEmpty) return '—';
      if (value is List) return value.map((item) => '$item').join(', ');
      if (value is Map) return '—';
      return '$value';
    }
    return selected.map((option) {
      final extra = ChoiceAnswer.extra(value, option.id);
      if (!option.hasExtra || extra == null || '$extra'.trim().isEmpty) {
        return option.label;
      }
      return '${option.label}: ${_formatSimple(option.resolvedExtraType, extra)}';
    }).join(', ');
  }
  return _formatSimple(field.type, value);
}

String _formatSimple(FormFieldType type, dynamic value) {
  if (value == null || '$value'.trim().isEmpty) return '—';
  if (type == FormFieldType.boolean) {
    return value == true || value == 'true' ? 'Evet' : 'Hayır';
  }
  if (type == FormFieldType.rating) return '$value / 5';
  if (value is List) return value.map((item) => '$item').join(', ');
  return '$value';
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
  final List<FormFieldOption> options;

  factory ClinicFormField.fromMap(Map<String, dynamic> data) {
    final rawOptions = data['options'] as List? ?? const [];
    return ClinicFormField(
      id: data['id'] as String? ?? '',
      label: data['label'] as String? ?? '',
      type: FormFieldType.fromName(data['type'] as String?),
      required: data['required'] as bool? ?? false,
      options: [
        for (var i = 0; i < rawOptions.length; i++) FormFieldOption.fromRaw(rawOptions[i], i),
      ],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'type': type.name,
      'required': required,
      'options': options.map((item) => item.toMap()).toList(),
    };
  }

  ClinicFormField copyWith({
    String? label,
    FormFieldType? type,
    bool? required,
    List<FormFieldOption>? options,
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
    this.categoryId,
    this.active = true,
    this.sourceFileUrl,
    this.sourceFileName,
    this.sourceFileKind,
    this.isGlobal = false,
    this.createdByUid,
    this.createdByEmail,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final String? categoryId;
  final List<ClinicFormField> fields;
  final bool active;
  final String? sourceFileUrl;
  final String? sourceFileName;
  final FormSourceKind? sourceFileKind;
  final bool isGlobal;
  final String? createdByUid;
  final String? createdByEmail;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasSourceFile => sourceFileUrl != null && sourceFileUrl!.isNotEmpty;

  bool get hasCategory => categoryId != null && categoryId!.isNotEmpty;

  String get listKey => isGlobal ? 'global:$id' : 'personal:$id';

  factory ClinicFormTemplate.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    bool isGlobal = false,
  }) {
    final data = doc.data() ?? {};
    return ClinicFormTemplate(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      categoryId: data['categoryId'] as String?,
      fields: (data['fields'] as List? ?? [])
          .whereType<Map>()
          .map((item) => ClinicFormField.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      active: data['active'] as bool? ?? true,
      sourceFileUrl: data['sourceFileUrl'] as String?,
      sourceFileName: data['sourceFileName'] as String?,
      sourceFileKind: FormSourceKind.fromName(data['sourceFileKind'] as String?),
      isGlobal: isGlobal || (data['isGlobal'] as bool? ?? false),
      createdByUid: data['createdByUid'] as String?,
      createdByEmail: data['createdByEmail'] as String?,
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'categoryId': categoryId,
      'fields': fields.map((field) => field.toMap()).toList(),
      'active': active,
      'sourceFileUrl': sourceFileUrl,
      'sourceFileName': sourceFileName,
      'sourceFileKind': sourceFileKind?.name,
      'isGlobal': isGlobal,
      'createdByUid': createdByUid,
      'createdByEmail': createdByEmail,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ClinicFormTemplate copyWith({
    String? id,
    String? name,
    String? description,
    String? categoryId,
    List<ClinicFormField>? fields,
    bool? active,
    String? sourceFileUrl,
    String? sourceFileName,
    FormSourceKind? sourceFileKind,
    bool? isGlobal,
    String? createdByUid,
    String? createdByEmail,
    DateTime? updatedAt,
  }) {
    return ClinicFormTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      fields: fields ?? this.fields,
      active: active ?? this.active,
      sourceFileUrl: sourceFileUrl ?? this.sourceFileUrl,
      sourceFileName: sourceFileName ?? this.sourceFileName,
      sourceFileKind: sourceFileKind ?? this.sourceFileKind,
      isGlobal: isGlobal ?? this.isGlobal,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByEmail: createdByEmail ?? this.createdByEmail,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ClinicFormTemplate && other.listKey == listKey;

  @override
  int get hashCode => listKey.hashCode;
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
