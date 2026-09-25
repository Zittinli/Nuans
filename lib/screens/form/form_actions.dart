import 'package:flutter/material.dart';

import '../../models/clinic_form.dart';
import '../../models/patient.dart';
import '../../services/clinic_service.dart';
import '../../services/scan_service.dart';
import '../../theme/app_theme.dart';
import 'form_builder_screen.dart';
import 'form_fill_screen.dart';

Future<void> showNewFormSheet({
  required BuildContext context,
  required Patient patient,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => _NewFormSheet(patient: patient),
  );
}

class _NewFormSheet extends StatelessWidget {
  const _NewFormSheet({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final clinic = ClinicService();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: StreamBuilder<List<ClinicFormTemplate>>(
          stream: clinic.watchFormTemplates(),
          builder: (context, snapshot) {
            final templates = (snapshot.data ?? const <ClinicFormTemplate>[])
                .where((item) => item.active)
                .toList();
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.72),
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Text('Yeni form', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text(
                    'Hazır şablonlardan doldurun, kağıt formu tarayın veya yeni bir form tasarlayın.',
                    style: TextStyle(color: AppColors.muted, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.document_scanner_outlined),
                    title: const Text('Kağıttan tara'),
                    subtitle: const Text('Kamera ile gerçek formu tarayın'),
                    onTap: () async {
                      Navigator.pop(context);
                      await _scanAndSave(context, patient);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.post_add_outlined),
                    title: const Text('Yeni form şablonu oluştur'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const FormBuilderScreen()),
                      );
                    },
                  ),
                  if (templates.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        'Klinik formları buraya eklenecek. Şimdilik kendi şablonunuzu oluşturabilirsiniz.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    )
                  else ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text('Şablonlar', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    ...templates.map((template) {
                      return ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(template.name),
                        subtitle: Text('${template.fields.length} alan'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FormFillScreen(patient: patient, template: template),
                            ),
                          );
                        },
                      );
                    }),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

Future<void> _scanAndSave(BuildContext context, Patient patient) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final pages = await ScanService().scanPages();
    if (pages.isEmpty) return;
    final clinic = ClinicService();
    final now = DateTime.now();
    final formId = await clinic.savePatientForm(
      patient.id,
      PatientFormEntry(
        id: '',
        title: 'Taranmış form',
        source: PatientFormSource.scanned,
        values: const {},
        scanUrls: const [],
        createdAt: now,
        updatedAt: now,
      ),
    );
    try {
      final urls = await clinic.uploadFormScans(
        patientId: patient.id,
        formId: formId,
        localPaths: pages,
      );
      await clinic.savePatientForm(
        patient.id,
        PatientFormEntry(
          id: formId,
          title: 'Taranmış form',
          source: PatientFormSource.scanned,
          values: const {},
          scanUrls: urls,
          createdAt: now,
          updatedAt: DateTime.now(),
        ),
      );
    } catch (_) {
      await clinic.savePatientForm(
        patient.id,
        PatientFormEntry(
          id: formId,
          title: 'Taranmış form',
          source: PatientFormSource.scanned,
          values: const {},
          scanUrls: pages,
          createdAt: now,
          updatedAt: DateTime.now(),
        ),
      );
    }
    messenger.showSnackBar(const SnackBar(content: Text('Form tarandı ve kaydedildi.')));
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text('Tarama başarısız: $error')));
  }
}
