import 'package:flutter/material.dart';

import '../models/clinic_form.dart';
import '../models/patient.dart';
import '../screens/form/form_actions.dart';
import '../screens/form/form_fill_screen.dart';
import '../services/clinic_service.dart';
import '../theme/app_theme.dart';

class PatientFormSelector extends StatefulWidget {
  const PatientFormSelector({super.key, required this.patient});

  final Patient patient;

  @override
  State<PatientFormSelector> createState() => _PatientFormSelectorState();
}

class _PatientFormSelectorState extends State<PatientFormSelector> {
  final _clinic = ClinicService();
  ClinicFormTemplate? _selected;

  void _openFill(ClinicFormTemplate template) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FormFillScreen(patient: widget.patient, template: template),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClinicFormTemplate>>(
      stream: _clinic.watchFormTemplates(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Formlar yüklenemedi: ${snapshot.error}');
        }
        final all = snapshot.data ?? const <ClinicFormTemplate>[];
        final active = all.where((item) => item.active).toList();
        final selected = _selected != null && active.any((item) => item.id == _selected!.id)
            ? _selected
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Form seç', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<ClinicFormTemplate?>(
                    value: selected,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: active.isEmpty ? 'Aktif form yok' : 'Form şablonu',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      if (active.isEmpty)
                        const DropdownMenuItem<ClinicFormTemplate?>(
                          value: null,
                          enabled: false,
                          child: Text('Ayarlardan form ekleyin'),
                        )
                      else
                        ...active.map(
                          (template) => DropdownMenuItem(
                            value: template,
                            child: Text(template.name, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                    ],
                    onChanged: active.isEmpty ? null : (value) => setState(() => _selected = value),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Diğer form işlemleri',
                  onPressed: () => showNewFormSheet(context: context, patient: widget.patient),
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
            if (active.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Profil menüsünden form ekleyip aktif yapın.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            if (selected != null) ...[
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () => _openFill(selected),
                icon: const Icon(Icons.edit_document),
                label: Text('${selected.name} doldur'),
              ),
            ],
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}
