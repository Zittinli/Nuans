import 'package:flutter/material.dart';

import '../../models/clinic_form.dart';
import '../../models/form_category.dart';
import '../../services/clinic_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/confirm_twice.dart';

class FormCategoriesScreen extends StatefulWidget {
  const FormCategoriesScreen({super.key, this.embedded = false});

  /// Yönetim sekmesi içindeyken üst AppBar gösterilmez.
  final bool embedded;

  @override
  State<FormCategoriesScreen> createState() => _FormCategoriesScreenState();
}

class _FormCategoriesScreenState extends State<FormCategoriesScreen> {
  final _clinic = ClinicService();
  var _seeded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _seedDefaults());
  }

  Future<void> _seedDefaults() async {
    if (_seeded) return;
    _seeded = true;
    try {
      await _clinic.ensureDefaultFormCategories();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Varsayılan kategoriler oluşturulamadı: $error')),
      );
    }
  }

  Future<void> _openEditor([FormCategory? category]) async {
    final name = TextEditingController(text: category?.name ?? '');
    final description = TextEditingController(text: category?.description ?? '');
    final sortOrder = TextEditingController(text: '${category?.sortOrder ?? 0}');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category == null ? 'Kategori ekle' : 'Kategoriyi düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Kategori adı / kodu'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Açıklama (isteğe bağlı)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sortOrder,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sıra numarası'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kaydet')),
        ],
      ),
    );
    if (saved != true) {
      name.dispose();
      description.dispose();
      sortOrder.dispose();
      return;
    }

    final trimmed = name.text.trim();
    if (trimmed.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kategori adı gerekli.')),
        );
      }
      name.dispose();
      description.dispose();
      sortOrder.dispose();
      return;
    }

    final order = int.tryParse(sortOrder.text.trim()) ?? category?.sortOrder ?? 0;
    final now = DateTime.now();
    try {
      await _clinic.saveFormCategory(
        FormCategory(
          id: category?.id ?? '',
          name: trimmed,
          description: description.text.trim().isEmpty ? null : description.text.trim(),
          sortOrder: order,
          createdAt: category?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kategori kaydedilemedi: $error')),
        );
      }
    }
    name.dispose();
    description.dispose();
    sortOrder.dispose();
  }

  Future<void> _deleteCategory(FormCategory category, List<ClinicFormTemplate> forms) async {
    final inUse = forms.any((item) => item.categoryId == category.id);
    if (inUse) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${category.name}" kategorisinde formlar var; önce formları taşıyın veya silin.')),
      );
      return;
    }
    final ok = await confirmTwice(
      context: context,
      title: 'Kategoriyi sil',
      firstBody: '"${category.name}" kalıcı olarak silinsin mi?',
      secondBody: 'Kategori geri getirilemez. Emin misiniz?',
    );
    if (!ok) return;
    try {
      await _clinic.deleteFormCategory(category.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kategori silinemedi: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.embedded ? Colors.transparent : null,
      appBar: widget.embedded ? null : AppBar(title: const Text('Form kategorileri')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Kategori ekle'),
      ),
      body: StreamBuilder<List<ClinicFormTemplate>>(
        stream: _clinic.watchFormTemplates(),
        builder: (context, formsSnap) {
          final forms = formsSnap.data ?? const <ClinicFormTemplate>[];
          return StreamBuilder<List<FormCategory>>(
            stream: _clinic.watchFormCategories(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Kategoriler yüklenemedi: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final categories = snapshot.data!;
              if (categories.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Henüz kategori yok. Varsayılanlar yükleniyor veya yeni kategori ekleyin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, height: 1.45),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final count = forms.where((item) => item.categoryId == category.id).length;
                  return Card(
                    child: ListTile(
                      title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        [
                          if (category.description?.isNotEmpty == true) category.description!,
                          '$count form',
                          'Sıra: ${category.sortOrder}',
                        ].join(' · '),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _openEditor(category);
                          } else if (value == 'delete') {
                            _deleteCategory(category, forms);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                          PopupMenuItem(value: 'delete', child: Text('Sil')),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
