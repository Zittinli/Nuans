import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _auth = AuthService();
  bool _busy = false;

  Future<void> _resend() async {
    setState(() => _busy = true);
    try {
      await _auth.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doğrulama e-postası yeniden gönderildi.')),
      );
    } on AuthFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    setState(() => _busy = true);
    try {
      final verified = await _auth.reloadAndCheckVerified();
      if (!mounted) return;
      if (!verified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-posta henüz doğrulanmadı. Gelen kutusunu kontrol edin.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _auth.currentUser?.email ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.mark_email_unread_outlined, size: 56, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text(
                'E-posta doğrulaması',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Devam etmek için $email adresine gönderilen bağlantıyı açın. Tek kullanımlık e-posta adresleri kabul edilmez.',
                style: const TextStyle(color: AppColors.muted, height: 1.45),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _check,
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Doğrulamayı kontrol et'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : _resend,
                child: const Text('E-postayı yeniden gönder'),
              ),
              TextButton(
                onPressed: _busy ? null : _auth.signOut,
                child: const Text('Farklı hesapla giriş yap'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
