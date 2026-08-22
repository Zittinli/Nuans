import 'package:flutter/material.dart';

import '../../models/note.dart';
import '../../services/clinic_service.dart';
import '../../theme/app_theme.dart';

class NoteFormScreen extends StatefulWidget {
  const NoteFormScreen({super.key, required this.patientId, this.note});

  final String patientId;
  final Note? note;

  @override
  State<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends State<NoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clinic = ClinicService();
  late final TextEditingController _title;
  late final TextEditingController _content;
  late NoteType _type;
  bool _busy = false;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title ?? '');
    _content = TextEditingController(text: widget.note?.content ?? '');
    _type = widget.note?.type ?? NoteType.examination;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final note = Note(
        id: widget.note?.id ?? '',
        title: _title.text.trim(),
        content: _content.text.trim(),
        type: _type,
        createdAt: widget.note?.createdAt ?? now,
        updatedAt: now,
      );
      await _clinic.saveNote(widget.patientId, note);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Not kaydedilemedi: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Notu düzenle' : 'Yeni klinik not')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: NoteType.values.map((type) {
                final selected = type == _type;
                return ChoiceChip(
                  avatar: Icon(type.icon, size: 16, color: selected ? Colors.white : AppColors.primary),
                  label: Text(type.label),
                  selected: selected,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: selected ? Colors.white : AppColors.text),
                  onSelected: (_) => setState(() => _type = type),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Başlık'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Başlık gerekli' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _content,
              minLines: 8,
              maxLines: 16,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Not',
                alignLabelWithHint: true,
                hintText: 'Muayene bulguları, plan, ilaçlar...',
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Not içeriği gerekli' : null,
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
                  : Text(_isEditing ? 'Notu güncelle' : 'Notu kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
