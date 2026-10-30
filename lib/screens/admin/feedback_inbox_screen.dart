import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/feedback_message.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

class FeedbackInboxScreen extends StatelessWidget {
  const FeedbackInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tamamlanmış bildirimler',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const _CompletedFeedbackScreen()),
          );
        },
        child: const Icon(Icons.arrow_forward),
      ),
      body: const _FeedbackList(completed: false),
    );
  }
}

class _CompletedFeedbackScreen extends StatelessWidget {
  const _CompletedFeedbackScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tamamlanmış bildirimler')),
      body: const _FeedbackList(completed: true),
    );
  }
}

class _FeedbackList extends StatefulWidget {
  const _FeedbackList({required this.completed});

  final bool completed;

  @override
  State<_FeedbackList> createState() => _FeedbackListState();
}

class _FeedbackListState extends State<_FeedbackList> {
  final _admin = AdminService();
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _setResolved(FeedbackMessage item, {required bool resolved}) async {
    try {
      await _admin.setFeedbackResolved(item.id, resolved: resolved);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşaret kaydedilemedi: $error')),
      );
    }
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
          child: StreamBuilder<List<FeedbackMessage>>(
            stream: _admin.watchFeedback(),
            builder: (context, snapshot) {
              if (snapshot.hasError && !snapshot.hasData) {
                return Center(child: Text('Geri bildirimler yüklenemedi: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final q = _query.trim().toLowerCase();
              final items = snapshot.data!.where((item) {
                if (item.resolved != widget.completed) return false;
                if (q.isEmpty) return true;
                return item.senderName.toLowerCase().contains(q) ||
                    item.senderEmail.toLowerCase().contains(q);
              }).toList();
              if (items.isEmpty) {
                final empty = widget.completed ? 'Tamamlanmış bildirim yok.' : 'Henüz geri bildirim yok.';
                return Center(child: Text(q.isEmpty ? empty : 'Eşleşen geri bildirim yok.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final name = item.senderName.trim().isEmpty ? item.senderEmail : item.senderName.trim();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 2),
                          Text(item.senderEmail, style: const TextStyle(color: AppColors.muted)),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('d MMM yyyy HH:mm', 'tr_TR').format(item.createdAt),
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          Text(item.message, style: const TextStyle(height: 1.4)),
                          if (item.imageUrls.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 96,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: item.imageUrls.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 8),
                                itemBuilder: (context, imageIndex) {
                                  final url = item.imageUrls[imageIndex];
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => _FeedbackPhotoScreen(url: url)),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        url,
                                        width: 96,
                                        height: 96,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const ColoredBox(
                                          color: AppColors.chip,
                                          child: SizedBox(
                                            width: 96,
                                            height: 96,
                                            child: Icon(Icons.broken_image_outlined),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _setResolved(item, resolved: !widget.completed),
                              child: Text(widget.completed ? 'Geri al' : 'Okudum, anladım'),
                            ),
                          ),
                        ],
                      ),
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

class _FeedbackPhotoScreen extends StatelessWidget {
  const _FeedbackPhotoScreen({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: InteractiveViewer(
        child: Center(child: Image.network(url)),
      ),
    );
  }
}
