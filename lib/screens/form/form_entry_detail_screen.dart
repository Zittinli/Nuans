import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/clinic_form.dart';
import '../../models/patient.dart';
import '../../services/clinic_service.dart';
import '../../services/local_clinic_cache.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/form_pack.dart';
import '../../widgets/clinic_form_fields.dart';
import 'form_fill_screen.dart';

class FormEntryDetailScreen extends StatelessWidget {
  const FormEntryDetailScreen({
    super.key,
    required this.patient,
    required this.entry,
    this.templates,
    this.readOnly = false,
  });

  final Patient patient;
  final PatientFormEntry entry;
  final List<ClinicFormTemplate>? templates;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final clinic = ClinicService();
    if (templates != null) {
      return _buildScaffold(context, clinic, templates!);
    }
    return StreamBuilder<List<ClinicFormTemplate>>(
      stream: clinic.watchFormTemplates(),
      builder: (context, snapshot) {
        return _buildScaffold(context, clinic, snapshot.data ?? const []);
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    ClinicService clinic,
    List<ClinicFormTemplate> allTemplates,
  ) {
    final template = allTemplates.where((item) => item.id == entry.templateId).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(entry.title),
        actions: [
          if (!readOnly)
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
          if (!readOnly && entry.source == PatientFormSource.filled)
            IconButton(
              tooltip: 'Dolu formu paylaş',
              onPressed: () async {
                try {
                  final packTemplate = (template ??
                          ClinicFormTemplate(
                            id: '',
                            name: entry.title,
                            fields: const [],
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          ))
                      .copyWith(name: entry.title);
                  await FormPack.share(
                    template: packTemplate,
                    clinic: clinic,
                    entry: entry,
                    patient: patient,
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Dolu form paylaşılamadı: $error')),
                  );
                }
              },
              icon: const Icon(Icons.ios_share_outlined),
            ),
          if (!readOnly && entry.source == PatientFormSource.filled && template != null)
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
          ...filledFormRows(entry, template),
          if (entry.scanUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Taranmış sayfalar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            ...entry.scanUrls.indexed.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _ScanPage(
                    patientId: patient.id,
                    formId: entry.id,
                    index: item.$1,
                    url: item.$2,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScanPage extends StatefulWidget {
  const _ScanPage({
    required this.patientId,
    required this.formId,
    required this.index,
    required this.url,
  });

  final String patientId;
  final String formId;
  final int index;
  final String url;

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  File? _file;

  @override
  void initState() {
    super.initState();
    LocalClinicCache().scanFile(widget.patientId, widget.formId, widget.index).then((file) {
      if (mounted && file != null) setState(() => _file = file);
    });
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    if (file != null) return Image.file(file);
    if (widget.url.startsWith('http')) return Image.network(widget.url);
    if (widget.url.isEmpty) return const SizedBox.shrink();
    return Image.file(File(widget.url));
  }
}

List<Widget> filledFormRows(PatientFormEntry entry, ClinicFormTemplate? template) {
  if (template != null) {
    final blocks = splitFormSections(template.fields);
    if (blocks.isEmpty) {
      return [
        const Text('Bu formda doldurulmuş alan yok.', style: TextStyle(color: AppColors.muted)),
      ];
    }
    return [
      for (final block in blocks)
        if (block.header != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    color: AppColors.primary,
                    child: Text(
                      block.header!.label,
                      softWrap: true,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, height: 1.3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (block.fields.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text('Bu bölümde alan yok.', style: TextStyle(color: AppColors.muted)),
                          )
                        else
                          for (final field in block.fields)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(field.label, softWrap: true, style: const TextStyle(color: AppColors.muted, height: 1.35)),
                                  const SizedBox(height: 4),
                                  FilledFieldBody(field: field, value: entry.values[field.id]),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (final field in block.fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(field.label, softWrap: true, style: const TextStyle(color: AppColors.muted, height: 1.35)),
                  const SizedBox(height: 4),
                  FilledFieldBody(field: field, value: entry.values[field.id]),
                ],
              ),
            ),
    ];
  }
  if (entry.values.isEmpty) {
    return [
      const Text('Bu formda doldurulmuş alan yok.', style: TextStyle(color: AppColors.muted)),
    ];
  }
  return entry.values.entries
      .map(
        (item) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(item.key),
          subtitle: Text('${item.value}'),
        ),
      )
      .toList();
}

String displayFilledFormValue(ClinicFormField field, dynamic value) {
  return formatFormFieldValue(field, value);
}
