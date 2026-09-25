import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 32),
          children: [
            const Icon(Icons.cloud_outlined, size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              'Firebase bağlantısı gerekli',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nüans hasta notlarını bulutta saklamak için kendi Firebase projenize bağlanmalıdır. Aşağıdaki adımları bir kez uygulayın.',
              style: TextStyle(color: AppColors.muted, height: 1.45),
            ),
            const SizedBox(height: 28),
            const _Step(
              number: '1',
              title: 'Firebase projesi oluşturun',
              body: 'console.firebase.google.com adresinden yeni bir proje açın.',
            ),
            const _Step(
              number: '2',
              title: 'Authentication ve Firestore açın',
              body:
                  'Authentication > Sign-in method içinde E-posta/Şifre’yi etkinleştirin. Firestore Database’i production modunda başlatın. Uygulama e-posta doğrulaması ve kalıcı e-posta zorunluluğunu kendisi uygular.',
            ),
            const _Step(
              number: '3',
              title: 'Android uygulaması ekleyin',
              body: 'Paket adı olarak com.nuans.nuans kullanın.',
            ),
            const _Step(
              number: '4',
              title: 'Yapılandırmayı aktarın',
              body:
                  'En kolay yol: flutterfire configure komutunu çalıştırmak. Alternatif olarak lib/firebase_options.dart içindeki YOUR_... alanlarını doldurun.',
            ),
            const _Step(
              number: '5',
              title: 'Güvenlik kurallarını yayınlayın',
              body: 'firebase deploy --only firestore:rules,storage',
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Kurulumdan sonra uygulamayı yeniden başlatın. Her doktor yalnızca kendi hastalarını ve notlarını görür.',
                  style: TextStyle(color: AppColors.muted.withValues(alpha: 0.95), height: 1.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.body});

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary,
            child: Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(color: AppColors.muted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
