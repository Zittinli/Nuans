import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/patient_media.dart';
import '../services/clinic_service.dart';
import '../services/local_clinic_cache.dart';
import '../theme/app_theme.dart';
import '../utils/video_thumb.dart';

class MediaPreview extends StatelessWidget {
  const MediaPreview({super.key, required this.media, this.patientId});

  final PatientMedia media;
  final String? patientId;

  @override
  Widget build(BuildContext context) {
    if (media.kind == PatientMediaKind.photo && (media.url.isNotEmpty || patientId != null)) {
      return _OfflineImage(
        patientId: patientId,
        mediaId: media.id,
        url: media.url,
        fallback: const _KindFallback(icon: Icons.image_outlined, label: 'Fotoğraf'),
      );
    }
    if (media.kind == PatientMediaKind.video) {
      return _OfflineImage(
        patientId: patientId,
        mediaId: media.id,
        url: media.thumbnailUrl ?? '',
        video: true,
        media: media,
        fallback: _GeneratedVideoThumb(media: media, patientId: patientId),
      );
    }
    return const _KindFallback(icon: Icons.mic_none, label: 'Ses');
  }
}

class _OfflineImage extends StatefulWidget {
  const _OfflineImage({
    required this.patientId,
    required this.mediaId,
    required this.url,
    required this.fallback,
    this.video = false,
    this.media,
  });

  final String? patientId;
  final String mediaId;
  final String url;
  final Widget fallback;
  final bool video;
  final PatientMedia? media;

  @override
  State<_OfflineImage> createState() => _OfflineImageState();
}

class _OfflineImageState extends State<_OfflineImage> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final patientId = widget.patientId;
    if (patientId == null) return;
    final file = await LocalClinicCache().mediaFile(patientId, widget.mediaId);
    if (!mounted || file == null) return;
    setState(() => _file = file);
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    final ImageProvider? provider = file != null
        ? FileImage(file)
        : (widget.url.isNotEmpty ? NetworkImage(widget.url) : null);
    if (widget.video) {
      if (file != null) {
        return _GeneratedVideoThumb(media: widget.media!, patientId: widget.patientId, sourcePath: file.path);
      }
      if (provider != null) return _VideoFrame(child: _cover(provider));
      return widget.fallback;
    }
    if (provider != null) return _cover(provider);
    return widget.fallback;
  }

  Widget _cover(ImageProvider provider) {
    return Image(
      image: provider,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => widget.fallback,
    );
  }
}

class _GeneratedVideoThumb extends StatefulWidget {
  const _GeneratedVideoThumb({required this.media, this.patientId, this.sourcePath});

  final PatientMedia media;
  final String? patientId;
  final String? sourcePath;

  @override
  State<_GeneratedVideoThumb> createState() => _GeneratedVideoThumbState();
}

class _GeneratedVideoThumbState extends State<_GeneratedVideoThumb> {
  Uint8List? _bytes;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final media = widget.media;
    final cached = cachedVideoThumb(media.id);
    if (cached != null) {
      if (mounted) setState(() => _bytes = cached);
      return;
    }
    final bytes = await videoThumbnailBytes(widget.sourcePath ?? media.url);
    if (bytes == null) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    rememberVideoThumb(media.id, bytes);
    final patientId = widget.patientId;
    if (patientId != null && (media.thumbnailUrl == null || media.thumbnailUrl!.isEmpty)) {
      await ClinicService().saveVideoThumbnail(patientId: patientId, mediaId: media.id, jpeg: bytes);
    }
    if (!mounted) return;
    setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return _VideoFrame(
        child: Image.memory(bytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
      );
    }
    if (_failed) {
      return const _KindFallback(icon: Icons.videocam_outlined, label: 'Video');
    }
    return const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)));
  }
}

class _VideoFrame extends StatelessWidget {
  const _VideoFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        const Center(
          child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
            child: Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.play_arrow, color: Colors.white, size: 22),
            ),
          ),
        ),
      ],
    );
  }
}

class _KindFallback extends StatelessWidget {
  const _KindFallback({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 40, color: AppColors.primary),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
