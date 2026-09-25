import 'package:flutter/material.dart';

import '../../models/clinic_form.dart';
import '../../models/patient.dart';
import '../../services/clinic_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/form_attachment.dart';
import '../../widgets/clinic_form_fields.dart';

class FormFillScreen extends StatefulWidget {
  const FormFillScreen({
    super.key,
    required this.patient,
    required this.template,
    this.entry,
  });

  final Patient patient;
  final ClinicFormTemplate template;
  final PatientFormEntry? entry;

  @override
  State<FormFillScreen> createState() => _FormFillScreenState();
}

class _FormFillScreenState extends State<FormFillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clinic = ClinicService();
  late final Map<String, dynamic> _values;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _values = Map<String, dynamic>.from(widget.entry?.values ?? {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      await _clinic.savePatientForm(
        widget.patient.id,
        PatientFormEntry(
          id: widget.entry?.id ?? '',
          templateId: widget.template.id,
          title: widget.template.name,
          source: PatientFormSource.filled,
          values: _values,
          scanUrls: widget.entry?.scanUrls ?? const [],
          createdAt: widget.entry?.createdAt ?? now,
          updatedAt: now,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Form kaydedilemedi: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.template.name)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${widget.patient.fullName} için form dolduruluyor.',
              style: const TextStyle(color: AppColors.muted),
            ),
            if (widget.template.description?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(widget.template.description!),
            ],
            if (widget.template.hasSourceFile) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => openFormSourceFile(context: context, template: widget.template),
                icon: Icon(
                  widget.template.sourceFileKind == FormSourceKind.pdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.description_outlined,
                ),
                label: Text(widget.template.sourceFileName ?? 'Kaynak dosyayı aç'),
              ),
            ],
            const SizedBox(height: 16),
            ClinicFormFieldsSection(
              fields: widget.template.fields,
              values: _values,
              onValuesChanged: () => setState(() {}),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Formu kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
