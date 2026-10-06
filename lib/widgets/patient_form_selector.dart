import 'package:flutter/material.dart';

import '../models/clinic_form.dart';
import '../models/form_category.dart';
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
  FormCategory? _selectedCategory;
  ClinicFormTemplate? _selectedForm;

  @override
  void initState() {
    super.initState();
    _clinic.ensureDefaultFormCategories();
  }

  void _openFill(ClinicFormTemplate template) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FormFillScreen(patient: widget.patient, template: template),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FormCategory>>(
      stream: _clinic.watchFormCategories(),
      builder: (context, categorySnap) {
        if (categorySnap.hasError) {
          return Text('Kategoriler yüklenemedi: ${categorySnap.error}');
        }
        final categories = categorySnap.data ?? const <FormCategory>[];

        return StreamBuilder<List<ClinicFormTemplate>>(
          stream: _clinic.watchFormTemplates(),
          builder: (context, formSnap) {
            if (formSnap.hasError) {
              return Text('Formlar yüklenemedi: ${formSnap.error}');
            }
            final active = (formSnap.data ?? const <ClinicFormTemplate>[])
                .where((item) => item.active && item.hasCategory)
                .toList();

            final selectedCategory = _selectedCategory == null
                ? null
                : categories.where((item) => item.id == _selectedCategory!.id).firstOrNull;

            final formsInCategory = selectedCategory == null
                ? const <ClinicFormTemplate>[]
                : active.where((item) => item.categoryId == selectedCategory.id).toList();

            final selectedForm = _selectedForm == null
                ? null
                : formsInCategory.where((item) => item.listKey == _selectedForm!.listKey).firstOrNull;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Form kategorisi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<FormCategory?>(
                  value: selectedCategory,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: categories.isEmpty ? 'Kategori yok' : 'Kategori seçin',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: [
                    if (categories.isEmpty)
                      const DropdownMenuItem<FormCategory?>(
                        value: null,
                        enabled: false,
                        child: Text('Yönetimden kategori ekleyin'),
                      )
                    else
                      ...categories.map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                  ],
                  onChanged: categories.isEmpty
                      ? null
                      : (value) => setState(() {
                            _selectedCategory = value;
                            _selectedForm = null;
                          }),
                ),
                if (selectedCategory != null) ...[
                  const SizedBox(height: 12),
                  const Text('Form seç', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<ClinicFormTemplate?>(
                          value: selectedForm,
                          isExpanded: true,
                          decoration: InputDecoration(
                            hintText: formsInCategory.isEmpty
                                ? 'Bu kategoride aktif form yok'
                                : 'Form şablonu',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: [
                            if (formsInCategory.isEmpty)
                              const DropdownMenuItem<ClinicFormTemplate?>(
                                value: null,
                                enabled: false,
                                child: Text('Form ekleyin'),
                              )
                            else
                              ...formsInCategory.map(
                                (template) => DropdownMenuItem(
                                  value: template,
                                  child: Text(
                                    template.isGlobal
                                        ? '${template.name} (varsayılan)'
                                        : template.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                          ],
                          onChanged: formsInCategory.isEmpty
                              ? null
                              : (value) => setState(() => _selectedForm = value),
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
                ],
                if (categories.isEmpty || active.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      categories.isEmpty
                          ? 'Form kategorileri tanımlanmadan hasta formu seçilemez.'
                          : 'Profil menüsünden kategorili ve aktif form ekleyin.',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ),
                if (selectedForm != null) ...[
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => _openFill(selectedForm),
                    icon: const Icon(Icons.edit_document),
                    label: Text('${selectedForm.name} doldur'),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            );
          },
        );
      },
    );
  }
}
