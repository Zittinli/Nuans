import 'package:flutter/material.dart';

import '../../models/clinic_form.dart';
import '../../services/clinic_service.dart';
import '../../theme/app_theme.dart';
import 'form_builder_screen.dart';

class FormTemplatesScreen extends StatelessWidget {
  const FormTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final clinic = ClinicService();
    return Scaffold(
      appBar: AppBar(title: const Text('Form şablonları')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FormBuilderScreen()),
          );
        },
        icon: const Icon(Icons.post_add_outlined),
        label: const Text('Yeni şablon'),
      ),
      body: StreamBuilder<List<ClinicFormTemplate>>(
        stream: clinic.watchFormTemplates(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Şablonlar yüklenemedi: ${snapshot.error}'));
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
                  'Henüz form şablonu yok. İstediğiniz alanlarla yeni bir form oluşturabilirsiniz. Hazır klinik formlarını daha sonra buraya ekleyeceğiz.',
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
                child: ListTile(
                  title: Text(template.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    [
                      if (template.description?.isNotEmpty == true) template.description!,
                      '${template.fields.length} alan',
                    ].join(' · '),
                  ),
                  trailing: IconButton(
                    tooltip: 'Sil',
                    onPressed: () => clinic.deleteFormTemplate(template),
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => FormBuilderScreen(template: template)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
