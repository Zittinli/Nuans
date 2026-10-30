import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/clinic_form.dart';
import '../models/patient.dart';
import '../services/clinic_service.dart';

const kNuansFormFormat = 'nuans';
const kNuansFormLegacyFormat = 'nuans-form';
const kNuansFormExtension = 'nuans';
const kNuansFormMime = 'application/nuans';

class ImportedFormPack {
  const ImportedFormPack({
    required this.template,
    this.sourceFile,
    this.sourceFileName,
    this.sourceFileKind,
    this.filled = false,
    this.values = const {},
    this.patientMeta,
  });

  final ClinicFormTemplate template;
  final File? sourceFile;
  final String? sourceFileName;
  final FormSourceKind? sourceFileKind;
  final bool filled;
  final Map<String, dynamic> values;
  final Map<String, dynamic>? patientMeta;

  String? get patientName {
    final name = '${patientMeta?['fullName'] ?? ''}'.trim();
    return name.isEmpty ? null : name;
  }

  String? get identityNumber {
    final fromMeta = '${patientMeta?['identityNumber'] ?? ''}'.trim();
    return fromMeta.isEmpty ? null : fromMeta;
  }
}

class FormPack {
  static bool looksLikePack(String fileName, [String? contents]) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.$kNuansFormExtension') ||
        lower.endsWith('.nuansform') ||
        lower.endsWith('.zip')) {
      return true;
    }
    if (contents == null) return lower.endsWith('.json');
    try {
      return _isPackMap(jsonDecode(contents));
    } catch (_) {
      return false;
    }
  }

  static bool _isPackMap(dynamic decoded) {
    if (decoded is! Map) return false;
    final format = '${decoded['format'] ?? ''}'.toLowerCase();
    if (format.contains('nuans')) return true;
    return decoded.containsKey('fields') && decoded.containsKey('name');
  }

  static Future<ImportedFormPack> importFile(File file) async {
    var path = file.path;
    if (path.toLowerCase().endsWith('.zip')) {
      final extracted = await _shareChannel.invokeMethod<String>('unzipNuans', {'path': path});
      if (extracted == null || extracted.isEmpty) {
        throw const FormatException('Zip içinde İNÜ SKY formu yok.');
      }
      path = extracted;
    }
    final packFile = File(path);
    var text = await packFile.readAsString();
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }
    final decoded = jsonDecode(text);
    if (!_isPackMap(decoded)) {
      throw const FormatException('Bu dosya İNÜ SKY form dosyası değil.');
    }
    final data = Map<String, dynamic>.from(decoded as Map);

    final now = DateTime.now();
    final fields = (data['fields'] as List? ?? [])
        .whereType<Map>()
        .map((item) => ClinicFormField.fromMap(Map<String, dynamic>.from(item)))
        .toList();
    final sourceName = data['sourceFileName'] as String?;
    final sourceKind = FormSourceKind.fromName(data['sourceFileKind'] as String?);
    File? sourceFile;
    final encoded = data['sourceFileBase64'] as String?;
    if (encoded != null && encoded.isNotEmpty && sourceName != null) {
      final bytes = base64Decode(encoded);
      final dir = await getTemporaryDirectory();
      sourceFile = File('${dir.path}/imported_$sourceName');
      await sourceFile.writeAsBytes(bytes, flush: true);
    }

    final valuesRaw = data['values'];
    final values = valuesRaw is Map
        ? Map<String, dynamic>.from(valuesRaw)
        : const <String, dynamic>{};
    Map<String, dynamic>? patientMeta;
    final patientRaw = data['patient'];
    if (patientRaw is Map) {
      patientMeta = Map<String, dynamic>.from(patientRaw);
    }
    final identity = '${data['identityNumber'] ?? patientMeta?['identityNumber'] ?? ''}'.trim();
    if (identity.isNotEmpty) {
      patientMeta = {...?patientMeta, 'identityNumber': identity};
    }

    return ImportedFormPack(
      template: ClinicFormTemplate(
        id: '',
        name: data['name'] as String? ?? 'Aktarılan form',
        description: data['description'] as String?,
        categoryId: data['categoryId'] as String?,
        fields: fields,
        active: true,
        sourceFileName: sourceName,
        sourceFileKind: sourceKind,
        createdAt: now,
        updatedAt: now,
      ),
      sourceFile: sourceFile,
      sourceFileName: sourceName,
      sourceFileKind: sourceKind,
      filled: data['filled'] == true,
      values: values,
      patientMeta: patientMeta,
    );
  }

  static Future<File> writeFile({
    required ClinicFormTemplate template,
    ClinicService? clinic,
    String? localSourcePath,
    PatientFormEntry? entry,
    Patient? patient,
  }) async {
    List<int>? sourceBytes;
    if (localSourcePath != null) {
      final local = File(localSourcePath);
      if (await local.exists()) {
        sourceBytes = await local.readAsBytes();
      }
    } else if (template.hasSourceFile) {
      sourceBytes = await (clinic ?? ClinicService()).downloadBytes(template.sourceFileUrl!);
    }

    final filledEntry =
        entry != null && entry.source == PatientFormSource.filled ? entry : null;
    final payload = <String, dynamic>{
      'format': kNuansFormFormat,
      'version': 1,
      'name': template.name,
      'description': template.description,
      'categoryId': template.categoryId,
      'fields': template.fields.map((field) => field.toMap()).toList(),
      'sourceFileName': template.sourceFileName,
      'sourceFileKind': template.sourceFileKind?.name,
      if (sourceBytes != null) 'sourceFileBase64': base64Encode(sourceBytes),
      if (filledEntry != null) 'filled': true,
      if (filledEntry != null) 'values': filledEntry.values,
      if (filledEntry != null && patient != null) 'identityNumber': patient.identityNumber,
      if (filledEntry != null && patient != null)
        'patient': {
          'fullName': patient.fullName,
          'identityNumber': patient.identityNumber,
          'gender': patient.gender,
          'phone': patient.phone,
          'diagnosis': patient.diagnosis,
          'referrer': patient.referrer,
          if (patient.birthDate != null) 'birthDate': patient.birthDate!.toIso8601String(),
        },
    };

    final dir = await getTemporaryDirectory();
    final fileName = packFileName(template.name, filled: filledEntry != null);
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) {
      await file.delete();
    }
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload), flush: true);
    return file;
  }

  static Future<ImportedFormPack> importIntoCurrentAccount(String path) async {
    final pack = await importFile(File(path));
    final clinic = ClinicService();
    var template = pack.template.copyWith(isGlobal: false, active: false);
    final id = await clinic.saveFormTemplate(template);
    if (pack.sourceFile != null && pack.sourceFileName != null) {
      try {
        final url = await clinic.uploadFormTemplateSource(
          templateId: id,
          file: pack.sourceFile!,
          fileName: pack.sourceFileName!,
        );
        template = template.copyWith(
          id: id,
          sourceFileUrl: url,
          sourceFileName: pack.sourceFileName,
          sourceFileKind: pack.sourceFileKind,
        );
        await clinic.saveFormTemplate(template);
        return ImportedFormPack(
          template: template,
          sourceFile: pack.sourceFile,
          sourceFileName: pack.sourceFileName,
          sourceFileKind: pack.sourceFileKind,
          filled: pack.filled,
          values: pack.values,
          patientMeta: pack.patientMeta,
        );
      } catch (_) {}
    }
    return ImportedFormPack(
      template: template.copyWith(id: id),
      sourceFile: pack.sourceFile,
      sourceFileName: pack.sourceFileName,
      sourceFileKind: pack.sourceFileKind,
      filled: pack.filled,
      values: pack.values,
      patientMeta: pack.patientMeta,
    );
  }

  static String normalizeIdentity(String? value) {
    return (value ?? '').replaceAll(RegExp(r'\D'), '');
  }

  static Patient? matchPatientByIdentity(List<Patient> patients, String? identity) {
    final needle = normalizeIdentity(identity);
    if (needle.isEmpty) return null;
    return patients.where((item) => normalizeIdentity(item.identityNumber) == needle).firstOrNull;
  }

  static Patient? patientFromMeta(Map<String, dynamic>? meta, {String id = ''}) {
    if (meta == null) return null;
    final name = '${meta['fullName'] ?? ''}'.trim();
    if (name.isEmpty) return null;
    DateTime? birthDate;
    final rawBirth = meta['birthDate'];
    if (rawBirth is String && rawBirth.isNotEmpty) {
      birthDate = DateTime.tryParse(rawBirth);
    }
    final now = DateTime.now();
    return Patient(
      id: id,
      fullName: name,
      identityNumber: _emptyToNull('${meta['identityNumber'] ?? ''}'),
      birthDate: birthDate,
      gender: '${meta['gender'] ?? ''}'.trim().isEmpty ? 'Belirtilmedi' : '${meta['gender']}',
      phone: _emptyToNull('${meta['phone'] ?? ''}'),
      diagnosis: _emptyToNull('${meta['diagnosis'] ?? ''}'),
      referrer: _emptyToNull('${meta['referrer'] ?? ''}'),
      createdAt: now,
      updatedAt: now,
    );
  }

  static const _shareChannel = MethodChannel('com.nuans.nuans/open_file');

  static Future<String> share({
    required ClinicFormTemplate template,
    ClinicService? clinic,
    String? localSourcePath,
    PatientFormEntry? entry,
    Patient? patient,
  }) async {
    final filledEntry =
        entry != null && entry.source == PatientFormSource.filled ? entry : null;
    final file = await writeFile(
      template: template,
      clinic: clinic,
      localSourcePath: localSourcePath,
      entry: entry,
      patient: patient,
    );
    final fileName = packFileName(template.name, filled: filledEntry != null);
    await _shareChannel.invokeMethod<void>('shareFile', {
      'path': file.path,
      'name': fileName,
    });
    return fileName;
  }

  static String packFileName(String formName, {bool filled = false}) {
    final safe = _safeFileName(formName);
    if (filled) return '$safe(dolu).$kNuansFormExtension';
    return '$safe.$kNuansFormExtension';
  }

  static String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _safeFileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[^\w\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    if (cleaned.isEmpty) return 'Nuans_formu';
    return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
  }
}
