import 'package:flutter/material.dart';

import '../../models/clinic_form.dart';
import '../../theme/app_theme.dart';

/// Tek bir form alanını ekleme / düzenleme ekranı.
class FormFieldEditorScreen extends StatefulWidget {
  const FormFieldEditorScreen({
    super.key,
    this.field,
    required this.newFieldId,
  });

  final ClinicFormField? field;
  final String newFieldId;

  @override
  State<FormFieldEditorScreen> createState() => _FormFieldEditorScreenState();
}

class _FormFieldEditorScreenState extends State<FormFieldEditorScreen> {
  late final TextEditingController _label;
  late FormFieldType _type;
  late bool _required;
  late List<TextEditingController> _optionControllers;

  bool get _isEditing => widget.field != null;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.field?.label ?? '');
    _type = widget.field?.type ?? FormFieldType.text;
    _required = widget.field?.required ?? false;
    final options = widget.field?.options ?? const <String>[];
    _optionControllers = options.isEmpty
        ? [TextEditingController()]
        : options.map((option) => TextEditingController(text: option)).toList();
  }

  @override
  void dispose() {
    _label.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _readOptions() {
    return _optionControllers
        .map((c) => c.text.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  void _addOption() {
    setState(() => _optionControllers.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 1) {
      _optionControllers.first.clear();
      setState(() {});
      return;
    }
    setState(() {
      _optionControllers.removeAt(index).dispose();
    });
  }

  void _save() {
    final label = _label.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alan başlığı gerekli.')),
      );
      return;
    }
    final options = _readOptions();
    if (_type.hasOptions && options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seçim alanları için en az iki seçenek girin.')),
      );
      return;
    }
    Navigator.pop(
      context,
      ClinicFormField(
        id: widget.field?.id ?? widget.newFieldId,
        label: label,
        type: _type,
        required: _required,
        options: _type.hasOptions ? options : const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Alanı düzenle' : 'Yeni alan'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _label,
            textCapitalization: TextCapitalization.sentences,
            autofocus: !_isEditing,
            decoration: const InputDecoration(
              labelText: 'Alan başlığı',
              hintText: 'Örn. Başvuru şikayeti',
            ),
          ),
          const SizedBox(height: 20),
          const Text('Alan türü', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...FormFieldType.values.map((type) {
            final selected = _type == type;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: selected ? AppColors.chip : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() {
                    _type = type;
                    if (!type.hasOptions && _optionControllers.length > 1) {
                      for (var i = 1; i < _optionControllers.length; i++) {
                        _optionControllers[i].dispose();
                      }
                      _optionControllers = [_optionControllers.first];
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(type.icon, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(type.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        if (selected) const Icon(Icons.check_circle, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Zorunlu alan'),
            subtitle: const Text('Form doldurulurken boş bırakılamaz'),
            value: _required,
            onChanged: (value) => setState(() => _required = value),
          ),
          if (_type.hasOptions) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text('Seçenekler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add),
                  label: const Text('Seçenek ekle'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Her satır hasta formunda ayrı bir seçenek olarak görünür.',
              style: TextStyle(color: AppColors.muted, height: 1.35),
            ),
            const SizedBox(height: 12),
            ...List.generate(_optionControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _optionControllers[index],
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Seçenek ${index + 1}',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Seçeneği sil',
                      onPressed: () => _removeOption(index),
                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: Text(_isEditing ? 'Alanı güncelle' : 'Alanı ekle')),
        ],
      ),
    );
  }
}
