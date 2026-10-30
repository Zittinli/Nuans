import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'clinic_service.dart';

class MediaUploadItem {
  MediaUploadItem({
    required this.id,
    required this.patientId,
    required this.displayName,
    required this.state,
    required this.progress,
  });

  final String id;
  final String patientId;
  final String displayName;
  String state;
  double progress;

  bool get uploading => state == 'uploading';
}

class _PendingUpload {
  _PendingUpload({
    required this.id,
    required this.patientId,
    required this.path,
    required this.fileName,
    required this.contentType,
    required this.displayName,
    this.sessionId,
    this.sessionTitle,
    this.sessionStartsAt,
  });

  final String id;
  final String patientId;
  final String path;
  final String fileName;
  final String contentType;
  final String displayName;
  final String? sessionId;
  final String? sessionTitle;
  final DateTime? sessionStartsAt;
  String state = 'queued';
  double progress = 0;
  UploadTask? task;
}

class MediaUploadQueue extends ChangeNotifier {
  MediaUploadQueue._();

  static final instance = MediaUploadQueue._();

  final items = <MediaUploadItem>[];
  final notice = ValueNotifier<String?>(null);
  final _jobs = <_PendingUpload>[];
  final _cancelled = <String>{};
  var _busy = false;
  var _serviceReady = false;
  var _noteBusy = false;
  var _noteDirty = false;
  var _note = '';

  void prepare() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'media_upload',
        channelName: 'Medya yükleme',
        channelDescription: 'Hasta medyası sunucuya kaydedilirken görünür.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  List<MediaUploadItem> forPatient(String patientId) {
    return items.where((item) => item.patientId == patientId).toList();
  }

  Future<void> enqueue({
    required String patientId,
    required String path,
    required String fileName,
    required String contentType,
    required String displayName,
    String? sessionId,
    String? sessionTitle,
    DateTime? sessionStartsAt,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      notice.value = 'Dosya bulunamadı.';
      return;
    }
    _jobs.add(
      _PendingUpload(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        patientId: patientId,
        path: path,
        fileName: fileName,
        contentType: contentType,
        displayName: displayName,
        sessionId: sessionId,
        sessionTitle: sessionTitle,
        sessionStartsAt: sessionStartsAt,
      ),
    );
    _publish();
    unawaited(_pump());
  }

  void requestCancel(String id) {
    _cancelled.add(id);
    final job = _jobs.where((item) => item.id == id).firstOrNull;
    if (job == null) return;
    if (job.state == 'uploading') {
      job.task?.cancel();
      return;
    }
    _jobs.remove(job);
    _publish();
  }

  Future<void> _pump() async {
    if (_busy) return;
    _busy = true;
    try {
      while (true) {
        final index = _jobs.indexWhere((item) => item.state == 'queued' && !_cancelled.contains(item.id));
        if (index < 0) break;
        final job = _jobs[index];
        job.state = 'uploading';
        _publish();
        try {
          await ClinicService().uploadPatientMedia(
            patientId: job.patientId,
            file: File(job.path),
            fileName: job.fileName,
            contentType: job.contentType,
            displayName: job.displayName,
            sessionId: job.sessionId,
            sessionTitle: job.sessionTitle,
            sessionStartsAt: job.sessionStartsAt,
            onTask: (task) => job.task = task,
            isCancelled: () => _cancelled.contains(job.id),
            onProgress: (value) {
              job.progress = value;
              _publish();
            },
          );
          _jobs.remove(job);
        } on FirebaseException catch (error) {
          _jobs.remove(job);
          if (error.code != 'canceled') {
            notice.value = '${job.displayName} yüklenemedi.';
          }
        } catch (_) {
          _jobs.remove(job);
          notice.value = '${job.displayName} yüklenemedi.';
        }
        _publish();
      }
    } finally {
      _busy = false;
    }
    if (_jobs.any((item) => item.state == 'queued' && !_cancelled.contains(item.id))) {
      unawaited(_pump());
      return;
    }
    _jobs.removeWhere((item) => _cancelled.contains(item.id));
    _publish();
    if (_jobs.isEmpty) {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
      _serviceReady = false;
    }
  }

  void _publish() {
    items
      ..clear()
      ..addAll(
        _jobs.map(
          (job) => MediaUploadItem(
            id: job.id,
            patientId: job.patientId,
            displayName: job.displayName,
            state: job.state,
            progress: job.progress,
          ),
        ),
      );
    notifyListeners();
    final current = _jobs.where((item) => item.state == 'uploading').firstOrNull;
    if (_jobs.isEmpty || current == null && _jobs.every((item) => item.state != 'queued')) {
      return;
    }
    final active = current ?? _jobs.first;
    final percent = (active.progress * 100).round();
    unawaited(_showNotification('${_jobs.length} medya kaldı · ${active.displayName} %$percent'));
  }

  Future<void> _showNotification(String text) async {
    _note = text;
    if (_noteBusy) {
      _noteDirty = true;
      return;
    }
    _noteBusy = true;
    try {
      do {
        _noteDirty = false;
        final current = _note;
        if (!_serviceReady) {
          final permission = await FlutterForegroundTask.checkNotificationPermission();
          if (permission != NotificationPermission.granted) {
            await FlutterForegroundTask.requestNotificationPermission();
          }
        }
        if (await FlutterForegroundTask.isRunningService) {
          await FlutterForegroundTask.updateService(
            notificationTitle: 'Medya yükleniyor',
            notificationText: current,
          );
          _serviceReady = true;
          continue;
        }
        final result = await FlutterForegroundTask.startService(
          serviceId: 410,
          serviceTypes: [ForegroundServiceTypes.dataSync],
          notificationTitle: 'Medya yükleniyor',
          notificationText: current,
          callback: mediaUploadCallback,
        );
        _serviceReady = result is ServiceRequestSuccess;
      } while (_noteDirty);
    } catch (_) {
    } finally {
      _noteBusy = false;
    }
  }
}

@pragma('vm:entry-point')
void mediaUploadCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveTask());
}

class _KeepAliveTask extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
