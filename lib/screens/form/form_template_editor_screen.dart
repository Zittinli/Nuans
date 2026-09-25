import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/clinic_form.dart';
import '../../services/clinic_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/form_attachment.dart';
import '../../widgets/clinic_form_fields.dart';
import 'form_field_editor_screen.dart';

/// Yeni form oluşturma ve mevcut şablon düzenleme için ortak düzenleyici.
class FormTemplateEditorScreen extends StatefulWidget {
  const FormTemplateEditorScreen({super.key, this.template});

  final ClinicFormTemplate? template;

  bool get isEditing => template != null;

  @override
  State<FormTemplateEditorScreen> createState() => _FormTemplateEditorScreenState();
}

class _FormTemplateEditorScreenState extends State<FormTemplateEditorScreen>
    with SingleTickerProviderStateMixin {
  final _clinic = ClinicService();
  late final TabController _tabs;
  late final TextEditingController _name;
  late final TextEditingController _description;
  late List<ClinicFormField> _fields;

  bool _busy = false;
  bool _dirty = false;
  bool _active = true;
  String? _pendingSourcePath;
  String? _pendingSourceName;
  FormSourceKind? _pendingSourceKind;
  String? _sourceFileUrl;
  String? _sourceFileName;
  FormSourceKind? _sourceFileKind;

  String? _initialSnapshot;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this)..addListener(() => setState(() {}));
    _name = TextEditingController(text: widget.template?.name ?? '');
    _description = TextEditingController(text: widget.template?.description ?? '');
    _fields = [...?widget.template?.fields];
    _active = widget.template?.active ?? true;
    _sourceFileUrl = widget.template?.sourceFileUrl;
    _sourceFileName = widget.template?.sourceFileName;
    _sourceFileKind = widget.template?.sourceFileKind;
    _name.addListener(_markDirty);
    _description.addListener(_markDirty);
    _initialSnapshot = _snapshot();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  String _snapshot() {
    return [
      _name.text,
      _description.text,
      _active,
      _fields.map((f) => '${f.id}|${f.label}|${f.type.name}|${f.required}|${f.options.join(',')}').join(';'),
      _pendingSourcePath ?? '',
      _sourceFileUrl ?? '',
    ].join('::');
  }

  bool get _hasUnsavedChanges => _dirty || _snapshot() != _initialSnapshot;

  String _newFieldId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<bool> _confirmDiscard() async {
    if (!_hasUnsavedChanges) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydedilmemiş değişiklikler'),
        content: const Text('Form düzenleyiciden çıkarsanız yaptığınız değişiklikler kaybolur.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Kal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Çık')),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _pickSourceFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final path = file.path;
    if (path == null) return;
    final ext = file.extension?.toLowerCase();
    setState(() {
      _pendingSourcePath = path;
      _pendingSourceName = file.name;
      _pendingSourceKind = ext == 'pdf' ? FormSourceKind.pdf : FormSourceKind.word;
      _dirty = true;
    });
  }

  void _clearSourceFile() {
    setState(() {
      _pendingSourcePath = null;
      _pendingSourceName = null;
      _pendingSourceKind = null;
      _sourceFileUrl = null;
      _sourceFileName = null;
      _sourceFileKind = null;
      _dirty = true;
    });
  }

  Future<void> _openFieldEditor([ClinicFormField? existing]) async {
    final result = await Navigator.of(context).push<ClinicFormField>(
      MaterialPageRoute(
        builder: (_) => FormFieldEditorScreen(
          field: existing,
          newFieldId: _newFieldId(),
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      final index = _fields.indexWhere((item) => item.id == result.id);
      if (index >= 0) {
        _fields[index] = result;
      } else {
        _fields.add(result);
      }
      _dirty = true;
    });
  }

  void _duplicateField(ClinicFormField field) {
    setState(() {
      _fields.add(
        ClinicFormField(
          id: _newFieldId(),
          label: '${field.label} (kopya)',
          type: field.type,
          required: field.required,
          options: [...field.options],
        ),
      );
      _dirty = true;
    });
  }

  void _moveField(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _fields.length) return;
    setState(() {
      final item = _fields.removeAt(index);
      _fields.insert(target, item);
      _dirty = true;
    });
  }

  void _removeField(int index) {
    setState(() {
      _fields.removeAt(index);
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Form adı gerekli.')),
      );
      _tabs.animateTo(0);
      return;
    }
    final hasSource = _pendingSourcePath != null || (_sourceFileUrl?.isNotEmpty == true);
    if (_fields.isEmpty && !hasSource) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir alan ekleyin veya PDF/Word dosyası yükleyin.')),
      );
      _tabs.animateTo(1);
      return;
    }
    for (final field in _fields) {
      if (field.type.hasOptions && field.options.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${field.label}" alanında en az iki seçenek olmalı.')),
        );
        _tabs.animateTo(1);
        return;
      }
    }

    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      var template = ClinicFormTemplate(
        id: widget.template?.id ?? '',
        name: _name.text.trim(),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        fields: _fields,
        active: _active,
        sourceFileUrl: _sourceFileUrl,
        sourceFileName: _sourceFileName,
        sourceFileKind: _sourceFileKind,
        createdAt: widget.template?.createdAt ?? now,
        updatedAt: now,
      );
      final id = await _clinic.saveFormTemplate(template);
      if (_pendingSourcePath != null && _pendingSourceName != null) {
        final url = await _clinic.uploadFormTemplateSource(
          templateId: id,
          file: File(_pendingSourcePath!),
          fileName: _pendingSourceName!,
        );
        template = ClinicFormTemplate(
          id: id,
          name: template.name,
          description: template.description,
          fields: template.fields,
          active: template.active,
          sourceFileUrl: url,
          sourceFileName: _pendingSourceName,
          sourceFileKind: _pendingSourceKind,
          createdAt: template.createdAt,
          updatedAt: DateTime.now(),
        );
        await _clinic.saveFormTemplate(template);
      }
      if (!mounted) return;
      _initialSnapshot = _snapshot();
      _dirty = false;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isEditing ? 'Form güncellendi.' : 'Form oluşturuldu.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Form kaydedilemedi: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  ClinicFormTemplate get _previewTemplate => ClinicFormTemplate(
        id: widget.template?.id ?? 'preview',
        name: _name.text.trim().isEmpty ? 'Form adı' : _name.text.trim(),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        fields: _fields,
        active: _active,
        sourceFileUrl: _sourceFileUrl,
        sourceFileName: _pendingSourceName ?? _sourceFileName,
        sourceFileKind: _pendingSourceKind ?? _sourceFileKind,
        createdAt: widget.template?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmDiscard()) {
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Formu düzenle' : 'Yeni form'),
          bottom: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Genel'),
              Tab(text: 'Alanlar'),
              Tab(text: 'Önizleme'),
            ],
          ),
          actions: [
            if (_hasUnsavedChanges)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Center(
                  child: Text('Kaydedilmedi', style: TextStyle(fontSize: 12, color: Colors.white70)),
                ),
              ),
            TextButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Kaydet', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabs,
          children: [
            _GeneralTab(
              name: _name,
              description: _description,
              active: _active,
              busy: _busy,
              pendingSourceName: _pendingSourceName,
              sourceFileName: _sourceFileName,
              sourceFileUrl: _sourceFileUrl,
              sourceFileKind: _sourceFileKind,
              pendingSourcePath: _pendingSourcePath,
              onActiveChanged: (value) => setState(() {
                _active = value;
                _dirty = true;
              }),
              onPickSource: _pickSourceFile,
              onClearSource: _clearSourceFile,
              onViewSource: widget.template == null && _sourceFileUrl == null
                  ? null
                  : () {
                      openFormSourceFile(
                        context: context,
                        template: _previewTemplate,
                      );
                    },
              fieldCount: _fields.length,
              hasSourceFile: _pendingSourcePath != null || _sourceFileUrl != null,
            ),
            _FieldsTab(
              fields: _fields,
              onAdd: () => _openFieldEditor(),
              onEdit: _openFieldEditor,
              onDuplicate: _duplicateField,
              onRemove: _removeField,
              onMove: _moveField,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  var target = newIndex;
                  if (oldIndex < target) target--;
                  final item = _fields.removeAt(oldIndex);
                  _fields.insert(target, item);
                  _dirty = true;
                });
              },
            ),
            _PreviewTab(template: _previewTemplate),
          ],
        ),
        floatingActionButton: _tabs.index == 1
            ? FloatingActionButton.extended(
                onPressed: () => _openFieldEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Alan ekle'),
              )
            : null,
      ),
    );
  }
}

class _GeneralTab extends StatelessWidget {
  const _GeneralTab({
    required this.name,
    required this.description,
    required this.active,
    required this.busy,
    required this.pendingSourceName,
    required this.sourceFileName,
    required this.sourceFileUrl,
    required this.sourceFileKind,
    required this.pendingSourcePath,
    required this.onActiveChanged,
    required this.onPickSource,
    required this.onClearSource,
    required this.onViewSource,
    required this.fieldCount,
    required this.hasSourceFile,
  });

  final TextEditingController name;
  final TextEditingController description;
  final bool active;
  final bool busy;
  final String? pendingSourceName;
  final String? sourceFileName;
  final String? sourceFileUrl;
  final FormSourceKind? sourceFileKind;
  final String? pendingSourcePath;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onPickSource;
  final VoidCallback onClearSource;
  final VoidCallback? onViewSource;
  final int fieldCount;
  final bool hasSourceFile;

  @override
  Widget build(BuildContext context) {
    final displayFileName = pendingSourceName ?? sourceFileName;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: name,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Form adı',
            hintText: 'Örn. Anamnez formu',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: description,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Açıklama (isteğe bağlı)',
            hintText: 'Hastaya veya personele kısa not',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Aktif form'),
          subtitle: const Text('Hasta detayında form seçim listesinde görünsün'),
          value: active,
          onChanged: onActiveChanged,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Özet', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('$fieldCount alan · ${hasSourceFile ? 'Kaynak dosya var' : 'Kaynak dosya yok'}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text('PDF / Word', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
          'Klinikte kullandığınız kağıt formun dijital kopyasını ekleyebilirsiniz. Alanlar sekmesindeki sorular buna ek olarak doldurulur.',
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      sourceFileKind == FormSourceKind.pdf
                          ? Icons.picture_as_pdf_outlined
                          : Icons.description_outlined,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        displayFileName ?? 'Henüz dosya seçilmedi',
                        style: TextStyle(
                          color: displayFileName == null ? AppColors.muted : null,
                        ),
                      ),
                    ),
                  ],
                ),
                if (pendingSourcePath != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Kayıtta yüklenecek', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: busy ? null : onPickSource,
                      icon: const Icon(Icons.upload_file),
                      label: Text(displayFileName == null ? 'Dosya seç' : 'Dosyayı değiştir'),
                    ),
                    if (hasSourceFile)
                      TextButton(onPressed: onClearSource, child: const Text('Kaldır')),
                    if (sourceFileUrl != null && onViewSource != null)
                      TextButton.icon(
                        onPressed: onViewSource,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Görüntüle'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldsTab extends StatelessWidget {
  const _FieldsTab({
    required this.fields,
    required this.onAdd,
    required this.onEdit,
    required this.onDuplicate,
    required this.onRemove,
    required this.onMove,
    required this.onReorder,
  });

  final List<ClinicFormField> fields;
  final VoidCallback onAdd;
  final void Function(ClinicFormField field) onEdit;
  final void Function(ClinicFormField field) onDuplicate;
  final void Function(int index) onRemove;
  final void Function(int index, int delta) onMove;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Form alanları',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kısa metin, tarih, evet/hayır veya çoktan seçmeli alanlar ekleyin. Sıralamayı sürükleyerek değiştirebilirsiniz.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('İlk alanı ekle')),
        ],
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      itemCount: fields.length,
      onReorder: onReorder,
      itemBuilder: (context, index) {
        final field = fields[index];
        final optionWarning = field.type.hasOptions && field.options.length < 2;
        return Card(
          key: ValueKey(field.id),
          margin: const EdgeInsets.only(bottom: 10),
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.chip,
                  child: Icon(field.type.icon, color: AppColors.primary, size: 20),
                ),
                title: Text(field.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  [
                    field.type.label,
                    if (field.required) 'zorunlu',
                    if (field.type.hasOptions) '${field.options.length} seçenek',
                    if (optionWarning) 'seçenek eksik',
                  ].join(' · '),
                  style: TextStyle(color: optionWarning ? AppColors.danger : AppColors.muted),
                ),
                trailing: const Icon(Icons.drag_handle),
                onTap: () => onEdit(field),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Yukarı taşı',
                      onPressed: index == 0 ? null : () => onMove(index, -1),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: 'Aşağı taşı',
                      onPressed: index == fields.length - 1 ? null : () => onMove(index, 1),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    IconButton(
                      tooltip: 'Düzenle',
                      onPressed: () => onEdit(field),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Kopyala',
                      onPressed: () => onDuplicate(field),
                      icon: const Icon(Icons.copy_outlined),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Sil',
                      onPressed: () => onRemove(index),
                      icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewTab extends StatelessWidget {
  const _PreviewTab({required this.template});

  final ClinicFormTemplate template;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(template.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        if (template.description?.isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text(template.description!, style: const TextStyle(height: 1.4)),
        ],
        if (template.hasSourceFile || template.sourceFileName != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: null,
            icon: Icon(
              template.sourceFileKind == FormSourceKind.pdf
                  ? Icons.picture_as_pdf_outlined
                  : Icons.description_outlined,
            ),
            label: Text(template.sourceFileName ?? 'Kaynak dosya'),
          ),
        ],
        const SizedBox(height: 8),
        const Text(
          'Hasta formu doldururken alanlar böyle görünür (önizleme).',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        ClinicFormFieldsSection(fields: template.fields, preview: true),
      ],
    );
  }
}
