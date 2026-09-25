import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/clinic_form.dart';
import '../theme/app_theme.dart';

/// Hasta formu doldurma ve şablon önizlemesinde ortak alan çizimi.
class ClinicFormFieldsSection extends StatelessWidget {
  const ClinicFormFieldsSection({
    super.key,
    required this.fields,
    this.values,
    this.preview = false,
    this.onValuesChanged,
  });

  final List<ClinicFormField> fields;
  final Map<String, dynamic>? values;
  final bool preview;
  final VoidCallback? onValuesChanged;

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            preview
                ? 'Bu şablonda henüz alan yok. Alanlar sekmesinden ekleyin.'
                : 'Bu formda doldurulacak alan tanımlı değil.',
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: fields.map((field) => _ClinicFormFieldTile(
            field: field,
            values: values,
            preview: preview,
            onValuesChanged: onValuesChanged,
          )).toList(),
    );
  }
}

class _ClinicFormFieldTile extends StatelessWidget {
  const _ClinicFormFieldTile({
    required this.field,
    required this.values,
    required this.preview,
    this.onValuesChanged,
  });

  final ClinicFormField field;
  final Map<String, dynamic>? values;
  final bool preview;
  final VoidCallback? onValuesChanged;

  void _notify() => onValuesChanged?.call();

  @override
  Widget build(BuildContext context) {
    switch (field.type) {
      case FormFieldType.text:
      case FormFieldType.multiline:
      case FormFieldType.number:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            enabled: !preview,
            initialValue: preview ? '' : '${values?[field.id] ?? ''}',
            minLines: field.type == FormFieldType.multiline ? 3 : 1,
            maxLines: field.type == FormFieldType.multiline ? 6 : 1,
            keyboardType: field.type == FormFieldType.number
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            decoration: InputDecoration(
              labelText: field.label,
              suffixIcon: field.required
                  ? const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Text('*', style: TextStyle(color: AppColors.danger)),
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              hintText: preview ? _hintFor(field.type) : null,
            ),
            validator: preview
                ? null
                : (value) {
                    if (field.required && (value == null || value.trim().isEmpty)) {
                      return 'Bu alan zorunlu';
                    }
                    return null;
                  },
            onChanged: preview ? null : (value) {
              values?[field.id] = value;
              _notify();
            },
          ),
        );
      case FormFieldType.date:
        final current = preview ? null : values?[field.id] as String?;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FormField<String>(
            initialValue: current,
            validator: preview
                ? null
                : (value) {
                    if (field.required && (value == null || value.isEmpty)) {
                      return 'Tarih seçin';
                    }
                    return null;
                  },
            builder: (state) {
              return InkWell(
                onTap: preview
                    ? null
                    : () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: DateTime.tryParse(current ?? '') ?? DateTime.now(),
                          firstDate: DateTime(1900),
                          lastDate: DateTime(2100),
                          locale: const Locale('tr', 'TR'),
                        );
                        if (selected == null) return;
                        final formatted = DateFormat('yyyy-MM-dd').format(selected);
                        values?[field.id] = formatted;
                        state.didChange(formatted);
                        _notify();
                      },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: field.label,
                    errorText: state.errorText,
                    suffixIcon: field.required
                        ? const Icon(Icons.emergency, size: 10, color: AppColors.danger)
                        : null,
                  ),
                  child: Text(
                    preview
                        ? 'Örnek: 15 Mart 2026'
                        : current == null || current.isEmpty
                            ? 'Seçilmedi'
                            : DateFormat('d MMMM yyyy', 'tr_TR').format(DateTime.parse(current)),
                    style: TextStyle(color: preview ? AppColors.muted : null),
                  ),
                ),
              );
            },
          ),
        );
      case FormFieldType.boolean:
        final value = preview ? false : values?[field.id] == true;
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          subtitle: field.required ? const Text('Zorunlu', style: TextStyle(color: AppColors.muted)) : null,
          value: value,
          onChanged: preview
              ? null
              : (next) {
                  values?[field.id] = next;
                  _notify();
                },
        );
      case FormFieldType.singleChoice:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            value: preview ? null : values?[field.id] as String?,
            decoration: InputDecoration(labelText: field.label),
            hint: preview ? Text(field.options.isNotEmpty ? field.options.first : 'Seçenek') : null,
            items: field.options
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: preview
                ? null
                : (value) {
                    values?[field.id] = value;
                    _notify();
                  },
            validator: preview
                ? null
                : (value) {
                    if (field.required && (value == null || value.isEmpty)) {
                      return 'Seçim yapın';
                    }
                    if (field.options.isEmpty) return 'Seçenek tanımlı değil';
                    return null;
                  },
          ),
        );
      case FormFieldType.multiChoice:
        final selected = preview
            ? <String>[]
            : List<String>.from(values?[field.id] as List? ?? const []);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FormField<List<String>>(
            initialValue: selected,
            validator: preview
                ? null
                : (value) {
                    if (field.required && (value == null || value.isEmpty)) {
                      return 'En az bir seçenek işaretleyin';
                    }
                    if (field.options.isEmpty) return 'Seçenek tanımlı değil';
                    return null;
                  },
            builder: (state) {
              if (field.options.isEmpty) {
                return InputDecorator(
                  decoration: InputDecoration(
                    labelText: field.label,
                    errorText: preview ? null : 'En az bir seçenek ekleyin',
                  ),
                  child: const Text('Seçenek yok', style: TextStyle(color: AppColors.muted)),
                );
              }
              return InputDecorator(
                decoration: InputDecoration(
                  labelText: field.label,
                  errorText: state.errorText,
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: field.options.map((option) {
                    final isOn = selected.contains(option);
                    return FilterChip(
                      label: Text(option),
                      selected: isOn,
                      onSelected: preview
                          ? null
                          : (next) {
                              if (next) {
                                selected.add(option);
                              } else {
                                selected.remove(option);
                              }
                              values?[field.id] = List<String>.from(selected);
                              state.didChange(selected);
                              _notify();
                            },
                    );
                  }).toList(),
                ),
              );
            },
          ),
        );
    }
  }

  String _hintFor(FormFieldType type) {
    return switch (type) {
      FormFieldType.number => 'Örn. 42',
      FormFieldType.multiline => 'Uzun açıklama metni…',
      _ => 'Örnek metin',
    };
  }
}
