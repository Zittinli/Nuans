import 'package:flutter/material.dart';

import '../../services/media_upload_queue.dart';
import '../../theme/app_theme.dart';

Future<void> showUploadQueueSheet(BuildContext context, String patientId) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return ListenableBuilder(
        listenable: MediaUploadQueue.instance,
        builder: (context, _) {
          final jobs = MediaUploadQueue.instance.forPatient(patientId);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Yükleme sırası', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (jobs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('Sırada medya yok.', textAlign: TextAlign.center),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: jobs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final job = jobs[index];
                          final percent = (job.progress * 100).round();
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(job.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      ),
                                      if (job.uploading)
                                        IconButton(
                                          tooltip: 'Yüklemeyi iptal et',
                                          onPressed: () => _confirmCancel(context, job),
                                          icon: const Icon(Icons.close),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  LinearProgressIndicator(value: job.progress.clamp(0, 1)),
                                  const SizedBox(height: 6),
                                  Text(
                                    job.uploading ? 'Yükleniyor · %$percent' : 'Sırada · %$percent',
                                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> _confirmCancel(BuildContext context, MediaUploadItem job) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Emin misin?'),
      content: Text('"${job.displayName}" yüklemesi silinecek.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
      ],
    ),
  );
  if (confirmed == true) {
    MediaUploadQueue.instance.requestCancel(job.id);
  }
}
