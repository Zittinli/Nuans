import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/clinic_form.dart';
import '../services/clinic_service.dart';

Future<void> openFormSourceFile({
  required BuildContext context,
  required ClinicFormTemplate template,
  ClinicService? clinic,
}) async {
  final url = template.sourceFileUrl;
  if (url == null || url.isEmpty) return;

  final messenger = ScaffoldMessenger.of(context);
  final service = clinic ?? ClinicService();
  final bytes = await service.downloadBytes(url);
  if (bytes == null) {
    messenger.showSnackBar(const SnackBar(content: Text('Dosya açılamadı.')));
    return;
  }

  final name = template.sourceFileName ?? 'form';
  if (template.sourceFileKind == FormSourceKind.pdf) {
    await Printing.layoutPdf(onLayout: (_) async => Uint8List.fromList(bytes));
    return;
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], text: template.name),
  );
}
