import 'package:flutter/material.dart';

import '../../models/clinic_form.dart';
import '../../theme/app_theme.dart';

/// Tek bir form alanını ekleme / düzenleme ekranı.
class FormFieldEditorScreen extends StatefulWidget {
  const FormFieldEditorScreen({
    super.key,
    this.field,
    required this.newFieldId,
    this.initialType,
  });

  final ClinicFormField? field;
  final String newFieldId;
  final FormFieldType? initialType;

  @override
  State<FormFieldEditorScreen> createState() => _FormFieldEditorScreenState();
}

class _OptionDraft {
  _OptionDraft({
    required this.id,
    String label = '',
    this.isOther = false,
    this.extraType,
  }) : label = TextEditingController(text: label);

  final String id;
  final TextEditingController label;
  bool isOther;
  FormFieldType? extraType;

  void dispose() => label.dispose();
}

class _FormFieldEditorScreenState extends State<FormFieldEditorScreen> {
  late final TextEditingController _label;
  late FormFieldType _type;
  late bool _required;
  late List<_OptionDraft> _options;

  bool get _isEditing => widget.field != null;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.field?.label ?? '');
    _type = widget.field?.type ?? widget.initialType ?? FormFieldType.text;
    _required = widget.field?.required ?? false;
    final existing = widget.field?.options ?? const <FormFieldOption>[];
    _options = existing.isEmpty
        ? [_OptionDraft(id: _newOptionId())]
        : existing
            .map(
              (option) => _OptionDraft(
                id: option.id,
                label: option.label,
                isOther: option.isOther,
                extraType: option.extraType,
              ),
            )
            .toList();
  }

  @override
  void dispose() {
    _label.dispose();
    for (final option in _options) {
      option.dispose();
    }
    super.dispose();
  }

  String _newOptionId() => 'opt_${DateTime.now().microsecondsSinceEpoch}';

  List<FormFieldOption> _readOptions() {
    return _options
        .map(
          (item) => FormFieldOption(
            id: item.id,
            label: item.label.text.trim(),
            isOther: _type.isTable ? false : item.isOther,
            extraType: _type.isTable
                ? (item.extraType ?? FormFieldType.text)
                : item.isOther
                    ? (item.extraType ?? FormFieldType.text)
                    : item.extraType,
          ),
        )
        .where((item) => item.label.isNotEmpty)
        .toList();
  }

  void _addOption() {
    setState(() => _options.add(_OptionDraft(
          id: _newOptionId(),
          extraType: _type.isTable ? FormFieldType.text : null,
        )));
  }

  void _removeOption(int index) {
    if (_options.length <= 1) {
      _options.first.label.clear();
      _options.first.isOther = false;
      _options.first.extraType = null;
      setState(() {});
      return;
    }
    setState(() {
      _options.removeAt(index).dispose();
    });
  }

  void _save() {
    final label = _label.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_type.isSection ? 'Bölüm başlığı gerekli.' : 'Alan başlığı gerekli.')),
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
    if (_type.isTable && options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tablo için en az iki sütun girin.')),
      );
      return;
    }
    Navigator.pop(
      context,
      ClinicFormField(
        id: widget.field?.id ?? widget.newFieldId,
        label: label,
        type: _type,
        required: _type.isSection ? false : _required,
        options: (_type.hasOptions || _type.isTable) ? options : const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? (_type.isTable ? 'Tabloyu düzenle' : _type.isSection ? 'Bölümü düzenle' : 'Alanı düzenle')
              : (_type.isTable ? 'Yeni tablo' : _type.isSection ? 'Yeni bölüm' : 'Yeni alan'),
        ),
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
            decoration: InputDecoration(
              labelText: _type.isTable ? 'Tablo başlığı' : _type.isSection ? 'Bölüm başlığı' : 'Alan başlığı',
              hintText: _type.isTable
                  ? 'Örn. Kullandığı ilaçlar'
                  : _type.isSection
                      ? 'Örn. Özgeçmiş'
                      : _type == FormFieldType.likert
                          ? 'Örn. Kaygı düzeyi'
                          : 'Örn. Başvuru şikayeti',
            ),
          ),
          const SizedBox(height: 20),
          const Text('Alan türü', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...FormFieldType.values.where((type) => !type.isSectionEnd).map((type) {
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
                    if (type.isTable) {
                      while (_options.length < 2) {
                        _options.add(_OptionDraft(id: _newOptionId(), extraType: FormFieldType.text));
                      }
                      for (final option in _options) {
                        option.isOther = false;
                        option.extraType ??= FormFieldType.text;
                      }
                    } else if (!type.hasOptions && _options.length > 1) {
                      for (var i = 1; i < _options.length; i++) {
                        _options[i].dispose();
                      }
                      _options = [_options.first];
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
          if (_type == FormFieldType.likert) ...[
            const SizedBox(height: 8),
            const Text(
              'Hasta 1 ile 5 arasında işaretler. 1 hiç hissetmiyorum, 5 çok hissediyorum anlamına gelir.',
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ],
          if (_type.isSection) ...[
            const SizedBox(height: 8),
            const Text(
              'Kaydedince hemen altına bir kapanış eklenir. Yalnızca açılış ile kapanış arasına taşıdığın alanlar bu bölümün içinde görünür.',
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ] else
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Zorunlu alan'),
              subtitle: const Text('Form doldurulurken boş bırakılamaz'),
              value: _required,
              onChanged: (value) => setState(() => _required = value),
            ),
          if (_type.hasOptions || _type.isTable) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _type.isTable ? 'Sütunlar' : 'Seçenekler',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add),
                  label: Text(_type.isTable ? 'Sütun ekle' : 'Seçenek ekle'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _type.isTable
                  ? 'Her satır bir sütun başlığıdır. Hücre türünü metin, sayı, tarih veya evet/hayır olarak seçebilirsin.'
                  : 'Her seçenek ayrı durur. “Diğer” işaretlersen o satıra istediğin alan türünü bağlayabilirsin (sayı, metin, tarih…).',
              style: const TextStyle(color: AppColors.muted, height: 1.35),
            ),
            const SizedBox(height: 12),
            ...List.generate(_options.length, (index) {
              final option = _options[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: option.label,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                labelText: _type.isTable ? 'Sütun ${index + 1}' : 'Seçenek ${index + 1}',
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
                      if (!_type.isTable)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('Diğer'),
                          subtitle: const Text('Seçilince ek alan açılır'),
                          value: option.isOther,
                          onChanged: (value) => setState(() {
                            option.isOther = value;
                            if (value && option.extraType == null) {
                              option.extraType = FormFieldType.text;
                            }
                          }),
                        ),
                      _TypeChoice(
                        label: _type.isTable ? 'Hücre türü' : 'Bu seçeneğin alan türü',
                        value: _type.isTable ? (option.extraType ?? FormFieldType.text) : option.extraType,
                        allowNone: !_type.isTable,
                        choices: _type.isTable ? FormFieldType.columnTypes : FormFieldType.extraChoices,
                        onChanged: (value) => setState(() => option.extraType = value),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: Text(
              _isEditing
                  ? (_type.isTable ? 'Tabloyu güncelle' : _type.isSection ? 'Bölümü güncelle' : 'Alanı güncelle')
                  : (_type.isTable ? 'Tabloyu ekle' : _type.isSection ? 'Bölümü ekle' : 'Alanı ekle'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypePick {
  const _TypePick(this.type);
  final FormFieldType? type;
}

class _TypeChoice extends StatelessWidget {
  const _TypeChoice({
    required this.label,
    required this.value,
    required this.allowNone,
    required this.choices,
    required this.onChanged,
  });

  final String label;
  final FormFieldType? value;
  final bool allowNone;
  final List<FormFieldType> choices;
  final ValueChanged<FormFieldType?> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = value != null && choices.contains(value) ? value : (allowNone ? null : FormFieldType.text);
    return InkWell(
      onTap: () async {
        final picked = await showDialog<_TypePick>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(label),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (allowNone)
                    ListTile(
                      title: const Text('Yalnızca seçim (ek alan yok)'),
                      onTap: () => Navigator.pop(dialogContext, const _TypePick(null)),
                    ),
                  for (final type in choices)
                    ListTile(
                      title: Text(type.label),
                      onTap: () => Navigator.pop(dialogContext, _TypePick(type)),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
            ],
          ),
        );
        if (picked == null) return;
        onChanged(picked.type);
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(current == null ? 'Yalnızca seçim (ek alan yok)' : current.label),
      ),
    );
  }
}
