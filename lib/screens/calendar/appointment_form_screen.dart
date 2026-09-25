import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/appointment.dart';
import '../../models/patient.dart';
import '../../services/clinic_service.dart';
import '../../theme/app_theme.dart';

class AppointmentFormScreen extends StatefulWidget {
  const AppointmentFormScreen({
    super.key,
    this.patient,
    this.appointment,
    this.initialDay,
  });

  final Patient? patient;
  final Appointment? appointment;
  final DateTime? initialDay;

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clinic = ClinicService();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  Patient? _patient;
  DateTime _day = DateTime.now();
  TimeOfDay _start = TimeOfDay.now();
  TimeOfDay _end = TimeOfDay.now().replacing(minute: (TimeOfDay.now().minute + 30) % 60);
  bool _busy = false;

  bool get _isEditing => widget.appointment != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.appointment;
    _patient = widget.patient;
    _title = TextEditingController(text: existing?.title ?? 'Görüşme');
    _notes = TextEditingController(text: existing?.notes ?? '');
    if (existing != null) {
      _day = existing.startsAt;
      _start = TimeOfDay.fromDateTime(existing.startsAt);
      _end = TimeOfDay.fromDateTime(existing.endsAt);
    } else if (widget.initialDay != null) {
      _day = widget.initialDay!;
      final now = TimeOfDay.now();
      _start = now;
      _end = TimeOfDay(hour: now.hour, minute: (now.minute + 30) % 60);
      if (now.minute + 30 >= 60) {
        _end = TimeOfDay(hour: (now.hour + 1) % 24, minute: (now.minute + 30) % 60);
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  DateTime _combine(DateTime day, TimeOfDay time) {
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  Future<void> _save(List<Patient> patients) async {
    if (!_formKey.currentState!.validate()) return;
    final patient = _patient ?? patients.where((item) => item.id == widget.appointment?.patientId).firstOrNull;
    if (patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hasta seçin.')),
      );
      return;
    }
    final startsAt = _combine(_day, _start);
    var endsAt = _combine(_day, _end);
    if (!endsAt.isAfter(startsAt)) {
      endsAt = startsAt.add(const Duration(minutes: 30));
    }
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      await _clinic.saveAppointment(
        Appointment(
          id: widget.appointment?.id ?? '',
          patientId: patient.id,
          patientName: patient.fullName,
          startsAt: startsAt,
          endsAt: endsAt,
          title: _title.text.trim().isEmpty ? 'Görüşme' : _title.text.trim(),
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          createdAt: widget.appointment?.createdAt ?? now,
          updatedAt: now,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Görüşme kaydedilemedi: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Patient>>(
      stream: _clinic.watchPatients(),
      builder: (context, snapshot) {
        final patients = snapshot.data ?? const <Patient>[];
        return Scaffold(
          appBar: AppBar(title: Text(_isEditing ? 'Görüşmeyi düzenle' : 'Yeni görüşme')),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (widget.patient == null)
                  DropdownButtonFormField<String>(
                    value: patients.any((item) => item.id == (_patient?.id ?? widget.appointment?.patientId))
                        ? (_patient?.id ?? widget.appointment?.patientId)
                        : null,
                    decoration: const InputDecoration(labelText: 'Hasta'),
                    items: patients
                        .map(
                          (item) => DropdownMenuItem(value: item.id, child: Text(item.fullName)),
                        )
                        .toList(),
                    onChanged: (id) {
                      setState(() {
                        _patient = patients.where((item) => item.id == id).firstOrNull;
                      });
                    },
                    validator: (value) => value == null || value.isEmpty ? 'Hasta seçin' : null,
                  )
                else
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Hasta'),
                    child: Text(widget.patient!.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Başlık'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tarih'),
                  subtitle: Text(DateFormat('d MMMM yyyy', 'tr_TR').format(_day)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: _day,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                      locale: const Locale('tr', 'TR'),
                    );
                    if (selected != null) setState(() => _day = selected);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Başlangıç saati'),
                  subtitle: Text(_start.format(context)),
                  trailing: const Icon(Icons.schedule),
                  onTap: () async {
                    final selected = await showTimePicker(context: context, initialTime: _start);
                    if (selected != null) setState(() => _start = selected);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bitiş saati'),
                  subtitle: Text(_end.format(context)),
                  trailing: const Icon(Icons.schedule_outlined),
                  onTap: () async {
                    final selected = await showTimePicker(context: context, initialTime: _end);
                    if (selected != null) setState(() => _end = selected);
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Not (isteğe bağlı)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : () => _save(patients),
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isEditing ? 'Görüşmeyi güncelle' : 'Görüşmeyi kaydet'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Saatler takvimde hasta adı ve görüşme başlığıyla görünür.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
