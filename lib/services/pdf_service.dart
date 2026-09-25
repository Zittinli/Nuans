import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/clinic_form.dart';
import '../models/patient.dart';
import 'clinic_service.dart';

class PdfService {
  PdfService({ClinicService? clinic}) : _clinic = clinic ?? ClinicService();

  final ClinicService _clinic;

  Future<void> sharePatientForm({
    required Patient patient,
    required PatientFormEntry entry,
    ClinicFormTemplate? template,
  }) async {
    final bytes = await buildPatientFormPdf(
      patient: patient,
      entry: entry,
      template: template,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: _fileName(patient.fullName, entry.title),
    );
  }

  Future<Uint8List> buildPatientFormPdf({
    required Patient patient,
    required PatientFormEntry entry,
    ClinicFormTemplate? template,
  }) async {
    final base = await PdfGoogleFonts.robotoRegular();
    final bold = await PdfGoogleFonts.robotoBold();
    final images = <pw.MemoryImage>[];
    for (final url in entry.scanUrls) {
      final data = await _clinic.downloadBytes(url);
      if (data != null && data.isNotEmpty) {
        images.add(pw.MemoryImage(Uint8List.fromList(data)));
      }
    }

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: base, bold: bold),
    );
    final date = DateFormat("d MMMM yyyy HH:mm", 'tr_TR').format(entry.createdAt);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('NÜANS', style: pw.TextStyle(font: bold, fontSize: 18, color: PdfColor.fromInt(0xFF0D4F4F))),
                      pw.SizedBox(height: 4),
                      pw.Text(entry.title, style: pw.TextStyle(font: bold, fontSize: 22)),
                      pw.Text(entry.source.label, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.Text(date, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromInt(0xFFD7E2E0)),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _kv('Hasta', patient.fullName, bold),
                  if (patient.identityNumber != null) _kv('T.C.', patient.identityNumber!, bold),
                  if (patient.diagnosis != null) _kv('Ön tanı', patient.diagnosis!, bold),
                  if (patient.referrer != null) _kv('Yönlendiren', patient.referrer!, bold),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            if (template != null && template.fields.isNotEmpty) ...[
              pw.Text('Form içeriği', style: pw.TextStyle(font: bold, fontSize: 14)),
              pw.SizedBox(height: 8),
              ...template.fields.map((field) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(field.label, style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text(_formatValue(field, entry.values[field.id])),
                    ],
                  ),
                );
              }),
            ] else if (entry.values.isNotEmpty) ...[
              ...entry.values.entries.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: _kv(item.key, '${item.value}', bold),
                );
              }),
            ],
            if (images.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Text('Taranmış sayfalar', style: pw.TextStyle(font: bold, fontSize: 14)),
              pw.SizedBox(height: 8),
              ...images.map(
                (image) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              ),
            ],
          ];
        },
      ),
    );

    return Uint8List.fromList(await doc.save());
  }

  pw.Widget _kv(String label, String value, pw.Font bold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: '$label: ', style: pw.TextStyle(font: bold)),
            pw.TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  String _formatValue(ClinicFormField field, dynamic value) {
    if (value == null || '$value'.trim().isEmpty) return '—';
    switch (field.type) {
      case FormFieldType.boolean:
        return value == true || value == 'true' ? 'Evet' : 'Hayır';
      case FormFieldType.multiChoice:
        if (value is List) return value.map((item) => '$item').join(', ');
        return '$value';
      default:
        return '$value';
    }
  }

  String _fileName(String patientName, String title) {
    final safe = '$patientName-$title'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9çğıöşü]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .trim();
    return '$safe.pdf';
  }
}
