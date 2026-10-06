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

  static final _teal = PdfColor.fromInt(0xFF0D4F4F);
  static final _border = PdfColor.fromInt(0xFFD7E2E0);
  static final _stripe = PdfColor.fromInt(0xFFF3F6F5);

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
    final date = DateFormat('d MMMM yyyy HH:mm', 'tr_TR').format(entry.createdAt);
    final patientRows = _patientRows(patient);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 48),
        header: (context) => pw.Column(
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: pw.BoxDecoration(
                color: _teal,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'NÜANS',
                          style: pw.TextStyle(
                            font: bold,
                            fontSize: 11,
                            color: PdfColors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          entry.title,
                          style: pw.TextStyle(font: bold, fontSize: 16, color: PdfColors.white),
                        ),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        entry.source.label,
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.white),
                      ),
                      pw.Text(
                        date,
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
          ],
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${context.pageNumber} / ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
              pw.Text(
                'made by posni',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400),
              ),
            ],
          ),
        ),
        build: (context) {
          return [
            if (patientRows.isNotEmpty) ...[
              _sectionTitle('Hasta bilgileri', bold),
              pw.SizedBox(height: 6),
              _infoTable(patientRows, bold),
              pw.SizedBox(height: 18),
            ],
            if (_hasAnswers(entry, template)) ...[
              _sectionTitle('Form yanıtları', bold),
              pw.SizedBox(height: 6),
              ..._answerWidgets(entry, template, bold),
            ],
            if (images.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              _sectionTitle('Taranmış sayfalar', bold),
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

  pw.Widget _sectionTitle(String text, pw.Font bold) {
    return pw.Text(text, style: pw.TextStyle(font: bold, fontSize: 12, color: _teal));
  }

  List<List<String>> _patientRows(Patient patient) {
    final rows = <List<String>>[
      ['Hasta', patient.fullName],
      if (_hasText(patient.identityNumber)) ['T.C. kimlik no', patient.identityNumber!],
      if (patient.birthDate != null)
        [
          'Doğum tarihi',
          [
            DateFormat('d MMMM yyyy', 'tr_TR').format(patient.birthDate!),
            if (patient.age != null) '${patient.age} yaş',
          ].join('  ·  '),
        ],
      if (_hasText(patient.gender) && patient.gender != 'Belirtilmedi') ['Cinsiyet', patient.gender],
      if (_hasText(patient.phone)) ['Telefon', patient.phone!],
      if (_hasText(patient.diagnosis)) ['Ön tanı', patient.diagnosis!.trim()],
      if (_hasText(patient.referrer)) ['Yönlendiren', patient.referrer!.trim()],
    ];
    return rows;
  }

  bool _hasAnswers(PatientFormEntry entry, ClinicFormTemplate? template) {
    if (template != null && template.fields.any((item) => item.type.isInput || item.type.isSection)) {
      return true;
    }
    return entry.values.isNotEmpty;
  }

  List<pw.Widget> _answerWidgets(PatientFormEntry entry, ClinicFormTemplate? template, pw.Font bold) {
    if (template == null || template.fields.isEmpty) {
      final rows = entry.values.entries
          .where((item) => '${item.value}'.trim().isNotEmpty)
          .map((item) => [item.key, '${item.value}'])
          .toList();
      if (rows.isEmpty) return const [];
      return [_answerTable(rows, bold)];
    }
    final widgets = <pw.Widget>[];
    for (final block in splitFormSections(template.fields)) {
      if (block.header != null) {
        widgets.add(
          pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(top: 8, bottom: 4),
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: _teal,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(5),
                topRight: pw.Radius.circular(5),
              ),
            ),
            child: pw.Text(
              block.header!.label,
              style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColors.white),
            ),
          ),
        );
      }
      final rows = <List<String>>[];
      void flushRows() {
        if (rows.isEmpty) return;
        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            decoration: block.header == null
                ? null
                : pw.BoxDecoration(
                    border: pw.Border.all(color: _border, width: 0.7),
                    borderRadius: const pw.BorderRadius.only(
                      bottomLeft: pw.Radius.circular(5),
                      bottomRight: pw.Radius.circular(5),
                    ),
                  ),
            child: _answerTable(rows.toList(), bold),
          ),
        );
        rows.clear();
      }

      for (final field in block.fields.where((item) => item.type.isInput)) {
        if (field.type.isTable) {
          flushRows();
          widgets.add(_pdfDataTable(field, entry.values[field.id], bold));
          continue;
        }
        rows.add([field.label, formatFormFieldValue(field, entry.values[field.id])]);
      }
      if (rows.isEmpty && block.header != null && !block.fields.any((item) => item.type.isTable)) {
        widgets.add(
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _border, width: 0.6),
              borderRadius: const pw.BorderRadius.only(
                bottomLeft: pw.Radius.circular(5),
                bottomRight: pw.Radius.circular(5),
              ),
            ),
            child: pw.Text('—', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          ),
        );
      }
      flushRows();
    }
    return widgets;
  }

  pw.Widget _pdfDataTable(ClinicFormField field, dynamic raw, pw.Font bold) {
    final columns = field.options;
    final data = TableAnswer.rows(raw);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(field.label, style: pw.TextStyle(font: bold, fontSize: 11, color: _teal)),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(color: _border, width: 0.6),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: _teal),
                children: [
                  for (final column in columns)
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      child: pw.Text(
                        column.label,
                        style: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.white),
                      ),
                    ),
                ],
              ),
              if (data.isEmpty)
                pw.TableRow(
                  children: [
                    for (final _ in columns)
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text('—', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      ),
                  ],
                )
              else
                for (final row in data)
                  pw.TableRow(
                    children: [
                      for (final column in columns)
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                          child: pw.Text(
                            TableAnswer.cellText(column, row[column.id]),
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                    ],
                  ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _infoTable(List<List<String>> rows, pw.Font bold) {
    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.15),
        1: pw.FlexColumnWidth(2.2),
      },
      children: [
        for (var i = 0; i < rows.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: i.isEven ? _stripe : PdfColors.white),
            children: [
              _cell(rows[i][0], font: bold, muted: true),
              _cell(rows[i][1]),
            ],
          ),
      ],
    );
  }

  pw.Widget _answerTable(List<List<String>> rows, pw.Font bold) {
    return pw.Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          pw.Container(
            width: double.infinity,
            decoration: pw.BoxDecoration(
              color: i.isOdd ? _stripe : PdfColors.white,
              border: pw.Border.all(color: _border, width: 0.5),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  rows[i][0],
                  style: pw.TextStyle(font: bold, fontSize: 10, color: PdfColors.grey800),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  rows[i][1],
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900),
                ),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _cell(String text, {pw.Font? font, bool muted = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 10,
          color: muted ? PdfColors.grey700 : PdfColors.grey900,
        ),
      ),
    );
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  String _fileName(String patientName, String title) {
    final safe = '$patientName-$title'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9çğıöşü]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .trim();
    return '$safe.pdf';
  }
}
