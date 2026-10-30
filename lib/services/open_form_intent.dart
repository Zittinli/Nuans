import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/clinic_form.dart';
import '../models/patient.dart';
import '../models/patient_media.dart';
import '../screens/form/form_management_screen.dart';
import '../screens/patient/attach_media_screen.dart';
import '../screens/patient/patient_detail_screen.dart';
import '../services/clinic_service.dart';
import '../theme/app_theme.dart';
import '../utils/form_pack.dart';

class OpenFormIntent {
  OpenFormIntent._();

  static const _channel = MethodChannel('com.nuans.nuans/open_file');
  static GlobalKey<NavigatorState>? navigatorKey;
  static var _listening = false;
  static var _importing = false;
  static var _openingMedia = false;

  static void start(GlobalKey<NavigatorState> nav) {
    navigatorKey = nav;
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'opened') {
        await consumeAfterAuth();
      } else if (call.method == 'openedMedia') {
        await consumeMediaAfterAuth();
      }
    });
  }

  static bool get _signedIn {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && user.emailVerified;
  }

  static Future<void> consumeMediaAfterAuth() async {
    if (!_signedIn || _openingMedia) return;
    if (navigatorKey?.currentState == null) return;
    List<dynamic>? raw;
    try {
      raw = await _channel.invokeMethod<List<dynamic>>('takePendingMedia');
    } on PlatformException catch (error) {
      _toast('Dosya okunamadı: ${error.message ?? error.code}');
      return;
    }
    if (raw == null || raw.isEmpty) return;
    final files = <IncomingMedia>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final path = map['path'] as String? ?? '';
      if (path.isEmpty) continue;
      files.add(
        IncomingMedia(
          path: path,
          name: map['name'] as String? ?? 'dosya',
          mime: map['mime'] as String? ?? '',
        ),
      );
    }
    if (files.isEmpty) return;
    final nav = navigatorKey?.currentState;
    if (nav == null) return;
    _openingMedia = true;
    try {
      await nav.push(
        MaterialPageRoute(builder: (_) => AttachMediaScreen(files: files)),
      );
    } finally {
      _openingMedia = false;
    }
  }

  static Future<void> consumeAfterAuth() async {
    if (!_signedIn || _importing) return;
    String? path;
    try {
      path = await _channel.invokeMethod<String>('takePending');
    } on PlatformException catch (error) {
      _toast('Form dosyası okunamadı: ${error.message ?? error.code}');
      return;
    }
    if (path == null || path.isEmpty) return;
    String? contents;
    try {
      contents = await File(path).readAsString();
    } catch (_) {}
    if (!FormPack.looksLikePack(path, contents)) {
      _toast('Bu dosya İNÜ SKY form dosyası değil.');
      return;
    }
    await openPath(path);
  }

  static Future<void> openPath(String path) async {
    if (!_signedIn) return;
    if (_importing) return;
    _importing = true;
    try {
      final pack = await FormPack.importIntoCurrentAccount(path);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final nav = navigatorKey?.currentState;
      final ctx = navigatorKey?.currentContext;
      if (pack.filled) {
        final clinic = ClinicService();
        final patients = await clinic.watchPatients().first;
        var chosen = FormPack.matchPatientByIdentity(patients, pack.identityNumber);
        if (chosen == null && ctx != null && ctx.mounted) {
          chosen = await _choosePatient(
            ctx,
            suggestedName: pack.patientName,
            patientMeta: pack.patientMeta,
          );
        }
        if (chosen != null) {
          final now = DateTime.now();
          await clinic.savePatientForm(
            chosen.id,
            PatientFormEntry(
              id: '',
              templateId: pack.template.id,
              title: pack.template.name,
              source: PatientFormSource.filled,
              values: pack.values,
              createdAt: now,
              updatedAt: now,
            ),
          );
          if (ctx != null && ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(
                  '"${pack.template.name}" dolu formu ${chosen.fullName} kaydına eklendi.',
                ),
              ),
            );
          }
          if (nav != null) {
            await nav.push(
              MaterialPageRoute(builder: (_) => PatientDetailScreen(patient: chosen!)),
            );
          }
          return;
        }
      }
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              '"${pack.template.name}" formlarınıza eklendi. Aktif formlara almak için tikleyin.',
            ),
          ),
        );
      }
      if (nav != null) {
        await nav.push(
          MaterialPageRoute(
            builder: (_) => const FormManagementScreen(initialTab: FormManagementTab.all),
          ),
        );
      }
    } catch (error) {
      _toast('Form hesaba eklenemedi: $error');
    } finally {
      _importing = false;
    }
  }

  static Future<Patient?> _choosePatient(
    BuildContext context, {
    String? suggestedName,
    Map<String, dynamic>? patientMeta,
  }) async {
    final clinic = ClinicService();
    final patients = await clinic.watchPatients().first;
    if (!context.mounted) return null;
    return showModalBottomSheet<Patient>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final fromPack = FormPack.patientFromMeta(patientMeta);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.72,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Dolu formu hangi hastaya ekleyelim?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  if (suggestedName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Kaynak hasta: $suggestedName',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        if (fromPack != null)
                          ListTile(
                            leading: const Icon(Icons.person_add_outlined),
                            title: Text('${fromPack.fullName} olarak yeni hasta oluştur'),
                            subtitle: const Text('Dolu formu yeni kayda ekler'),
                            onTap: () async {
                              final id = await clinic.savePatient(fromPack);
                              if (!sheetContext.mounted) return;
                              Navigator.pop(
                                sheetContext,
                                FormPack.patientFromMeta(patientMeta, id: id),
                              );
                            },
                          ),
                        if (patients.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Kayıtlı hasta yok. Yukarıdan yeni hasta oluşturabilirsin.',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          )
                        else
                          ...patients.map(
                            (patient) => ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.chip,
                                foregroundColor: AppColors.primary,
                                child: Text(patient.initials),
                              ),
                              title: Text(patient.fullName),
                              onTap: () => Navigator.pop(sheetContext, patient),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void _toast(String message) {
    final ctx = navigatorKey?.currentContext;
    if (ctx == null || !ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
  }
}
