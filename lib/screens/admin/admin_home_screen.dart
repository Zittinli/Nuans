import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_permission.dart';
import '../../models/clinic_form.dart';
import '../../models/doctor.dart';
import '../../models/note.dart';
import '../../models/patient.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../form/form_template_editor_screen.dart';
import '../../utils/form_pack.dart';
import '../../services/clinic_service.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return StreamBuilder<Doctor?>(
      stream: auth.watchProfile(),
      builder: (context, snapshot) {
        final actor = snapshot.data;
        if (actor == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!actor.canAccessAdmin) {
          return Scaffold(
            appBar: AppBar(title: const Text('Yönetim')),
            body: const Center(child: Text('Bu bölüme erişim yetkiniz yok.')),
          );
        }

        final tabs = <Tab>[
          if (actor.canViewAllAccounts || actor.canManagePermissions) const Tab(text: 'Hesaplar'),
          if (actor.canManageDefaultForms) const Tab(text: 'Varsayılan formlar'),
        ];

        if (tabs.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Yönetim')),
            body: const Center(child: Text('Bu bölüme erişim yetkiniz yok.')),
          );
        }

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Yönetim'),
              bottom: TabBar(tabs: tabs),
            ),
            body: TabBarView(
              children: [
                if (actor.canViewAllAccounts || actor.canManagePermissions)
                  _AccountsTab(actor: actor),
                if (actor.canManageDefaultForms) const _DefaultFormsTab(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AccountsTab extends StatefulWidget {
  const _AccountsTab({required this.actor});

  final Doctor actor;

  @override
  State<_AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<_AccountsTab> {
  final _admin = AdminService();
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Ad veya e-posta ara',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Doctor>>(
            stream: _admin.watchAccounts(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Hesaplar yüklenemedi: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final q = _query.trim().toLowerCase();
              final accounts = snapshot.data!.where((item) {
                if (q.isEmpty) return true;
                return item.fullName.toLowerCase().contains(q) ||
                    item.email.toLowerCase().contains(q);
              }).toList();
              if (accounts.isEmpty) {
                return const Center(child: Text('Kayıtlı hesap bulunamadı.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: accounts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final doctor = accounts[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.chip,
                        foregroundColor: AppColors.primary,
                        child: Text(
                          doctor.fullName.isEmpty
                              ? '?'
                              : doctor.fullName.trim().split(RegExp(r'\s+')).first[0].toUpperCase(),
                        ),
                      ),
                      title: Text(doctor.fullName.isEmpty ? doctor.email : doctor.fullName),
                      subtitle: Text(
                        [
                          doctor.email,
                          if (doctor.isSuperAdmin) 'Tam yetkili yönetici',
                          if (!doctor.isSuperAdmin && doctor.permissions.isNotEmpty)
                            '${doctor.permissions.length} yetki',
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdminAccountDetailScreen(
                              actor: widget.actor,
                              accountId: doctor.id,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DefaultFormsTab extends StatelessWidget {
  const _DefaultFormsTab();

  @override
  Widget build(BuildContext context) {
    final clinic = ClinicService();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const FormTemplateEditorScreen(asGlobal: true),
            ),
          );
        },
        icon: const Icon(Icons.post_add_outlined),
        label: const Text('Varsayılan form'),
      ),
      body: StreamBuilder<List<ClinicFormTemplate>>(
        stream: clinic.watchGlobalFormTemplates(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Formlar yüklenemedi: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final templates = snapshot.data!;
          if (templates.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Henüz varsayılan form yok. Eklediğiniz formlar tüm hesaplarda görünür.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, height: 1.45),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: templates.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final template = templates[index];
              return Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(template.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        [
                          if (template.description?.isNotEmpty == true) template.description!,
                          '${template.fields.length} alan',
                          if (!template.active) 'pasif',
                        ].join(' · '),
                      ),
                      trailing: IconButton(
                        tooltip: 'Düzenle',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FormTemplateEditorScreen(
                                template: template,
                                asGlobal: true,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Tüm hesaplarda göster'),
                      value: template.active,
                      onChanged: (value) => clinic.setFormTemplateActive(template, value),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Varsayılan formu kaldır'),
                              content: Text(
                                '"${template.name}" tüm hesapların form listesinden kaldırılsın mı?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Vazgeç'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                                  child: const Text('Kaldır'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await clinic.deleteFormTemplate(template);
                          }
                        },
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                        label: const Text('Kaldır', style: TextStyle(color: AppColors.danger)),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AdminAccountDetailScreen extends StatelessWidget {
  const AdminAccountDetailScreen({
    super.key,
    required this.actor,
    required this.accountId,
  });

  final Doctor actor;
  final String accountId;

  @override
  Widget build(BuildContext context) {
    final admin = AdminService();
    return StreamBuilder<List<Doctor>>(
      stream: admin.watchAccounts(),
      builder: (context, snapshot) {
        final account = snapshot.data?.where((item) => item.id == accountId).firstOrNull;
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Hesap')),
            body: Center(child: Text('${snapshot.error}')),
          );
        }
        if (account == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Hesap')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(account.fullName.isEmpty ? account.email : account.fullName)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Card(
                child: ListTile(
                  title: Text(account.fullName.isEmpty ? 'İsimsiz hesap' : account.fullName),
                  subtitle: Text(
                    [
                      account.email,
                      'Kayıt: ${DateFormat('d MMM yyyy', 'tr_TR').format(account.createdAt)}',
                      if (account.isSuperAdmin) 'Tam yetkili yönetici',
                    ].join('\n'),
                  ),
                  isThreeLine: true,
                ),
              ),
              const SizedBox(height: 20),
              const Text('Yetkiler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (account.isSuperAdmin)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.verified_user_outlined, color: AppColors.primary),
                    title: Text('Bu hesap tam yetkilidir'),
                    subtitle: Text(
                      'Hiçbir yönetici bu hesabın yetkisini alamaz. Bu hesap herkesin yetkisini kaldırabilir.',
                    ),
                  ),
                )
              else
                ...AppPermission.values.map((permission) {
                  final enabled = actor.canManagePermissions;
                  return Card(
                    child: SwitchListTile(
                      title: Text(permission.label),
                      subtitle: Text(permission.description),
                      value: account.hasPermission(permission),
                      onChanged: enabled
                          ? (value) async {
                              final next = {...account.permissions};
                              if (value) {
                                next.add(permission);
                              } else {
                                next.remove(permission);
                              }
                              try {
                                await admin.setPermissions(
                                  target: account,
                                  permissions: next,
                                  actor: actor,
                                );
                              } catch (error) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$error')),
                                );
                              }
                            }
                          : null,
                    ),
                  );
                }),
              if (actor.canViewAllAccounts) ...[
                const SizedBox(height: 24),
                const Text('Eklediği formlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _AccountForms(doctorId: account.id),
                const SizedBox(height: 24),
                const Text('Hastalar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _AccountPatients(account: account),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AccountForms extends StatelessWidget {
  const _AccountForms({required this.doctorId});

  final String doctorId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClinicFormTemplate>>(
      stream: AdminService().watchFormTemplates(doctorId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Formlar yüklenemedi: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final templates = snapshot.data!;
        if (templates.isEmpty) {
          return const Card(
            child: ListTile(title: Text('Bu hesap henüz form eklememiş.')),
          );
        }
        return Column(
          children: templates
              .map(
                (template) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      title: Text(template.name),
                      subtitle: Text('${template.fields.length} alan'),
                      trailing: IconButton(
                        tooltip: 'Dışa aktar',
                        onPressed: () => FormPack.share(template: template),
                        icon: const Icon(Icons.ios_share_outlined),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _AccountPatients extends StatelessWidget {
  const _AccountPatients({required this.account});

  final Doctor account;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Patient>>(
      stream: AdminService().watchPatients(account.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Hastalar yüklenemedi: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final patients = snapshot.data!;
        if (patients.isEmpty) {
          return const Card(
            child: ListTile(title: Text('Bu hesapta hasta kaydı yok.')),
          );
        }
        return Column(
          children: patients
              .map(
                (patient) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      title: Text(patient.fullName),
                      subtitle: Text(
                        [
                          if (patient.diagnosis?.isNotEmpty == true) patient.diagnosis!,
                          DateFormat('d MMM yyyy', 'tr_TR').format(patient.updatedAt),
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdminPatientInspectScreen(
                              account: account,
                              patient: patient,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class AdminPatientInspectScreen extends StatelessWidget {
  const AdminPatientInspectScreen({
    super.key,
    required this.account,
    required this.patient,
  });

  final Doctor account;
  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final admin = AdminService();
    return Scaffold(
      appBar: AppBar(title: Text(patient.fullName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            child: ListTile(
              title: Text(patient.fullName),
              subtitle: Text(
                [
                  account.email,
                  if (patient.diagnosis?.isNotEmpty == true) 'Ön tanı: ${patient.diagnosis}',
                  if (patient.referrer?.isNotEmpty == true) 'Yönlendiren: ${patient.referrer}',
                ].join('\n'),
              ),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 20),
          const Text('Notlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          StreamBuilder<List<Note>>(
            stream: admin.watchNotes(account.id, patient.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text('Notlar yüklenemedi: ${snapshot.error}');
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final notes = snapshot.data!;
              if (notes.isEmpty) {
                return const Card(child: ListTile(title: Text('Not yok.')));
              }
              return Column(
                children: notes
                    .map(
                      (note) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            title: Text(note.title),
                            subtitle: Text(
                              '${note.type.label}\n${note.content}',
                              maxLines: 8,
                              overflow: TextOverflow.ellipsis,
                            ),
                            isThreeLine: true,
                            trailing: Text(
                              DateFormat('d MMM', 'tr_TR').format(note.createdAt),
                              style: const TextStyle(color: AppColors.muted, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text('Formlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          StreamBuilder<List<PatientFormEntry>>(
            stream: admin.watchPatientForms(account.id, patient.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text('Formlar yüklenemedi: ${snapshot.error}');
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final forms = snapshot.data!;
              if (forms.isEmpty) {
                return const Card(child: ListTile(title: Text('Form yok.')));
              }
              return Column(
                children: forms
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            title: Text(entry.title),
                            subtitle: Text(
                              [
                                entry.source.label,
                                DateFormat('d MMM yyyy HH:mm', 'tr_TR').format(entry.createdAt),
                                if (entry.values.isNotEmpty)
                                  entry.values.entries
                                      .where((item) => '${item.value}'.trim().isNotEmpty)
                                      .map((item) => '${item.value}')
                                      .join(' · '),
                              ].join('\n'),
                            ),
                            isThreeLine: true,
                          ),
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
  }
}
