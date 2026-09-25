import 'package:flutter/material.dart';

import '../../models/clinic_form.dart';
import '../../services/clinic_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/form_attachment.dart';
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
  late FormManagementTab _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  Future<void> _openBuilder([ClinicFormTemplate? template]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FormTemplateEditorScreen(template: template)),
    );
  }

  List<ClinicFormTemplate> _filter(List<ClinicFormTemplate> templates) {
    if (_tab == FormManagementTab.active) {
      return templates.where((item) => item.active).toList();
    }
    return templates;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Form yönetimi'),
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
      body: StreamBuilder<List<ClinicFormTemplate>>(
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
                      : 'Henüz form şablonu yok. PDF/Word dosyası veya alanlarla yeni form oluşturun.',
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
              return Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(template.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        [
                          if (template.description?.isNotEmpty == true) template.description!,
                          '${template.fields.length} alan',
                          if (template.hasSourceFile)
                            '${template.sourceFileKind?.label ?? 'Dosya'} eklendi',
                        ].join(' · '),
                      ),
                      trailing: IconButton(
                        tooltip: 'Düzenle',
                        onPressed: () => _openBuilder(template),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      onTap: () => _openBuilder(template),
                    ),
                    if (_tab == FormManagementTab.all)
                      SwitchListTile(
                        title: const Text('Hasta ekranında göster'),
                        subtitle: const Text('Aktif formlar hasta detayında seçilebilir'),
                        value: template.active,
                        onChanged: (value) => _clinic.setFormTemplateActive(template.id, value),
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
                      child: TextButton.icon(
                        onPressed: () => _clinic.deleteFormTemplate(template.id),
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                        label: const Text('Sil', style: TextStyle(color: AppColors.danger)),
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
