import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/appointment.dart';

class MediaDetails {
  const MediaDetails({
    required this.name,
    this.session,
  });

  final String name;
  final Appointment? session;
}

Future<MediaDetails?> showMediaDetailsDialog({
  required BuildContext context,
  required List<Appointment> sessions,
  required String suggestedName,
}) {
  final sorted = [...sessions]..sort((a, b) => b.startsAt.compareTo(a.startsAt));
  return showDialog<MediaDetails>(
    context: context,
    builder: (context) => _MediaDetailsDialog(sessions: sorted, suggestedName: suggestedName),
  );
}

class _MediaDetailsDialog extends StatefulWidget {
  const _MediaDetailsDialog({required this.sessions, required this.suggestedName});

  final List<Appointment> sessions;
  final String suggestedName;

  @override
  State<_MediaDetailsDialog> createState() => _MediaDetailsDialogState();
}

class _MediaDetailsDialogState extends State<_MediaDetailsDialog> {
  late final TextEditingController _name;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.suggestedName);
    if (widget.sessions.isNotEmpty) {
      _sessionId = widget.sessions.first.id;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('d MMM yyyy HH:mm', 'tr_TR');
    return AlertDialog(
      title: const Text('Medya ayrıntısı'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: false,
              decoration: const InputDecoration(labelText: 'İsim'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            if (widget.sessions.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Bu hastanın seansı yok.'),
              )
            else ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Seans'),
              ),
              for (final session in widget.sessions)
                RadioListTile<String>(
                  value: session.id,
                  groupValue: _sessionId,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${session.title} · ${date.format(session.startsAt)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                  onChanged: (value) => setState(() => _sessionId = value),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Appointment? session;
            for (final item in widget.sessions) {
              if (item.id == _sessionId) session = item;
            }
            Navigator.pop(context, MediaDetails(name: name, session: session));
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
