import 'package:flutter/material.dart';

import '../../models/clinic_form.dart';
import '../../models/doctor.dart';
import '../../models/form_category.dart';
import '../../screens/form/form_categories_screen.dart';
import '../../services/auth_service.dart';
import '../../services/clinic_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/confirm_twice.dart';
import '../../utils/form_attachment.dart';
import '../../utils/form_pack.dart';
import 'form_template_editor_screen.dart';

enum FormManagementTab { active, all }

class FormManagementScreen extends StatefulWidget {
  const FormManagementScreen({super.key, this.initialTab = FormManagementTab.active});

  final FormManagementTab initialTab;

  @override
  State<FormManagementScreen> createState() => _FormManagementScreenState();
}

class _FormManagementScreenState extends State<FormManagementScreen> {
  final _clinic = ClinicService();
  final _auth = AuthService();
  late FormManagementTab _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _clinic.ensureDefaultFormCategories();
  }

  Future<void> _openBuilder([ClinicFormTemplate? template]) async {
    if (template?.isGlobal == true) {
      final doctor = await _auth.watchProfile().first;
      if (doctor?.canManageDefaultForms != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Varsayılan formlar yalnızca yetkili yöneticiler tarafından düzenlenir.')),
        );
        return;
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FormTemplateEditorScreen(
          template: template,
          asGlobal: template?.isGlobal ?? false,
        ),
      ),
    );
  }

  Future<void> _export(ClinicFormTemplate template) async {
    try {
      await FormPack.share(template: template, clinic: _clinic);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp’ta dosyaya basıp İNÜ SKY ile aç. İndirmene gerek yok.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Form dışa aktarılamadı: $error')),
      );
    }
  }

  Future<void> _deleteTemplate(ClinicFormTemplate template) async {
    final ok = await confirmTwice(
      context: context,
      title: template.isGlobal ? 'Varsayılan formu kaldır' : 'Formu sil',
      firstBody: '"${template.name}" ${template.isGlobal ? 'tüm hesapların listesinden kaldırılsın mı?' : 'kalıcı olarak silinsin mi?'}',
      secondBody: 'Bu işlem geri alınamaz. Devam etmek istediğinize emin misiniz?',
      confirmLabel: template.isGlobal ? 'Kaldır' : 'Sil',
      finalLabel: template.isGlobal ? 'Evet, kaldır' : 'Evet, sil',
    );
    if (!ok || !mounted) return;
    await _clinic.deleteFormTemplate(template);
  }

  List<ClinicFormTemplate> _filter(List<ClinicFormTemplate> templates) {
    if (_tab == FormManagementTab.active) {
      return templates.where((item) => item.active).toList();
    }
    return templates;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Doctor?>(
      stream: _auth.watchProfile(),
      builder: (context, profileSnap) {
        final canManageGlobal = profileSnap.data?.canManageDefaultForms ?? false;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Form yönetimi'),
            actions: [
              if (profileSnap.data?.canManageFormCategories == true)
                IconButton(
                  tooltip: 'Form kategorileri',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FormCategoriesScreen()),
                    );
                  },
                  icon: const Icon(Icons.category_outlined),
                ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SegmentedButton<FormManagementTab>(
                  segments: const [
                    ButtonSegment(value: FormManagementTab.active, label: Text('Aktif formlar')),
                    ButtonSegment(value: FormManagementTab.all, label: Text('Tüm formlar')),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (value) => setState(() => _tab = value.first),
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openBuilder(),
            icon: const Icon(Icons.post_add_outlined),
            label: const Text('Form ekle'),
          ),
          body: StreamBuilder<List<FormCategory>>(
            stream: _clinic.watchFormCategories(),
            builder: (context, categorySnap) {
              final categoryNames = {
                for (final item in categorySnap.data ?? const <FormCategory>[]) item.id: item.name,
              };
              return StreamBuilder<List<ClinicFormTemplate>>(
                stream: _clinic.watchFormTemplates(),
                builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Formlar yüklenemedi: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final templates = _filter(snapshot.data!);
              if (templates.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _tab == FormManagementTab.active
                          ? 'Aktif form yok. Tüm formlar sekmesinden bir formu aktifleştirin veya yeni form ekleyin.'
                          : 'Henüz form şablonu yok. PDF/Word veya .nuans dosyası seçerek form ekleyin.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted, height: 1.45),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: templates.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final template = templates[index];
                  final lockedGlobal = template.isGlobal && !canManageGlobal;
                  return Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(template.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            [
                              if (template.categoryId != null)
                                categoryNames[template.categoryId] ?? template.categoryId!,
                              if (template.isGlobal) 'Varsayılan form',
                              if (template.description?.isNotEmpty == true) template.description!,
                              '${template.fields.length} alan',
                              if (template.hasSourceFile)
                                '${template.sourceFileKind?.label ?? 'Dosya'} eklendi',
                            ].join(' · '),
                          ),
                          trailing: lockedGlobal
                              ? const Icon(Icons.lock_outline)
                              : IconButton(
                                  tooltip: 'Düzenle',
                                  onPressed: () => _openBuilder(template),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                          onTap: lockedGlobal ? null : () => _openBuilder(template),
                        ),
                        if (_tab == FormManagementTab.all && !lockedGlobal)
                          SwitchListTile(
                            title: const Text('Hasta ekranında göster'),
                            subtitle: Text(
                              template.visibleToEveryone
                                  ? 'Bu seçim herkesin hasta ekranını etkiler'
                                  : template.isGlobal
                                      ? 'Tüm hesapların listesinde görünsün'
                                      : 'Aktif formlar hasta detayında seçilebilir',
                            ),
                            value: template.active,
                            onChanged: (value) => _clinic.setFormTemplateActive(template, value),
                          ),
                        if (canManageGlobal && !template.isGlobal)
                          SwitchListTile(
                            title: const Text('Herkes görsün'),
                            subtitle: const Text(
                              'Açıkken form tüm hesaplarda görünür. Bu kayıt Firebase’de tutulur.',
                            ),
                            value: template.visibleToEveryone,
                            onChanged: (value) async {
                              try {
                                await _clinic.setFormVisibleToEveryone(template, value);
                              } catch (error) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Paylaşım kaydedilemedi: $error')),
                                );
                              }
                            },
                          ),
                        if (template.hasSourceFile)
                          ListTile(
                            dense: true,
                            leading: Icon(
                              template.sourceFileKind == FormSourceKind.pdf
                                  ? Icons.picture_as_pdf_outlined
                                  : Icons.description_outlined,
                            ),
                            title: Text(template.sourceFileName ?? 'Kaynak dosya'),
                            trailing: const Icon(Icons.open_in_new),
                            onTap: () => openFormSourceFile(context: context, template: template),
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            children: [
                              TextButton.icon(
                                onPressed: () => _export(template),
                                icon: const Icon(Icons.ios_share_outlined),
                                label: const Text('Dışa aktar'),
                              ),
                              if (!lockedGlobal)
                                TextButton.icon(
                                  onPressed: () => _deleteTemplate(template),
                                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                                  label: Text(
                                    template.isGlobal ? 'Kaldır' : 'Sil',
                                    style: const TextStyle(color: AppColors.danger),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
                },
              );
            },
          ),
        );
      },
    );
  }
}
