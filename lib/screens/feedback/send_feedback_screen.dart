import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

class SendFeedbackScreen extends StatefulWidget {
  const SendFeedbackScreen({
    super.key,
    required this.senderName,
    required this.senderEmail,
  });

  final String senderName;
  final String senderEmail;

  @override
  State<SendFeedbackScreen> createState() => _SendFeedbackScreenState();
}

class _SendFeedbackScreenState extends State<SendFeedbackScreen> {
  final _message = TextEditingController();
  final _admin = AdminService();
  final _picker = ImagePicker();
  final _images = <File>[];
  var _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    if (_images.length >= 4 || _sending) return;
    final picked = await _picker.pickMultiImage(imageQuality: 80, maxWidth: 2000);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      for (final item in picked) {
        if (_images.length >= 4) break;
        _images.add(File(item.path));
      }
    });
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _admin.sendFeedback(
        message: text,
        senderName: widget.senderName,
        senderEmail: widget.senderEmail,
        images: List<File>.from(_images),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geri bildiriminiz iletildi.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gönderilemedi: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Geri bildirim')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const Text(
            'Mesajınız zttnlnkc@gmail.com hesabının yönetim panelindeki Geri bildirimler sekmesine düşer. En fazla 4 fotoğraf ekleyebilirsiniz.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _message,
            minLines: 6,
            maxLines: 12,
            maxLength: 4000,
            enabled: !_sending,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Mesaj',
              alignLabelWithHint: true,
              hintText: 'Gördüğünüz sorunu veya önerinizi yazın',
            ),
          ),
          if (_images.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_images[index], width: 88, height: 88, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(28, 28),
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: _sending ? null : () => setState(() => _images.removeAt(index)),
                          icon: const Icon(Icons.close, size: 16),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _sending || _images.length >= 4 ? null : _addPhoto,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(_images.isEmpty ? 'Galeriden ekle' : 'Galeriden ekle (${_images.length}/4)'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: const Text('Gönder'),
          ),
        ],
      ),
    );
  }
}
