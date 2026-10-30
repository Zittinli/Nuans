import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import '../../models/patient_media.dart';
import '../../services/local_clinic_cache.dart';
import '../../theme/app_theme.dart';
import '../../utils/video_thumb.dart';

class PatientMediaScreen extends StatefulWidget {
  const PatientMediaScreen({super.key, required this.media, this.patientId});

  final PatientMedia media;
  final String? patientId;

  @override
  State<PatientMediaScreen> createState() => _PatientMediaScreenState();
}

class _PatientMediaScreenState extends State<PatientMediaScreen> {
  VideoPlayerController? _video;
  AudioPlayer? _audio;
  final List<StreamSubscription<dynamic>> _audioSubs = [];
  File? _photo;
  var _ready = false;
  String? _error;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  var _audioPlaying = false;
  var _audioDone = false;
  var _speed = 1.0;
  double? _drag;
  DateTime _lastVideoTick = DateTime.fromMillisecondsSinceEpoch(0);
  var _videoWasPlaying = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final media = widget.media;
    final patientId = widget.patientId;
    final local = patientId == null ? null : await LocalClinicCache().mediaFile(patientId, media.id);
    if (!mounted) return;
    if (media.kind == PatientMediaKind.video) {
      final controller = local != null
          ? VideoPlayerController.file(local)
          : VideoPlayerController.networkUrl(Uri.parse(media.url));
      _video = controller;
      controller.addListener(_onVideoTick);
      controller.initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        controller.play();
      }).catchError((Object error) {
        if (!mounted) return;
        setState(() => _error = '$error');
      });
    } else if (media.kind == PatientMediaKind.audio) {
      final player = AudioPlayer();
      _audio = player;
      _audioSubs.addAll([
        player.positionStream.listen((position) {
          if (!mounted || _drag != null) return;
          setState(() => _audioPosition = position);
        }),
        player.durationStream.listen((duration) {
          if (!mounted || duration == null) return;
          setState(() => _audioDuration = duration);
        }),
        player.playerStateStream.listen((state) {
          if (!mounted) return;
          setState(() {
            _audioPlaying = state.playing;
            _audioDone = state.processingState == ProcessingState.completed;
          });
        }),
      ]);
      final ready = local != null ? player.setFilePath(local.path) : player.setUrl(media.url);
      ready.then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        player.play();
      }).catchError((Object error) {
        if (!mounted) return;
        setState(() => _error = '$error');
      });
    } else if (local != null) {
      setState(() => _photo = local);
    }
  }

  void _onVideoTick() {
    final controller = _video;
    if (controller == null || !mounted) return;
    final playing = controller.value.isPlaying;
    final now = DateTime.now();
    if (playing == _videoWasPlaying && now.difference(_lastVideoTick) < const Duration(milliseconds: 200)) {
      return;
    }
    _videoWasPlaying = playing;
    _lastVideoTick = now;
    setState(() {});
  }

  @override
  void dispose() {
    _video?.removeListener(_onVideoTick);
    _video?.dispose();
    for (final sub in _audioSubs) {
      sub.cancel();
    }
    _audio?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    return Scaffold(
      appBar: AppBar(title: Text(media.title)),
      body: switch (media.kind) {
        PatientMediaKind.photo => InteractiveViewer(
            child: Center(
              child: _photo != null ? Image.file(_photo!) : Image.network(media.url),
            ),
          ),
        PatientMediaKind.video => _stage(
            ready: _ready && _video != null,
            media: _fittedVideo(),
            position: _video?.value.position ?? Duration.zero,
            duration: _video?.value.duration ?? Duration.zero,
            playing: _video?.value.isPlaying ?? false,
            onToggle: () {
              final controller = _video;
              if (controller == null) return;
              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
            },
            onSeek: (target) => _video?.seekTo(target),
          ),
        PatientMediaKind.audio => _audioBody(),
      },
    );
  }

  Future<void> _toggleAudio() async {
    final player = _audio;
    if (player == null) return;
    if (player.playing) {
      await player.pause();
      return;
    }
    if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero);
    }
    await player.play();
  }

  Future<void> _skipAudio(Duration delta) async {
    final player = _audio;
    if (player == null || !_ready) return;
    var target = player.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (_audioDuration > Duration.zero && target > _audioDuration) target = _audioDuration;
    await player.seek(target);
  }

  Future<void> _setAudioSpeed(double speed) async {
    setState(() => _speed = speed);
    await _audio?.setSpeed(speed);
  }

  Widget _audioBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Dosya açılamadı: $_error', textAlign: TextAlign.center),
        ),
      );
    }
    final media = widget.media;
    final duration = _audioDuration;
    final position = _drag == null || duration <= Duration.zero ? _audioPosition : duration * _drag!;
    final remaining = duration - position;
    final left = remaining.isNegative ? Duration.zero : remaining;
    final totalMs = duration.inMilliseconds;
    final fraction = totalMs <= 0 ? 0.0 : (position.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final recorded = DateFormat('d MMMM yyyy HH:mm', 'tr_TR').format(media.createdAt);
    final sessionWhen = media.sessionStartsAt == null
        ? null
        : DateFormat('d MMMM yyyy HH:mm', 'tr_TR').format(media.sessionStartsAt!);
    final status = !_ready
        ? 'Hazırlanıyor'
        : _audioPlaying
            ? 'Çalıyor'
            : _audioDone
                ? 'Bitti'
                : 'Duraklatıldı';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            children: [
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(color: AppColors.chip, shape: BoxShape.circle),
                  child: const Icon(Icons.mic_none, size: 46, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _clock(position),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                status,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Geçen ${_clock(position)} · Kalan ${_clock(left)} · Toplam ${_clock(duration)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, height: 1.35),
              ),
              const SizedBox(height: 18),
              _audioFact('Kayıt zamanı', recorded),
              if (media.sessionTitle != null && media.sessionTitle!.trim().isNotEmpty)
                _audioFact('Görüşme', media.sessionTitle!.trim()),
              if (sessionWhen != null) _audioFact('Görüşme zamanı', sessionWhen),
              _audioFact('Dosya', media.fileName),
              _audioFact('Hız', _speedLabel(_speed)),
              const SizedBox(height: 8),
              const Text('Oynatma hızı', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final speed in const [0.75, 1.0, 1.25, 1.5, 2.0])
                    ChoiceChip(
                      label: Text(_speedLabel(speed)),
                      selected: _speed == speed,
                      onSelected: !_ready ? null : (_) => _setAudioSpeed(speed),
                    ),
                ],
              ),
            ],
          ),
        ),
        Material(
          color: Colors.white,
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: (_drag ?? fraction).clamp(0.0, 1.0),
                  onChanged: !_ready || totalMs <= 0 ? null : (value) => setState(() => _drag = value),
                  onChangeEnd: (value) {
                    _audio?.seek(duration * value);
                    setState(() => _drag = null);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _skipButton(icon: Icons.replay, label: '15 sn geri', onPressed: () => _skipAudio(const Duration(seconds: -15))),
                    const SizedBox(width: 18),
                    IconButton.filled(
                      onPressed: _ready ? _toggleAudio : null,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.border,
                        minimumSize: const Size(64, 64),
                        iconSize: 32,
                      ),
                      icon: Icon(_audioPlaying ? Icons.pause : Icons.play_arrow),
                    ),
                    const SizedBox(width: 18),
                    _skipButton(icon: Icons.forward, label: '15 sn ileri', onPressed: () => _skipAudio(const Duration(seconds: 15))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _skipButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: label,
          onPressed: _ready ? onPressed : null,
          icon: Icon(icon, color: AppColors.primary),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ],
    );
  }

  Widget _audioFact(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  String _speedLabel(double speed) {
    final digits = speed == speed.roundToDouble() ? 0 : 2;
    return '${speed.toStringAsFixed(digits).replaceAll('.', ',')}×';
  }

  Widget _fittedVideo() {
    final controller = _video;
    if (controller == null) return const SizedBox.shrink();
    final ratio = controller.value.aspectRatio;
    final aspect = ratio <= 0 || ratio.isNaN ? 16 / 9 : ratio;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        var width = maxWidth;
        var height = width / aspect;
        if (height > maxHeight) {
          height = maxHeight;
          width = height * aspect;
        }
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: VideoPlayer(controller),
          ),
        );
      },
    );
  }

  Widget _stage({
    required bool ready,
    required Widget media,
    required Duration position,
    required Duration duration,
    required bool playing,
    required VoidCallback onToggle,
    required ValueChanged<Duration> onSeek,
  }) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Dosya açılamadı: $_error', textAlign: TextAlign.center),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ready ? media : _loading(),
        ),
        _controls(
          enabled: ready,
          position: position,
          duration: duration,
          playing: playing,
          onToggle: onToggle,
          onSeek: onSeek,
        ),
      ],
    );
  }

  Widget _loading() {
    final thumb = widget.media.thumbnailUrl;
    final cached = cachedVideoThumb(widget.media.id);
    if (widget.media.kind == PatientMediaKind.video &&
        ((thumb != null && thumb.isNotEmpty) || cached != null)) {
      return Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          if (cached != null)
            Image.memory(cached, fit: BoxFit.contain)
          else
            Image.network(thumb!, fit: BoxFit.contain),
          const CircularProgressIndicator(),
        ],
      );
    }
    return const Center(child: CircularProgressIndicator());
  }

  Widget _controls({
    required bool enabled,
    required Duration position,
    required Duration duration,
    required bool playing,
    required VoidCallback onToggle,
    required ValueChanged<Duration> onSeek,
  }) {
    final totalMs = duration.inMilliseconds;
    final fraction = totalMs <= 0 ? 0.0 : (position.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final shown = _drag ?? fraction;
    return Material(
      color: Colors.white,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Text(_clock(position), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ),
                Expanded(
                  child: Slider(
                    value: shown.clamp(0.0, 1.0),
                    onChanged: !enabled || totalMs <= 0
                        ? null
                        : (value) => setState(() => _drag = value),
                    onChangeEnd: (value) {
                      onSeek(duration * value);
                      setState(() => _drag = null);
                    },
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    _clock(duration),
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
              ],
            ),
            IconButton.filled(
              onPressed: enabled ? onToggle : null,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.border,
                minimumSize: const Size(64, 64),
                iconSize: 32,
              ),
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            ),
          ],
        ),
      ),
    );
  }

  String _clock(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }
}
