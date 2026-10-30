import 'package:flutter/material.dart';

import '../../models/patient.dart';
import '../../models/patient_media.dart';
import '../../services/clinic_service.dart';
import '../../services/media_upload_queue.dart';
import '../../theme/app_theme.dart';
import 'media_details_dialog.dart';
import 'patient_detail_screen.dart';

class AttachMediaScreen extends StatefulWidget {
  const AttachMediaScreen({super.key, required this.files});

  final List<IncomingMedia> files;

  @override
  State<AttachMediaScreen> createState() => _AttachMediaScreenState();
}

class _AttachMediaScreenState extends State<AttachMediaScreen> {
  final _clinic = ClinicService();
  final _search = TextEditingController();
  var _uploading = false;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _attach(Patient patient) async {
    if (_uploading) return;
    final sessions = await _clinic.watchPatientAppointments(patient.id).first;
    if (!mounted) return;
    final planned = <({IncomingMedia item, MediaDetails details})>[];
    for (final item in widget.files) {
      final details = await showMediaDetailsDialog(
        context: context,
        sessions: sessions,
        suggestedName: item.kind.label,
      );
      if (details == null || !mounted) return;
      planned.add((item: item, details: details));
    }
    setState(() => _uploading = true);
    try {
      for (final plannedItem in planned) {
        final item = plannedItem.item;
        final details = plannedItem.details;
        await MediaUploadQueue.instance.enqueue(
          patientId: patient.id,
          path: item.path,
          fileName: item.name,
          contentType: guessMediaContentType(item.path, item.mime),
          displayName: details.name,
          sessionId: details.session?.id,
          sessionTitle: details.session?.title,
          sessionStartsAt: details.session?.startsAt,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PatientDetailScreen(patient: patient)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya sıraya alınamadı: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.files.first;
    return Scaffold(
      appBar: AppBar(title: const Text('Hastaya ekle')),
      body: StreamBuilder<List<Patient>>(
        stream: _clinic.watchPatients(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Hastalar yüklenemedi: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final query = _query.trim().toLowerCase();
          final patients = snapshot.data!.where((patient) {
            if (query.isEmpty) return true;
            return patient.fullName.toLowerCase().contains(query);
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.files.length == 1
                          ? first.name
                          : '${widget.files.length} dosya · ${first.kind.label}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Bu dosya hangi hastaya eklensin?',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Hasta ara',
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: patients.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Kayıtlı hasta yok. Önce bir hasta ekleyin, sonra dosyayı yeniden paylaşın.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted, height: 1.4),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: patients.length,
                        itemBuilder: (context, index) {
                          final patient = patients[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.chip,
                                foregroundColor: AppColors.primary,
                                child: Text(patient.initials),
                              ),
                              title: Text(patient.fullName),
                              subtitle: Text(patient.diagnosis?.isNotEmpty == true ? patient.diagnosis! : 'Hastaya ekle'),
                              enabled: !_uploading,
                              onTap: () => _attach(patient),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
