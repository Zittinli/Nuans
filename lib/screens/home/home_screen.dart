import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/doctor.dart';
import '../../models/patient.dart';
import '../../services/auth_service.dart';
import '../../services/clinic_service.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_home_screen.dart';
import '../auth/change_password_screen.dart';
import '../calendar/clinic_calendar_screen.dart';
import '../form/form_template_editor_screen.dart';
import '../form/form_management_screen.dart';
import '../patient/patient_detail_screen.dart';
import '../patient/patient_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = AuthService();
  final _clinic = ClinicService();
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Patient> _filter(List<Patient> patients) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return patients;
    return patients.where((patient) {
      return patient.fullName.toLowerCase().contains(q) ||
          (patient.identityNumber ?? '').contains(q) ||
          (patient.phone ?? '').contains(q) ||
          (patient.diagnosis ?? '').toLowerCase().contains(q) ||
          (patient.referrer ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openProfile(Doctor? doctor) async {
    final user = _auth.currentUser;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                doctor?.fullName.isNotEmpty == true
                    ? doctor!.fullName
                    : user?.displayName ?? 'Doktor',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(user?.email ?? '', style: const TextStyle(color: AppColors.muted)),
              if (doctor?.canAccessAdmin == true) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
                    );
                  },
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('Yönetim paneli'),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FormTemplateEditorScreen()),
                  );
                },
                icon: const Icon(Icons.post_add_outlined),
                label: const Text('Form ekle'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FormManagementScreen(initialTab: FormManagementTab.active),
                    ),
                  );
                },
                icon: const Icon(Icons.checklist_outlined),
                label: const Text('Aktif formlar'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FormManagementScreen(initialTab: FormManagementTab.all),
                    ),
                  );
                },
                icon: const Icon(Icons.description_outlined),
                label: const Text('Formları görüntüle ve düzenle'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                  );
                },
                icon: const Icon(Icons.lock_reset_outlined),
                label: const Text('Şifre değiştir'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _auth.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Çıkış yap'),
              ),
            ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Doctor?>(
      stream: _auth.watchProfile(),
      builder: (context, profileSnap) {
        final doctor = profileSnap.data;
        final greetingName = doctor?.fullName.split(' ').first ??
            _auth.currentUser?.displayName?.split(' ').first ??
            'Doktor';

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Merhaba, $greetingName', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
                const Text('Hastalarım'),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Takvim',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ClinicCalendarScreen()),
                  );
                },
                icon: const Icon(Icons.calendar_month_outlined),
              ),
              IconButton(
                tooltip: 'Profil',
                onPressed: () => _openProfile(doctor),
                icon: const Icon(Icons.account_circle_outlined),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PatientFormScreen()),
              );
            },
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Yeni hasta'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Ad, T.C., telefon, tanı veya yönlendiren ara',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Patient>>(
                  stream: _clinic.watchPatients(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Kayıtlar yüklenemedi: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final patients = _filter(snapshot.data!);
                    if (snapshot.data!.isEmpty) {
                      return const _EmptyState(
                        title: 'Henüz hasta yok',
                        message: 'İlk hasta kaydınızı oluşturarak not almaya başlayın.',
                      );
                    }
                    if (patients.isEmpty) {
                      return const _EmptyState(
                        title: 'Sonuç bulunamadı',
                        message: 'Arama kriterlerinizi değiştirip tekrar deneyin.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: patients.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final patient = patients[index];
                        return _PatientCard(patient: patient);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final ageText = patient.age == null ? patient.gender : '${patient.age} yaş · ${patient.gender}';
    final updated = DateFormat('d MMM yyyy', 'tr_TR').format(patient.updatedAt);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PatientDetailScreen(patient: patient)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.chip,
                foregroundColor: AppColors.primary,
                child: Text(patient.initials, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(ageText, style: const TextStyle(color: AppColors.muted)),
                    if (patient.diagnosis?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        patient.diagnosis!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.primaryLight),
                      ),
                    ],
                    if (patient.referrer?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Yönlendiren: ${patient.referrer}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(updated, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 8),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_shared_outlined, size: 56, color: AppColors.primaryLight),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
