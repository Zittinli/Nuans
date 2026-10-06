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
    final blocks = splitFormSections(fields);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final block in blocks)
          if (block.header != null)
            _SectionFrame(
              title: block.header!.label,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final field in block.fields)
                    _ClinicFormFieldTile(
                      field: field,
                      values: values,
                      preview: preview,
                      onValuesChanged: onValuesChanged,
                    ),
                  if (block.fields.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('Bu bölümde henüz alan yok.', style: TextStyle(color: AppColors.muted)),
                    ),
                ],
              ),
            )
          else
            for (final field in block.fields)
              _ClinicFormFieldTile(
                field: field,
                values: values,
                preview: preview,
                onValuesChanged: onValuesChanged,
              ),
      ],
    );
  }
}

class _SectionFrame extends StatelessWidget {
  const _SectionFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.28), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: AppColors.primary,
            child: Text(
              title,
              softWrap: true,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15, height: 1.3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _QuestionText extends StatelessWidget {
  const _QuestionText(this.text, {this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
          children: [
            TextSpan(text: text),
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700),
              ),
          ],
        ),
      ),
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
      case FormFieldType.section:
      case FormFieldType.sectionEnd:
        return const SizedBox.shrink();
      case FormFieldType.text:
      case FormFieldType.multiline:
      case FormFieldType.number:
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _QuestionText(field.label, required: field.required),
              TextFormField(
            enabled: !preview,
            initialValue: preview ? '' : '${values?[field.id] ?? ''}',
            minLines: field.type == FormFieldType.multiline ? 3 : 1,
            maxLines: field.type == FormFieldType.multiline ? 6 : 1,
            keyboardType: field.type == FormFieldType.number
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            decoration: InputDecoration(
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
            onChanged: preview
                ? null
                : (value) {
                    values?[field.id] = value;
                    _notify();
                  },
              ),
            ],
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
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _QuestionText(field.label, required: field.required),
                  InkWell(
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
                    errorText: state.errorText,
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
              ),
                ],
              );
            },
          ),
        );
      case FormFieldType.boolean:
        final value = preview ? false : values?[field.id] == true;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _QuestionText(field.label, required: field.required),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Evet'),
                value: value,
                onChanged: preview
                    ? null
                    : (next) {
                        values?[field.id] = next;
                        _notify();
                      },
              ),
            ],
          ),
        );
      case FormFieldType.rating:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FormField<int>(
            initialValue: preview ? null : _ratingOf(values?[field.id]),
            validator: preview
                ? null
                : (value) {
                    if (field.required && value == null) return '1–5 arası puan seçin';
                    return null;
                  },
            builder: (state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _QuestionText(field.label, required: field.required),
                  if (state.errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(state.errorText!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                    ),
                  Row(
                    children: List.generate(5, (index) {
                      final score = index + 1;
                      final selected = state.value == score;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Material(
                            color: selected ? AppColors.primary : AppColors.chip,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: preview
                                  ? null
                                  : () {
                                      state.didChange(score);
                                      values?[field.id] = score;
                                      _notify();
                                    },
                              child: SizedBox(
                                height: 44,
                                child: Center(
                                  child: Text(
                                    '$score',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: selected ? Colors.white : AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        );
      case FormFieldType.singleChoice:
      case FormFieldType.multiChoice:
        return _ChoiceField(
          field: field,
          values: values,
          preview: preview,
          onChanged: _notify,
        );
      case FormFieldType.table:
        return FormTableField(
          field: field,
          values: values,
          preview: preview,
          onChanged: _notify,
        );
    }
  }

  String _hintFor(FormFieldType type) {
    return switch (type) {
      FormFieldType.number => 'Örn. 42',
      FormFieldType.multiline => 'Uzun açıklama metni…',
      FormFieldType.rating => '1–5',
      _ => 'Örnek metin',
    };
  }

  int? _ratingOf(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}

class _ChoiceField extends StatelessWidget {
  const _ChoiceField({
    required this.field,
    required this.values,
    required this.preview,
    required this.onChanged,
  });

  final ClinicFormField field;
  final Map<String, dynamic>? values;
  final bool preview;
  final VoidCallback onChanged;

  bool get _multi => field.type == FormFieldType.multiChoice;

  @override
  Widget build(BuildContext context) {
    final raw = preview ? null : values?[field.id];
    final selected = ChoiceAnswer.selectedIds(raw, field.options);
    final extras = ChoiceAnswer.extrasMap(raw);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FormField<List<String>>(
        initialValue: selected,
        validator: preview
            ? null
            : (value) {
                if (field.required && (value == null || value.isEmpty)) {
                  return _multi ? 'En az bir seçenek işaretleyin' : 'Seçim yapın';
                }
                if (field.options.isEmpty) return 'Seçenek tanımlı değil';
                for (final option in field.options) {
                  if (!option.hasExtra) continue;
                  if (!(value ?? const []).contains(option.id)) continue;
                  final extra = extras[option.id];
                  if (extra == null || '$extra'.trim().isEmpty) {
                    return '"${option.label}" için ek bilgi girin';
                  }
                }
                return null;
              },
        builder: (state) {
          if (field.options.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _QuestionText(field.label, required: field.required),
                const Text('Seçenek yok', style: TextStyle(color: AppColors.muted)),
                if (!preview)
                  const Text('En az bir seçenek ekleyin', style: TextStyle(color: AppColors.danger, fontSize: 12)),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _QuestionText(field.label, required: field.required),
              if (state.errorText != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(state.errorText!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                ),
              for (final option in field.options)
                _OptionRow(
                    option: option,
                    multi: _multi,
                    selected: selected.contains(option.id),
                    extraValue: extras[option.id],
                    preview: preview,
                    onToggle: (on) {
                      final next = List<String>.from(state.value ?? selected);
                      if (_multi) {
                        if (on) {
                          if (!next.contains(option.id)) next.add(option.id);
                        } else {
                          next.remove(option.id);
                          extras.remove(option.id);
                        }
                      } else {
                        next
                          ..clear()
                          ..add(option.id);
                      }
                      _commit(next, extras);
                      state.didChange(next);
                    },
                    onExtra: (value) {
                      extras[option.id] = value;
                      final current = List<String>.from(state.value ?? selected);
                      _commit(current, extras);
                      state.didChange(current);
                    },
                  ),
            ],
          );
        },
      ),
    );
  }

  void _commit(List<String> selected, Map<String, dynamic> extras) {
    values?[field.id] = ChoiceAnswer.encode(selected: selected, extras: extras);
    onChanged();
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.multi,
    required this.selected,
    required this.extraValue,
    required this.preview,
    required this.onToggle,
    required this.onExtra,
  });

  final FormFieldOption option;
  final bool multi;
  final bool selected;
  final dynamic extraValue;
  final bool preview;
  final ValueChanged<bool> onToggle;
  final ValueChanged<dynamic> onExtra;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: preview ? null : () => onToggle(!selected),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (multi)
                  Checkbox(
                    value: selected,
                    onChanged: preview ? null : (value) => onToggle(value ?? false),
                  )
                else
                  Radio<bool>(
                    value: true,
                    groupValue: selected,
                    onChanged: preview ? null : (_) => onToggle(true),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      option.label,
                      softWrap: true,
                      style: const TextStyle(height: 1.35),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (selected && option.hasExtra)
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 4, bottom: 10),
            child: _FollowUpInput(
              type: option.resolvedExtraType,
              value: extraValue,
              preview: preview,
              label: option.isOther ? 'Diğer' : option.resolvedExtraType.label,
              onChanged: onExtra,
            ),
          ),
      ],
    );
  }
}

class _FollowUpInput extends StatelessWidget {
  const _FollowUpInput({
    required this.type,
    required this.value,
    required this.preview,
    required this.label,
    required this.onChanged,
  });

  final FormFieldType type;
  final dynamic value;
  final bool preview;
  final String label;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case FormFieldType.boolean:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: value == true || value == 'true',
          onChanged: preview ? null : onChanged,
        );
      case FormFieldType.date:
        final current = value is String ? value : null;
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
                  onChanged(DateFormat('yyyy-MM-dd').format(selected));
                },
          child: InputDecorator(
            decoration: InputDecoration(labelText: label),
            child: Text(
              current == null || current.isEmpty
                  ? 'Tarih seçin'
                  : DateFormat('d MMMM yyyy', 'tr_TR').format(DateTime.parse(current)),
            ),
          ),
        );
      case FormFieldType.rating:
        final score = value is int ? value : int.tryParse('$value');
        return Row(
          children: List.generate(5, (index) {
            final n = index + 1;
            final on = score == n;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text('$n'),
                selected: on,
                onSelected: preview ? null : (_) => onChanged(n),
              ),
            );
          }),
        );
      case FormFieldType.multiline:
      case FormFieldType.number:
      case FormFieldType.text:
      default:
        return TextFormField(
          enabled: !preview,
          initialValue: value == null ? '' : '$value',
          minLines: type == FormFieldType.multiline ? 2 : 1,
          maxLines: type == FormFieldType.multiline ? 5 : 1,
          keyboardType: type == FormFieldType.number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(labelText: label),
          onChanged: preview ? null : onChanged,
        );
    }
  }
}

class FilledFieldBody extends StatelessWidget {
  const FilledFieldBody({super.key, required this.field, required this.value});

  final ClinicFormField field;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    if (field.type.isTable) {
      return FormTableField(field: field, value: value, readOnly: true);
    }
    return Text(
      formatFormFieldValue(field, value),
      softWrap: true,
      style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
    );
  }
}

class FormTableField extends StatelessWidget {
  const FormTableField({
    super.key,
    required this.field,
    this.values,
    this.value,
    this.preview = false,
    this.readOnly = false,
    this.onChanged,
  });

  final ClinicFormField field;
  final Map<String, dynamic>? values;
  final dynamic value;
  final bool preview;
  final bool readOnly;
  final VoidCallback? onChanged;

  bool get _locked => preview || readOnly;

  List<Map<String, String>> get _rows {
    final raw = readOnly ? value : values?[field.id];
    return TableAnswer.rows(raw);
  }

  void _write(List<Map<String, String>> rows) {
    values?[field.id] = TableAnswer.encode(rows);
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final columns = field.options;
    final rows = _rows;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: FormField<int>(
        initialValue: rows.length,
        validator: preview || readOnly
            ? null
            : (_) {
                if (columns.length < 2) return 'Tabloda en az iki sütun olmalı';
                if (field.required && !rows.any(TableAnswer.rowHasContent)) {
                  return 'En az bir satır doldurun';
                }
                return null;
              },
        builder: (state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _QuestionText(field.label, required: field.required && !readOnly),
              if (columns.isEmpty)
                const Text('Sütun tanımlı değil.', style: TextStyle(color: AppColors.muted))
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          for (final column in columns) _headerCell(column.label),
                          if (!_locked) const SizedBox(width: 40),
                        ],
                      ),
                      if (rows.isEmpty && _locked)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            preview ? 'Doldururken satır eklenebilir.' : 'Satır yok.',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ),
                      for (var index = 0; index < rows.length; index++)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final column in columns)
                              _bodyCell(
                                context,
                                column: column,
                                row: rows[index],
                                onValue: (next) {
                                  final copy = rows.map((item) => Map<String, String>.from(item)).toList();
                                  copy[index][column.id] = next;
                                  _write(copy);
                                  state.didChange(copy.length);
                                },
                              ),
                            if (!_locked)
                              IconButton(
                                tooltip: 'Satırı sil',
                                onPressed: () {
                                  final copy = rows.map((item) => Map<String, String>.from(item)).toList()
                                    ..removeAt(index);
                                  _write(copy);
                                  state.didChange(copy.length);
                                },
                                icon: const Icon(Icons.close, color: AppColors.danger),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              if (!_locked && columns.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      final copy = rows.map((item) => Map<String, String>.from(item)).toList()
                        ..add(TableAnswer.blankRow(columns));
                      _write(copy);
                      state.didChange(copy.length);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Satır ekle'),
                  ),
                ),
              if (state.errorText != null)
                Text(state.errorText!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ],
          );
        },
      ),
    );
  }

  Widget _headerCell(String label) {
    return Container(
      width: 148,
      margin: const EdgeInsets.only(right: 6, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: AppColors.primary,
      child: Text(
        label,
        softWrap: true,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, height: 1.25),
      ),
    );
  }

  Widget _bodyCell(
    BuildContext context, {
    required FormFieldOption column,
    required Map<String, String> row,
    required ValueChanged<String> onValue,
  }) {
    final type = column.extraType ?? FormFieldType.text;
    final raw = row[column.id] ?? '';
    if (_locked) {
      return Container(
        width: 148,
        margin: const EdgeInsets.only(right: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          color: AppColors.surface,
        ),
        child: Text(TableAnswer.cellText(column, raw), softWrap: true),
      );
    }
    if (type == FormFieldType.boolean) {
      return SizedBox(
        width: 148,
        child: Row(
          children: [
            Checkbox(
              value: raw == 'true',
              onChanged: (next) => onValue(next == true ? 'true' : 'false'),
            ),
            const Text('Evet'),
          ],
        ),
      );
    }
    if (type == FormFieldType.date) {
      return SizedBox(
        width: 148,
        child: Padding(
          padding: const EdgeInsets.only(right: 6, bottom: 6),
          child: InkWell(
            onTap: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: DateTime.tryParse(raw) ?? DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
                locale: const Locale('tr', 'TR'),
              );
              if (selected == null) return;
              onValue(DateFormat('yyyy-MM-dd').format(selected));
            },
            child: InputDecorator(
              decoration: const InputDecoration(isDense: true),
              child: Text(raw.isEmpty ? 'Tarih' : raw),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: 148,
      child: Padding(
        padding: const EdgeInsets.only(right: 6, bottom: 6),
        child: TextFormField(
          key: ValueKey('${row[TableAnswer.rowIdKey]}_${column.id}'),
          initialValue: raw,
          keyboardType: type == FormFieldType.number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: const InputDecoration(isDense: true),
          onChanged: onValue,
        ),
      ),
    );
  }
}
