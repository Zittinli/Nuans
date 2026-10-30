import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../theme/app_theme.dart';

/// Kayıt dosyasının yolunu döndürür. Vazgeçilirse null.
Future<String?> showAudioRecordSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: true,
    builder: (context) => const _AudioRecordSheet(),
  );
}

class _AudioRecordSheet extends StatefulWidget {
  const _AudioRecordSheet();

  @override
  State<_AudioRecordSheet> createState() => _AudioRecordSheetState();
}

enum _RecordPhase { idle, recording, paused, ready }

class _AudioRecordSheetState extends State<_AudioRecordSheet> {
  final _recorder = AudioRecorder();
  final _watch = Stopwatch();
  Timer? _ticker;
  _RecordPhase _phase = _RecordPhase.idle;
  String? _path;
  String? _error;

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _tick() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      final allowed = await _recorder.hasPermission();
      if (!allowed) {
        if (mounted) setState(() => _error = 'Mikrofon izni verilmedi.');
        return;
      }
      if (_path != null) {
        final old = File(_path!);
        if (await old.exists()) await old.delete();
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}${Platform.pathSeparator}ses_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      _watch
        ..reset()
        ..start();
      _tick();
      if (!mounted) return;
      setState(() {
        _path = path;
        _phase = _RecordPhase.recording;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Kayıt başlatılamadı: $error');
    }
  }

  Future<void> _pause() async {
    try {
      await _recorder.pause();
      _watch.stop();
      if (!mounted) return;
      setState(() => _phase = _RecordPhase.paused);
    } catch (error) {
      if (mounted) setState(() => _error = 'Duraklatılamadı: $error');
    }
  }

  Future<void> _resume() async {
    try {
      await _recorder.resume();
      _watch.start();
      _tick();
      if (!mounted) return;
      setState(() => _phase = _RecordPhase.recording);
    } catch (error) {
      if (mounted) setState(() => _error = 'Kayıt sürdürülemedi: $error');
    }
  }

  Future<void> _stop() async {
    try {
      final saved = await _recorder.stop();
      _watch.stop();
      _ticker?.cancel();
      if (_watch.elapsed < const Duration(milliseconds: 700)) {
        final path = saved ?? _path;
        if (path != null) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
        _watch.reset();
        if (!mounted) return;
        setState(() {
          _path = null;
          _phase = _RecordPhase.idle;
          _error = 'Kayıt çok kısa. Biraz daha uzun kaydedin.';
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _path = saved ?? _path;
        _phase = _RecordPhase.ready;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Kayıt durdurulamadı: $error');
    }
  }

  Future<void> _discard() async {
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {}
    final path = _path;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    if (mounted) Navigator.pop(context);
  }

  String get _clock {
    final elapsed = _watch.elapsed;
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get _status => switch (_phase) {
        _RecordPhase.idle => 'Hazır',
        _RecordPhase.recording => 'Kayıt sürüyor',
        _RecordPhase.paused => 'Duraklatıldı',
        _RecordPhase.ready => 'Kayıt hazır',
      };

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Ses kaydı', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            'O an kaydedin, duraklatın veya durdurup hastaya ekleyin.',
            style: TextStyle(color: AppColors.muted, height: 1.35),
          ),
          const SizedBox(height: 18),
          Text(
            _clock,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 18),
          ..._actions(),
        ],
      ),
    );
  }

  List<Widget> _actions() {
    switch (_phase) {
      case _RecordPhase.idle:
        return [
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.fiber_manual_record),
            label: const Text('Kaydı başlat'),
          ),
          TextButton(onPressed: _discard, child: const Text('Vazgeç')),
        ];
      case _RecordPhase.recording:
        return [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pause,
                  icon: const Icon(Icons.pause),
                  label: const Text('Duraklat'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _stop,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                  icon: const Icon(Icons.stop),
                  label: const Text('Durdur'),
                ),
              ),
            ],
          ),
          TextButton(onPressed: _discard, child: const Text('Kaydı iptal et')),
        ];
      case _RecordPhase.paused:
        return [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _resume,
                  icon: const Icon(Icons.mic),
                  label: const Text('Sürdür'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _stop,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                  icon: const Icon(Icons.stop),
                  label: const Text('Durdur'),
                ),
              ),
            ],
          ),
          TextButton(onPressed: _discard, child: const Text('Kaydı iptal et')),
        ];
      case _RecordPhase.ready:
        return [
          FilledButton.icon(
            onPressed: _path == null ? null : () => Navigator.pop(context, _path),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Hastaya ekle'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.replay),
            label: const Text('Yeniden kaydet'),
          ),
          TextButton(onPressed: _discard, child: const Text('Vazgeç')),
        ];
    }
  }
}
