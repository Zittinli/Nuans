import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/note.dart';
import '../../models/patient.dart';
import '../../services/clinic_service.dart';
import '../../theme/app_theme.dart';
import '../note/note_form_screen.dart';
import 'patient_form_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({super.key, required this.patient});

  final Patient patient;

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  final _clinic = ClinicService();
  late Patient _patient;

  @override
  void initState() {
    super.initState();
    _patient = widget.patient;
  }

  Future<void> _editPatient() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PatientFormScreen(patient: _patient)),
    );
  }

  Future<void> _deletePatient() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hastayı sil'),
        content: Text('${_patient.fullName} ve tüm notları kalıcı olarak silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _clinic.deletePatient(_patient.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notu sil'),
        content: const Text('Bu klinik not kalıcı olarak silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _clinic.deleteNote(_patient.id, note.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Patient>>(
      stream: _clinic.watchPatients(),
      builder: (context, patientSnap) {
        final latest = patientSnap.data?.where((item) => item.id == _patient.id).firstOrNull;
        if (latest != null) {
          _patient = latest;
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(_patient.fullName),
            actions: [
              IconButton(
                tooltip: 'Düzenle',
                onPressed: _editPatient,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Sil',
                onPressed: _deletePatient,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => NoteFormScreen(patientId: _patient.id)),
              );
            },
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('Yeni not'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              _PatientHeader(patient: _patient),
              const SizedBox(height: 20),
              const Text('Klinik notlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              StreamBuilder<List<Note>>(
                stream: _clinic.watchNotes(_patient.id),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Notlar yüklenemedi: ${snapshot.error}');
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final notes = snapshot.data!;
                  if (notes.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Bu hasta için henüz not yok. Muayene, kontrol veya reçete notu ekleyebilirsiniz.',
                          style: TextStyle(color: AppColors.muted, height: 1.4),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: notes
                        .map(
                          (note) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _NoteCard(
                              note: note,
                              onEdit: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => NoteFormScreen(patientId: _patient.id, note: note),
                                  ),
                                );
                              },
                              onDelete: () => _deleteNote(note),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PatientHeader extends StatelessWidget {
  const _PatientHeader({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.chip,
                  foregroundColor: AppColors.primary,
                  child: Text(patient.initials, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patient.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      Text(
                        [
                          if (patient.age != null) '${patient.age} yaş',
                          patient.gender,
                        ].join(' · '),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (patient.identityNumber != null) _InfoRow(label: 'T.C.', value: patient.identityNumber!),
            if (patient.phone != null) _InfoRow(label: 'Telefon', value: patient.phone!),
            if (patient.diagnosis != null) _InfoRow(label: 'Ön tanı', value: patient.diagnosis!),
            if (patient.birthDate != null)
              _InfoRow(
                label: 'Doğum',
                value: DateFormat('d MMMM yyyy', 'tr_TR').format(patient.birthDate!),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onEdit, required this.onDelete});

  final Note note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(note.type.icon, size: 18, color: AppColors.primaryLight),
                const SizedBox(width: 8),
                Chip(
                  label: Text(note.type.label),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppColors.chip,
                  side: BorderSide.none,
                ),
                const Spacer(),
                Text(
                  DateFormat('d MMM yyyy HH:mm', 'tr_TR').format(note.createdAt),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                    PopupMenuItem(value: 'delete', child: Text('Sil')),
                  ],
                ),
              ],
            ),
            Text(note.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(note.content, style: const TextStyle(height: 1.4, color: AppColors.text)),
          ],
        ),
      ),
    );
  }
}
