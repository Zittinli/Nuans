import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/appointment.dart';
import '../../models/clinic_form.dart';
import '../../models/note.dart';
import '../../models/patient.dart';
import '../../models/patient_media.dart';
import '../../services/clinic_service.dart';
import '../../services/media_upload_queue.dart';
import 'audio_record_sheet.dart';
import 'media_details_dialog.dart';
import '../../theme/app_theme.dart';
import '../../utils/confirm_twice.dart';
import '../../utils/form_pack.dart';
import '../../widgets/appointment_calendar.dart';
import '../calendar/appointment_form_screen.dart';
import '../form/form_entry_detail_screen.dart';
import '../../widgets/media_preview.dart';
import '../../widgets/patient_form_selector.dart';
import '../note/note_form_screen.dart';
import 'patient_form_screen.dart';
import 'patient_media_screen.dart';
import 'upload_queue_sheet.dart';

class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({super.key, required this.patient});

  final Patient patient;

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  final _clinic = ClinicService();
  late Patient _patient;
  DateTime _selected = DateTime.now();
  DateTime _focused = DateTime.now();
  final _addButtonKey = GlobalKey();
  OverlayEntry? _addOverlay;
  _AddMenu _addMenu = _AddMenu.closed;

  @override
  void initState() {
    super.initState();
    _patient = widget.patient;
    MediaUploadQueue.instance.notice.addListener(_onUploadNotice);
  }

  @override
  void dispose() {
    MediaUploadQueue.instance.notice.removeListener(_onUploadNotice);
    _addOverlay?.remove();
    _addOverlay = null;
    super.dispose();
  }

  void _onUploadNotice() {
    final message = MediaUploadQueue.instance.notice.value;
    if (message == null || !mounted) return;
    MediaUploadQueue.instance.notice.value = null;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _setAddMenu(_AddMenu menu) {
    if (!mounted) return;
    setState(() => _addMenu = menu);
    if (menu == _AddMenu.closed) {
      _addOverlay?.remove();
      _addOverlay = null;
      return;
    }
    _addOverlay ??= OverlayEntry(builder: _buildAddOverlay);
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    if (_addOverlay!.mounted) {
      _addOverlay!.markNeedsBuild();
    } else {
      overlay.insert(_addOverlay!);
    }
  }

  Future<void> _editPatient() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PatientFormScreen(patient: _patient)),
    );
  }

  Future<void> _deletePatient() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hastayı sil'),
        content: Text('${_patient.fullName}, notları ve dosyaları kalıcı olarak silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _clinic.deletePatient(_patient.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notu sil'),
        content: const Text('Bu klinik not kalıcı olarak silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _clinic.deleteNote(_patient.id, note.id);
    }
  }

  Future<void> _deleteAppointment(Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Görüşmeyi sil'),
        content: const Text('Bu görüşme silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed == true) {
      await _clinic.deleteAppointment(appointment.id);
    }
  }

  Future<void> _deletePatientForm(PatientFormEntry entry) async {
    final ok = await confirmTwice(
      context: context,
      title: 'Formu sil',
      firstBody: '"${entry.title}" bu hastadan kaldırılsın mı?',
      secondBody: 'Dolu form kaydı silinecek. Emin misiniz?',
    );
    if (!ok || !mounted) return;
    await _clinic.deletePatientForm(_patient.id, entry.id);
  }

  void _openAddForm() {
    _setAddMenu(_AddMenu.closed);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: PatientFormSelector(patient: _patient, popBeforeFill: true),
      ),
    );
  }

  Future<void> _addMedia(String choice) async {
    _setAddMenu(_AddMenu.closed);
    String? path;
    String? name;
    String? mime;
    final picker = ImagePicker();
    try {
      switch (choice) {
        case 'camera-photo':
          final file = await picker.pickImage(source: ImageSource.camera);
          path = file?.path;
          name = file?.name;
          mime = file?.mimeType;
        case 'gallery-photo':
          final file = await picker.pickImage(source: ImageSource.gallery);
          path = file?.path;
          name = file?.name;
          mime = file?.mimeType;
        case 'camera-video':
          final file = await picker.pickVideo(source: ImageSource.camera);
          path = file?.path;
          name = file?.name;
          mime = file?.mimeType;
        case 'gallery-video':
          final file = await picker.pickVideo(source: ImageSource.gallery);
          path = file?.path;
          name = file?.name;
          mime = file?.mimeType;
        case 'audio':
          final picked = await FilePicker.pickFiles(type: FileType.audio);
          final file = picked?.files.single;
          path = file?.path;
          name = file?.name;
          mime = file?.extension == null ? null : guessMediaContentType(file!.name, null);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dosya seçilemedi: $error')));
      return;
    }
    if (path == null || path.isEmpty || !mounted) return;
    final fileName = (name == null || name.isEmpty) ? path.split(Platform.pathSeparator).last : name;
    final contentType = guessMediaContentType(path, mime);
    final suggested = switch (choice) {
      'camera-video' || 'gallery-video' => 'Video',
      'audio' => 'Ses',
      _ => 'Fotoğraf',
    };
    await _saveMediaFile(path: path, fileName: fileName, contentType: contentType, suggestedName: suggested);
  }

  Future<void> _recordAudio() async {
    _setAddMenu(_AddMenu.closed);
    final path = await showAudioRecordSheet(context);
    if (path == null || path.isEmpty || !mounted) return;
    await _saveMediaFile(
      path: path,
      fileName: path.split(Platform.pathSeparator).last,
      contentType: 'audio/mp4',
      suggestedName: 'Ses kaydı',
    );
  }

  Future<void> _saveMediaFile({
    required String path,
    required String fileName,
    required String contentType,
    required String suggestedName,
  }) async {
    final sessions = await _clinic.watchPatientAppointments(_patient.id).first;
    sessions.sort((a, b) {
      final aDay = _sameDay(a.startsAt, _selected);
      final bDay = _sameDay(b.startsAt, _selected);
      if (aDay != bDay) return aDay ? -1 : 1;
      return b.startsAt.compareTo(a.startsAt);
    });
    if (!mounted) return;
    final details = await showMediaDetailsDialog(
      context: context,
      sessions: sessions,
      suggestedName: suggestedName,
    );
    if (details == null || !mounted) return;
    await MediaUploadQueue.instance.enqueue(
      patientId: _patient.id,
      path: path,
      fileName: fileName,
      contentType: contentType,
      displayName: details.name,
      sessionId: details.session?.id,
      sessionTitle: details.session?.title,
      sessionStartsAt: details.session?.startsAt,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yükleme sırasına alındı.')));
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _renameMedia(PatientMedia media) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameMediaDialog(initial: media.title),
    );
    if (name == null || name.isEmpty || !mounted) return;
    await _clinic.renamePatientMedia(_patient.id, media.id, name);
  }

  Future<void> _downloadMedia(PatientMedia media) async {
    try {
      final bytes = await _clinic.downloadBytes(
        media.url,
        patientId: _patient.id,
        mediaId: media.id,
      );
      if (!mounted) return;
      if (bytes == null || bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dosya indirilemedi.')));
        return;
      }
      final saved = await FilePicker.saveFile(
        dialogTitle: 'İndir',
        fileName: _downloadName(media),
        bytes: Uint8List.fromList(bytes),
      );
      if (!mounted || saved == null) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dosya indirildi.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İndirilemedi: $error')));
    }
  }

  String _downloadName(PatientMedia media) {
    final dot = media.fileName.lastIndexOf('.');
    final ext = dot >= 0 ? media.fileName.substring(dot) : '';
    final safe = media.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (ext.isEmpty || safe.toLowerCase().endsWith(ext.toLowerCase())) return safe;
    return '$safe$ext';
  }

  Future<void> _deleteMedia(PatientMedia media) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dosyayı sil'),
        content: Text('"${media.title}" bu hastadan kaldırılsın mı?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _clinic.deletePatientMedia(_patient.id, media);
  }

  Future<void> _shareFilledForm(PatientFormEntry entry) async {
    try {
      ClinicFormTemplate? template;
      if (entry.templateId != null && entry.templateId!.isNotEmpty) {
        final templates = await _clinic.watchFormTemplates().first;
        template = templates.where((item) => item.id == entry.templateId).firstOrNull;
      }
      final packTemplate = (template ??
              ClinicFormTemplate(
                id: '',
                name: entry.title,
                fields: const [],
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ))
          .copyWith(name: entry.title);
      await FormPack.share(
        template: packTemplate,
        clinic: _clinic,
        entry: entry,
        patient: _patient,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${FormPack.packFileName(entry.title, filled: true)} WhatsApp belgesi olarak gönderildi.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dolu form paylaşılamadı: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Patient>>(
      stream: _clinic.watchPatients(),
      builder: (context, patientSnap) {
        final latest = patientSnap.data?.where((item) => item.id == _patient.id).firstOrNull;
        if (latest != null) {
          _patient = latest;
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(_patient.fullName),
            actions: [
              IconButton(
                key: _addButtonKey,
                tooltip: _addMenu == _AddMenu.closed ? 'Ekle' : 'Kapat',
                onPressed: () => _setAddMenu(
                  _addMenu == _AddMenu.closed ? _AddMenu.main : _AddMenu.closed,
                ),
                icon: Icon(_addMenu == _AddMenu.closed ? Icons.add : Icons.close),
              ),
              IconButton(
                tooltip: 'Düzenle',
                onPressed: _editPatient,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Sil',
                onPressed: _deletePatient,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: Stack(
            children: [
              ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _PatientHeader(patient: _patient),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => NoteFormScreen(patientId: _patient.id)),
                  );
                },
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Yeni not'),
              ),
              const SizedBox(height: 24),
              const Text('Dosyalar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              StreamBuilder<List<PatientMedia>>(
                stream: _clinic.watchPatientMedia(_patient.id),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Dosyalar yüklenemedi: ${snapshot.error}');
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final items = snapshot.data!;
                  if (items.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Bu hasta için henüz fotoğraf, video veya ses yok.',
                          style: TextStyle(color: AppColors.muted, height: 1.4),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final media in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MediaRow(
                            patientId: _patient.id,
                            media: media,
                            onOpen: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PatientMediaScreen(
                                    media: media,
                                    patientId: _patient.id,
                                  ),
                                ),
                              );
                            },
                            onRename: () => _renameMedia(media),
                            onDownload: () => _downloadMedia(media),
                            onDelete: () => _deleteMedia(media),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text('Görüşme takvimi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              StreamBuilder<List<Appointment>>(
                stream: _clinic.watchPatientAppointments(_patient.id),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Takvim yüklenemedi: ${snapshot.error}');
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final items = snapshot.data!;
                  final past = items.where((item) => item.isPast).toList().reversed.toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppointmentCalendarView(
                        appointments: items,
                        selectedDay: _selected,
                        focusedDay: _focused,
                        emptyMessage: 'Bu gün için görüşme yok.',
                        onDaySelected: (selected, focused) {
                          setState(() {
                            _selected = selected;
                            _focused = focused;
                          });
                        },
                        onAdd: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AppointmentFormScreen(
                                patient: _patient,
                                initialDay: _selected,
                              ),
                            ),
                          );
                        },
                        onTapAppointment: (appointment) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AppointmentFormScreen(
                                patient: _patient,
                                appointment: appointment,
                              ),
                            ),
                          );
                        },
                        onDeleteAppointment: _deleteAppointment,
                      ),
                      if (past.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Geçmiş görüşmeler', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        ...past.take(8).map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.history, color: AppColors.primaryLight),
                            title: Text(item.title),
                            subtitle: Text(
                              DateFormat('d MMM yyyy HH:mm', 'tr_TR').format(item.startsAt),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text('Formlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              StreamBuilder<List<PatientFormEntry>>(
                stream: _clinic.watchPatientForms(_patient.id),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Formlar yüklenemedi: ${snapshot.error}');
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final forms = snapshot.data!;
                  if (forms.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Bu hasta için henüz form yok. Dijital form doldurabilir veya kağıt formu tarayabilirsiniz.',
                          style: TextStyle(color: AppColors.muted, height: 1.4),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: forms
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Card(
                              child: ListTile(
                                leading: Icon(
                                  entry.source == PatientFormSource.scanned
                                      ? Icons.document_scanner_outlined
                                      : Icons.description_outlined,
                                  color: AppColors.primary,
                                ),
                                title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text(
                                  '${entry.source.label} · ${DateFormat('d MMM yyyy HH:mm', 'tr_TR').format(entry.createdAt)}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (entry.source == PatientFormSource.filled)
                                      IconButton(
                                        tooltip: 'Dolu formu paylaş',
                                        onPressed: () => _shareFilledForm(entry),
                                        icon: const Icon(Icons.ios_share_outlined),
                                      ),
                                    IconButton(
                                      tooltip: 'Sil',
                                      onPressed: () => _deletePatientForm(entry),
                                      icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => FormEntryDetailScreen(patient: _patient, entry: entry),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text('Klinik notlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              StreamBuilder<List<Note>>(
                stream: _clinic.watchNotes(_patient.id),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Notlar yüklenemedi: ${snapshot.error}');
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final notes = snapshot.data!;
                  if (notes.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Bu hasta için henüz not yok. Muayene, kontrol veya reçete notu ekleyebilirsiniz.',
                          style: TextStyle(color: AppColors.muted, height: 1.4),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: notes
                        .map(
                          (note) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _NoteCard(
                              note: note,
                              onEdit: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => NoteFormScreen(patientId: _patient.id, note: note),
                                  ),
                                );
                              },
                              onDelete: () => _deleteNote(note),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
              ListenableBuilder(
                listenable: MediaUploadQueue.instance,
                builder: (context, _) {
                  final pending = MediaUploadQueue.instance.forPatient(_patient.id);
                  if (pending.isEmpty) return const SizedBox.shrink();
                  return Positioned(
                    top: 12,
                    right: 12,
                    child: Tooltip(
                      message: 'Yükleme sırası',
                      child: Material(
                        elevation: 8,
                        color: Colors.white,
                        shadowColor: const Color(0x66000000),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => showUploadQueueSheet(context, _patient.id),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 3.2,
                                color: AppColors.primary,
                                backgroundColor: Color(0xFFD5E4E2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddOverlay(BuildContext context) {
    final button = _addButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    final screen = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    var center = Offset(screen.width - 120, pad.top + 28);
    if (button != null && button.attached && overlay != null && overlay.attached) {
      center = overlay.globalToLocal(button.localToGlobal(button.size.center(Offset.zero)));
    }
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => _setAddMenu(_AddMenu.closed),
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: Color(0x33000000)),
          ),
        ),
        _AddBubbles(
          menu: _addMenu,
          anchor: center,
          bounds: screen,
          padding: pad,
          onPick: (action) {
              switch (action) {
                case 'form':
                  _openAddForm();
                case 'photo':
                  _setAddMenu(_AddMenu.photo);
                case 'video':
                  _setAddMenu(_AddMenu.video);
                case 'audio':
                  _setAddMenu(_AddMenu.audio);
                case 'record-audio':
                  _recordAudio();
                case 'upload-audio':
                  _addMedia('audio');
                case 'back':
                  _setAddMenu(_AddMenu.main);
                default:
                  _addMedia(action);
              }
          },
        ),
      ],
    );
  }
}

class _PatientHeader extends StatelessWidget {
  const _PatientHeader({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.chip,
                  foregroundColor: AppColors.primary,
                  child: Text(patient.initials, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patient.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      Text(
                        [
                          if (patient.age != null) '${patient.age} yaş',
                          patient.gender,
                        ].join(' · '),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (patient.identityNumber != null) _InfoRow(label: 'T.C.', value: patient.identityNumber!),
            if (patient.phone != null) _InfoRow(label: 'Telefon', value: patient.phone!),
            if (patient.diagnosis != null) _InfoRow(label: 'Ön tanı', value: patient.diagnosis!),
            if (patient.referrer != null) _InfoRow(label: 'Yönlendiren', value: patient.referrer!),
            if (patient.birthDate != null)
              _InfoRow(
                label: 'Doğum',
                value: DateFormat('d MMMM yyyy', 'tr_TR').format(patient.birthDate!),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96, child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onEdit, required this.onDelete});

  final Note note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(note.type.icon, size: 18, color: AppColors.primaryLight),
                const SizedBox(width: 8),
                Chip(
                  label: Text(note.type.label),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppColors.chip,
                  side: BorderSide.none,
                ),
                const Spacer(),
                Text(
                  DateFormat('d MMM yyyy HH:mm', 'tr_TR').format(note.createdAt),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                    PopupMenuItem(value: 'delete', child: Text('Sil')),
                  ],
                ),
              ],
            ),
            Text(note.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(note.content, style: const TextStyle(height: 1.4, color: AppColors.text)),
          ],
        ),
      ),
    );
  }
}

class _MediaRow extends StatelessWidget {
  const _MediaRow({
    required this.patientId,
    required this.media,
    required this.onOpen,
    required this.onRename,
    required this.onDownload,
    required this.onDelete,
  });

  final String patientId;
  final PatientMedia media;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('d MMM yyyy HH:mm', 'tr_TR');
    final session = media.sessionTitle == null || media.sessionTitle!.trim().isEmpty
        ? 'Seans yok'
        : media.sessionStartsAt == null
            ? media.sessionTitle!
            : '${media.sessionTitle} · ${date.format(media.sessionStartsAt!)}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 116,
              height: 116,
              child: Material(
                color: AppColors.chip,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onOpen,
                  child: MediaPreview(media: media, patientId: patientId),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(media.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(date.format(media.createdAt), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(session, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'İndir',
                        visualDensity: VisualDensity.compact,
                        onPressed: onDownload,
                        icon: const Icon(Icons.download_outlined),
                      ),
                      IconButton(
                        tooltip: 'Adı değiştir',
                        visualDensity: VisualDensity.compact,
                        onPressed: onRename,
                        icon: const Icon(Icons.drive_file_rename_outline),
                      ),
                      IconButton(
                        tooltip: 'Sil',
                        visualDensity: VisualDensity.compact,
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RenameMediaDialog extends StatefulWidget {
  const _RenameMediaDialog({required this.initial});

  final String initial;

  @override
  State<_RenameMediaDialog> createState() => _RenameMediaDialogState();
}

class _RenameMediaDialogState extends State<_RenameMediaDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('İsim'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Medya adı'),
        textCapitalization: TextCapitalization.sentences,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

enum _AddMenu { closed, main, photo, video, audio }

class _AddBubbles extends StatelessWidget {
  const _AddBubbles({
    required this.menu,
    required this.anchor,
    required this.bounds,
    required this.padding,
    required this.onPick,
  });

  final _AddMenu menu;
  final Offset anchor;
  final Size bounds;
  final EdgeInsets padding;
  final ValueChanged<String> onPick;

  static const _radius = 116.0;
  static const _bubble = 46.0;
  static const _slotW = 74.0;
  static const _slotH = 68.0;

  @override
  Widget build(BuildContext context) {
    final items = switch (menu) {
      _AddMenu.photo => const [
          _Bubble('camera-photo', 'Çek', Icons.photo_camera_outlined),
          _Bubble('gallery-photo', 'Galeri', Icons.photo_library_outlined),
        ],
      _AddMenu.video => const [
          _Bubble('camera-video', 'Çek', Icons.videocam_outlined),
          _Bubble('gallery-video', 'Galeri', Icons.video_library_outlined),
        ],
      _AddMenu.audio => const [
          _Bubble('record-audio', 'Kaydet', Icons.mic),
          _Bubble('upload-audio', 'Yükle', Icons.upload_file_outlined),
        ],
      _ => const [
          _Bubble('audio', 'Ses', Icons.mic_none),
          _Bubble('video', 'Video', Icons.videocam_outlined),
          _Bubble('photo', 'Fotoğraf', Icons.photo_outlined),
          _Bubble('form', 'Form', Icons.description_outlined),
        ],
    };
    final angles = _angles(items.length);
    final submenu = menu == _AddMenu.photo || menu == _AddMenu.video || menu == _AddMenu.audio;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var i = 0; i < items.length; i++) _placedBubble(items[i], angles[i], i),
        if (submenu)
          Positioned(
            left: _fit(anchor.dx - 28, 8, bounds.width - 72),
            top: _fit(anchor.dy + 8, padding.top + 4, bounds.height - padding.bottom - 40),
            child: TextButton(
              onPressed: () => onPick('back'),
              child: const Text(
                'Geri',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                ),
              ),
            ),
          ),
      ],
    );
  }

  double _fit(double value, double min, double max) {
    if (max < min) return min;
    return value.clamp(min, max);
  }

  /// Daire yayı. İki seçenek kısa yayda komşu kalır; dört seçenekte video ile fotoğraf ardışıktır.
  List<double> _angles(int count) {
    if (count <= 2) {
      const mid = math.pi * 0.56;
      const gap = math.pi * 0.28;
      if (count == 1) return const [mid];
      return [mid - gap / 2, mid + gap / 2];
    }
    const start = math.pi * 0.28;
    const step = math.pi * 0.23;
    return List.generate(count, (i) => start + step * i);
  }

  Widget _placedBubble(_Bubble item, double angle, int index) {
    final left = _fit(anchor.dx + math.cos(angle) * _radius - _slotW / 2, 8, bounds.width - _slotW - 8);
    final top = _fit(
      anchor.dy + math.sin(angle) * _radius - _bubble / 2,
      padding.top + 4,
      bounds.height - padding.bottom - _slotH - 8,
    );
    return Positioned(
      left: left,
      top: top,
      width: _slotW,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 180 + 35 * index),
        curve: Curves.easeOutBack,
        builder: (context, value, child) => Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.scale(scale: value, child: child),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              elevation: 3,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onPick(item.action),
                child: SizedBox(
                  width: _bubble,
                  height: _bubble,
                  child: Icon(item.icon, color: Colors.white, size: 22),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _Bubble {
  const _Bubble(this.action, this.label, this.icon);
  final String action;
  final String label;
  final IconData icon;
}
