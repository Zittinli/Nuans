import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/patient.dart';
import '../../services/clinic_service.dart';
import '../../theme/app_theme.dart';

const _genders = ['Kadın', 'Erkek', 'Diğer', 'Belirtilmedi'];

class PatientFormScreen extends StatefulWidget {
  const PatientFormScreen({super.key, this.patient});

  final Patient? patient;

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clinic = ClinicService();
  late final TextEditingController _fullName;
  late final TextEditingController _identity;
  late final TextEditingController _phone;
  late final TextEditingController _diagnosis;
  late final TextEditingController _referrer;
  DateTime? _birthDate;
  String _gender = 'Belirtilmedi';
  bool _busy = false;

  bool get _isEditing => widget.patient != null;

  @override
  void initState() {
    super.initState();
    final patient = widget.patient;
    _fullName = TextEditingController(text: patient?.fullName ?? '');
    _identity = TextEditingController(text: patient?.identityNumber ?? '');
    _phone = TextEditingController(text: patient?.phone ?? '');
    _diagnosis = TextEditingController(text: patient?.diagnosis ?? '');
    _referrer = TextEditingController(text: patient?.referrer ?? '');
    _birthDate = patient?.birthDate;
    _gender = patient?.gender ?? 'Belirtilmedi';
  }

  @override
  void dispose() {
    _fullName.dispose();
    _identity.dispose();
    _phone.dispose();
    _diagnosis.dispose();
    _referrer.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
      locale: const Locale('tr', 'TR'),
    );
    if (selected != null) {
      setState(() => _birthDate = selected);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final existing = widget.patient;
      final now = DateTime.now();
      final patient = Patient(
        id: existing?.id ?? '',
        fullName: _fullName.text.trim(),
        identityNumber: _emptyToNull(_identity.text),
        birthDate: _birthDate,
        gender: _gender,
        phone: _emptyToNull(_phone.text),
        diagnosis: _emptyToNull(_diagnosis.text),
        referrer: _emptyToNull(_referrer.text),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      await _clinic.savePatient(patient);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hasta kaydedilemedi: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Hastayı düzenle' : 'Yeni hasta')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _fullName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Ad soyad'),
              validator: (value) =>
                  value == null || value.trim().length < 2 ? 'Ad soyad gerekli' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _identity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'T.C. kimlik no (isteğe bağlı)'),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Doğum tarihi'),
                child: Text(
                  _birthDate == null
                      ? 'Seçilmedi'
                      : DateFormat('d MMMM yyyy', 'tr_TR').format(_birthDate!),
                  style: TextStyle(
                    color: _birthDate == null ? AppColors.muted : AppColors.text,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(labelText: 'Cinsiyet'),
              items: _genders
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (value) => setState(() => _gender = value ?? 'Belirtilmedi'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _diagnosis,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Ön tanı',
                hintText: 'İstediğiniz gibi serbest metin yazabilirsiniz',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _referrer,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Hasta yönlendireni',
                hintText: 'Doktor, kurum veya kişi',
              ),
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
                  : Text(_isEditing ? 'Değişiklikleri kaydet' : 'Hastayı kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
