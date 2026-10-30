import 'package:flutter/material.dart';

import '../models/clinic_form.dart';
import '../models/form_category.dart';
import '../models/patient.dart';
import '../screens/form/form_actions.dart';
import '../screens/form/form_fill_screen.dart';
import '../services/clinic_service.dart';
import '../theme/app_theme.dart';

class PatientFormSelector extends StatefulWidget {
  const PatientFormSelector({super.key, required this.patient, this.popBeforeFill = false});

  final Patient patient;
  final bool popBeforeFill;

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
    final patient = widget.patient;
    final root = Navigator.of(context, rootNavigator: true);
    if (widget.popBeforeFill) {
      Navigator.of(context).pop();
    }
    root.push(
      MaterialPageRoute(
        builder: (_) => FormFillScreen(patient: patient, template: template),
      ),
    );
  }

  Future<T?> _pickOne<T>({
    required String title,
    required List<T> items,
    required String Function(T item) labelOf,
  }) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final item in items)
                ListTile(
                  title: Text(labelOf(item)),
                  onTap: () => Navigator.pop(dialogContext, item),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
        ],
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
                _ChoiceField(
                  hint: categories.isEmpty ? 'Kategori yok' : 'Kategori seçin',
                  value: selectedCategory?.name,
                  enabled: categories.isNotEmpty,
                  onTap: () async {
                    final picked = await _pickOne<FormCategory>(
                      title: 'Form kategorisi',
                      items: categories,
                      labelOf: (item) => item.name,
                    );
                    if (picked == null || !mounted) return;
                    setState(() {
                      _selectedCategory = picked;
                      _selectedForm = null;
                    });
                  },
                ),
                if (selectedCategory != null) ...[
                  const SizedBox(height: 12),
                  const Text('Form seç', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ChoiceField(
                          hint: formsInCategory.isEmpty ? 'Bu kategoride aktif form yok' : 'Form şablonu',
                          value: selectedForm == null
                              ? null
                              : selectedForm.isGlobal
                                  ? '${selectedForm.name} (varsayılan)'
                                  : selectedForm.name,
                          enabled: formsInCategory.isNotEmpty,
                          onTap: () async {
                            final picked = await _pickOne<ClinicFormTemplate>(
                              title: 'Form seç',
                              items: formsInCategory,
                              labelOf: (item) => item.isGlobal ? '${item.name} (varsayılan)' : item.name,
                            );
                            if (picked == null || !mounted) return;
                            setState(() => _selectedForm = picked);
                          },
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

class _ChoiceField extends StatelessWidget {
  const _ChoiceField({
    required this.hint,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final String hint;
  final String? value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shown = value?.trim();
    final hasValue = shown != null && shown.isNotEmpty;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          hasValue ? shown : hint,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: hasValue && enabled ? null : AppColors.muted),
        ),
      ),
    );
  }
}
