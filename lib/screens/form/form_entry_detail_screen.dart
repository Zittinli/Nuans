import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/clinic_form.dart';
import '../../models/patient.dart';
import '../../services/clinic_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import 'form_fill_screen.dart';

class FormEntryDetailScreen extends StatelessWidget {
  const FormEntryDetailScreen({
    super.key,
    required this.patient,
    required this.entry,
  });

  final Patient patient;
  final PatientFormEntry entry;

  @override
  Widget build(BuildContext context) {
    final clinic = ClinicService();
    return StreamBuilder<List<ClinicFormTemplate>>(
      stream: clinic.watchFormTemplates(),
      builder: (context, snapshot) {
        final template = snapshot.data?.where((item) => item.id == entry.templateId).firstOrNull;
        return Scaffold(
          appBar: AppBar(
            title: Text(entry.title),
            actions: [
              IconButton(
                tooltip: 'PDF paylaş',
                onPressed: () async {
                  try {
                    await PdfService(clinic: clinic).sharePatientForm(
                      patient: patient,
                      entry: entry,
                      template: template,
                    );
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('PDF paylaşılamadı: $error')),
                    );
                  }
                },
                icon: const Icon(Icons.picture_as_pdf_outlined),
              ),
              if (entry.source == PatientFormSource.filled && template != null)
                IconButton(
                  tooltip: 'Düzenle',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FormFillScreen(
                          patient: patient,
                          template: template,
                          entry: entry,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                DateFormat('d MMMM yyyy HH:mm', 'tr_TR').format(entry.createdAt),
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              Chip(label: Text(entry.source.label), backgroundColor: AppColors.chip, side: BorderSide.none),
              const SizedBox(height: 16),
              if (template != null)
                ...template.fields.map((field) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(field.label, style: const TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 4),
                        Text(_display(field, entry.values[field.id]), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                })
              else if (entry.values.isNotEmpty)
                ...entry.values.entries.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.key),
                    subtitle: Text('${item.value}'),
                  ),
                ),
              if (entry.scanUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Taranmış sayfalar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                ...entry.scanUrls.map(
                  (url) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: url.startsWith('http')
                          ? Image.network(url)
                          : Image.file(File(url)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _display(ClinicFormField field, dynamic value) {
    if (value == null || '$value'.trim().isEmpty) return '—';
    if (field.type == FormFieldType.boolean) {
      return value == true || value == 'true' ? 'Evet' : 'Hayır';
    }
    if (value is List) return value.map((item) => '$item').join(', ');
    return '$value';
  }
}
