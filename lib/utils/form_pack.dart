import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/clinic_form.dart';
import '../services/clinic_service.dart';

const kNuansFormFormat = 'nuans-form';
const kNuansFormExtension = 'nuansform';

class ImportedFormPack {
  const ImportedFormPack({
    required this.template,
    this.sourceFile,
    this.sourceFileName,
    this.sourceFileKind,
  });

  final ClinicFormTemplate template;
  final File? sourceFile;
  final String? sourceFileName;
  final FormSourceKind? sourceFileKind;
}

class FormPack {
  static bool looksLikePack(String fileName, [String? contents]) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.$kNuansFormExtension')) return true;
    if (contents == null) return lower.endsWith('.json');
    try {
      final decoded = jsonDecode(contents);
      return decoded is Map && decoded['format'] == kNuansFormFormat;
    } catch (_) {
      return false;
    }
  }

  static Future<ImportedFormPack> importFile(File file) async {
    final text = await file.readAsString();
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('Bu dosya Nüans form dosyası değil.');
    }
    final data = Map<String, dynamic>.from(decoded);
    if (data['format'] != kNuansFormFormat) {
      throw const FormatException('Bu dosya Nüans form dosyası değil.');
    }

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

    return ImportedFormPack(
      template: ClinicFormTemplate(
        id: '',
        name: data['name'] as String? ?? 'Aktarılan form',
        description: data['description'] as String?,
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
    );
  }

  static Future<File> writeFile({
    required ClinicFormTemplate template,
    ClinicService? clinic,
    String? localSourcePath,
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

    final payload = <String, dynamic>{
      'format': kNuansFormFormat,
      'version': 1,
      'name': template.name,
      'description': template.description,
      'fields': template.fields.map((field) => field.toMap()).toList(),
      'sourceFileName': template.sourceFileName,
      'sourceFileKind': template.sourceFileKind?.name,
      if (sourceBytes != null) 'sourceFileBase64': base64Encode(sourceBytes),
    };

    final dir = await getTemporaryDirectory();
    final safe = _safeFileName(template.name);
    final file = File('${dir.path}/$safe.$kNuansFormExtension');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload), flush: true);
    return file;
  }

  static Future<void> share({
    required ClinicFormTemplate template,
    ClinicService? clinic,
    String? localSourcePath,
  }) async {
    final file = await writeFile(
      template: template,
      clinic: clinic,
      localSourcePath: localSourcePath,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json', name: file.uri.pathSegments.last)],
        text: 'Nüans form şablonu: ${template.name}',
      ),
    );
  }

  static String _safeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), ' ').trim();
    if (cleaned.isEmpty) return 'Nuans_formu';
    return cleaned.length > 60 ? cleaned.substring(0, 60).trim() : cleaned;
  }
}
