import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/appointment.dart';
import '../models/clinic_form.dart';
import '../models/form_category.dart';
import '../models/note.dart';
import '../models/patient.dart';
import '../models/patient_media.dart';
import '../utils/video_thumb.dart';
import 'local_clinic_cache.dart';

class ClinicService {
  ClinicService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  late final LocalClinicCache _cache = LocalClinicCache(auth: _auth, storage: _storage);

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Oturum açık değil.');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _patients =>
      _db.collection('doctors').doc(_uid).collection('patients');

  CollectionReference<Map<String, dynamic>> get _appointments =>
      _db.collection('doctors').doc(_uid).collection('appointments');

  CollectionReference<Map<String, dynamic>> get _templates =>
      _db.collection('doctors').doc(_uid).collection('formTemplates');

  CollectionReference<Map<String, dynamic>> get _globalTemplates =>
      _db.collection('globalFormTemplates');

  CollectionReference<Map<String, dynamic>> get _formCategories =>
      _db.collection('formCategories');

  CollectionReference<Map<String, dynamic>> _notes(String patientId) =>
      _patients.doc(patientId).collection('notes');

  CollectionReference<Map<String, dynamic>> _forms(String patientId) =>
      _patients.doc(patientId).collection('forms');

  CollectionReference<Map<String, dynamic>> get _removedMedia =>
      _db.collection('doctors').doc(_uid).collection('removedMedia');

  CollectionReference<Map<String, dynamic>> _media(String patientId) =>
      _patients.doc(patientId).collection('media');

  Stream<List<Patient>> watchPatients() {
    return _cache.mirrorSnapshots(
      snapshots: _patients.orderBy('updatedAt', descending: true).snapshots(),
      decode: (snapshot) => snapshot.docs.map(Patient.fromDoc).toList(),
      read: _cache.readPatients,
      write: _cache.writePatients,
    );
  }

  Future<String> savePatient(Patient patient) async {
    final now = DateTime.now();
    final data = patient.copyWith(updatedAt: now).toMap();
    if (patient.id.isEmpty) {
      data['createdAt'] = Timestamp.fromDate(now);
      data['updatedAt'] = Timestamp.fromDate(now);
      final doc = await _patients.add(data);
      return doc.id;
    }
    final batch = _db.batch();
    batch.set(_patients.doc(patient.id), data, SetOptions(merge: true));
    final related = await _appointments.where('patientId', isEqualTo: patient.id).get();
    for (final doc in related.docs) {
      batch.update(doc.reference, {'patientName': patient.fullName});
    }
    await batch.commit();
    return patient.id;
  }

  Future<void> deletePatient(String patientId) async {
    final notes = await _notes(patientId).get();
    final forms = await _forms(patientId).get();
    final media = await _media(patientId).get();
    final appointments = await _appointments.where('patientId', isEqualTo: patientId).get();
    final batch = _db.batch();
    for (final doc in notes.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in forms.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in media.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in appointments.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_patients.doc(patientId));
    await batch.commit();
    await _cache.deletePatient(patientId);
    final kept = <String>{};
    try {
      final archived = await _removedMedia.where('patientId', isEqualTo: patientId).get();
      for (final doc in archived.docs) {
        final data = doc.data();
        final storagePath = data['storagePath'];
        final thumbnailPath = data['thumbnailPath'];
        if (storagePath is String && storagePath.isNotEmpty) kept.add(storagePath);
        if (thumbnailPath is String && thumbnailPath.isNotEmpty) kept.add(thumbnailPath);
      }
    } catch (_) {}
    try {
      final folder = await _storage.ref('doctors/$_uid/patients/$patientId').listAll();
      for (final prefix in folder.prefixes) {
        final nested = await prefix.listAll();
        for (final item in nested.items) {
          if (kept.contains(item.fullPath)) continue;
          await item.delete();
        }
      }
      for (final item in folder.items) {
        if (kept.contains(item.fullPath)) continue;
        await item.delete();
      }
    } catch (_) {}
  }

  Stream<List<Note>> watchNotes(String patientId) {
    return _cache.mirrorSnapshots(
      snapshots: _notes(patientId).orderBy('createdAt', descending: true).snapshots(),
      decode: (snapshot) => snapshot.docs.map(Note.fromDoc).toList(),
      read: () => _cache.readNotes(patientId),
      write: (notes) => _cache.writeNotes(patientId, notes),
    );
  }

  Future<void> saveNote(String patientId, Note note) async {
    final now = DateTime.now();
    final data = {
      'title': note.title,
      'content': note.content,
      'type': note.type.name,
      'updatedAt': Timestamp.fromDate(now),
    };
    if (note.id.isEmpty) {
      data['createdAt'] = Timestamp.fromDate(now);
      await _notes(patientId).add(data);
    } else {
      await _notes(patientId).doc(note.id).set(data, SetOptions(merge: true));
    }
    await _touchPatient(patientId, now);
  }

  Future<void> deleteNote(String patientId, String noteId) {
    return _notes(patientId).doc(noteId).delete();
  }

  Stream<List<Appointment>> watchAppointments() {
    return _appointments.snapshots().map((snapshot) {
      final items = snapshot.docs.map(Appointment.fromDoc).toList();
      items.sort((a, b) => a.startsAt.compareTo(b.startsAt));
      return items;
    });
  }

  Stream<List<Appointment>> watchPatientAppointments(String patientId) {
    return _appointments.where('patientId', isEqualTo: patientId).snapshots().map((snapshot) {
      final items = snapshot.docs.map(Appointment.fromDoc).toList();
      items.sort((a, b) => a.startsAt.compareTo(b.startsAt));
      return items;
    });
  }

  Future<void> saveAppointment(Appointment appointment) async {
    final now = DateTime.now();
    final data = appointment.toMap();
    data['updatedAt'] = Timestamp.fromDate(now);
    if (appointment.id.isEmpty) {
      data['createdAt'] = Timestamp.fromDate(now);
      await _appointments.add(data);
    } else {
      await _appointments.doc(appointment.id).set(data, SetOptions(merge: true));
    }
    await _touchPatient(appointment.patientId, now);
  }

  Future<void> deleteAppointment(String appointmentId) {
    return _appointments.doc(appointmentId).delete();
  }

  Stream<List<ClinicFormTemplate>> watchFormTemplates() {
    final controller = StreamController<List<ClinicFormTemplate>>();
    List<ClinicFormTemplate>? personal;
    List<ClinicFormTemplate>? global;

    void emit() {
      if (personal == null || global == null || controller.isClosed) return;
      final ownIds = personal!.map((item) => item.id).toSet();
      final sharedCopies = global!.where((item) {
        final sourceId = item.sourceTemplateId;
        return item.sourceDoctorId == _uid && sourceId != null && ownIds.contains(sourceId);
      });
      final hidden = sharedCopies.map((item) => item.listKey).toSet();
      controller.add([
        ...global!.where((item) => !hidden.contains(item.listKey)),
        ...personal!,
      ]);
    }

    final personalSub = _templates.orderBy('updatedAt', descending: true).snapshots().listen(
      (snapshot) {
        personal = snapshot.docs.map(ClinicFormTemplate.fromDoc).toList();
        emit();
      },
      onError: controller.addError,
    );
    final globalSub = _globalTemplates.orderBy('updatedAt', descending: true).snapshots().listen(
      (snapshot) {
        global = snapshot.docs
            .map((doc) => ClinicFormTemplate.fromDoc(doc, isGlobal: true))
            .toList();
        emit();
      },
      onError: (_) {
        global = const [];
        emit();
      },
    );

    controller.onCancel = () {
      personalSub.cancel();
      globalSub.cancel();
    };
    return controller.stream;
  }

  Stream<List<ClinicFormTemplate>> watchGlobalFormTemplates() {
    return _globalTemplates.orderBy('updatedAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => ClinicFormTemplate.fromDoc(doc, isGlobal: true)).toList(),
        );
  }

  Stream<List<FormCategory>> watchFormCategories() {
    return _formCategories.orderBy('sortOrder').snapshots().map((snapshot) {
      final items = snapshot.docs.map(FormCategory.fromDoc).toList();
      items.sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        if (order != 0) return order;
        return a.name.compareTo(b.name);
      });
      return items;
    });
  }

  /// Eksik varsayılan kategorileri ekler. Yazma yetkisi yoksa sessizce çıkar.
  Future<void> ensureDefaultFormCategories() async {
    try {
      final snapshot = await _formCategories.get();
      final existingIds = snapshot.docs.map((doc) => doc.id).toSet();
      final existingNames = snapshot.docs
          .map((doc) => '${doc.data()['name'] ?? doc.id}'.toLowerCase())
          .toSet();
      final now = DateTime.now();
      for (var i = 0; i < kDefaultFormCategoryCodes.length; i++) {
        final code = kDefaultFormCategoryCodes[i];
        if (existingIds.contains(code)) continue;
        if (existingNames.contains(code.toLowerCase())) continue;
        final category = FormCategory(
          id: code,
          name: code,
          sortOrder: i,
          createdAt: now,
          updatedAt: now,
        );
        await _formCategories.doc(code).set(category.toMap(), SetOptions(merge: true));
      }
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') return;
      rethrow;
    }
  }

  Future<String> saveFormCategory(FormCategory category) async {
    final now = DateTime.now();
    final data = category.copyWith(updatedAt: now).toMap();
    if (category.id.isEmpty) {
      data['createdAt'] = Timestamp.fromDate(now);
      final doc = await _formCategories.add(data);
      return doc.id;
    }
    data['updatedAt'] = Timestamp.fromDate(now);
    await _formCategories.doc(category.id).set(data, SetOptions(merge: true));
    return category.id;
  }

  Future<void> deleteFormCategory(String categoryId) {
    return _formCategories.doc(categoryId).delete();
  }

  CollectionReference<Map<String, dynamic>> _templateCollection(bool isGlobal) {
    return isGlobal ? _globalTemplates : _templates;
  }

  Future<String> saveFormTemplate(ClinicFormTemplate template) async {
    final now = DateTime.now();
    final user = _auth.currentUser;
    final data = template
        .copyWith(
          createdByUid: template.createdByUid ?? user?.uid,
          createdByEmail: template.createdByEmail ?? user?.email,
        )
        .toMap();
    data['updatedAt'] = Timestamp.fromDate(now);
    final col = _templateCollection(template.isGlobal);
    if (template.id.isEmpty) {
      data['createdAt'] = Timestamp.fromDate(now);
      final doc = await col.add(data);
      return doc.id;
    }
    await col.doc(template.id).set(data, SetOptions(merge: true));
    if (!template.isGlobal) {
      await _syncSharedCopy(template);
    }
    return template.id;
  }

  Future<void> _syncSharedCopy(ClinicFormTemplate template) async {
    final globalId = template.globalTemplateId;
    if (!template.visibleToEveryone || globalId == null || globalId.isEmpty) return;
    final shared = template.copyWith(
      id: globalId,
      isGlobal: true,
      visibleToEveryone: true,
      sourceDoctorId: template.sourceDoctorId ?? _uid,
      sourceTemplateId: template.id,
      updatedAt: DateTime.now(),
    );
    await _globalTemplates.doc(globalId).set(shared.toMap(), SetOptions(merge: true));
  }

  Future<void> setFormVisibleToEveryone(ClinicFormTemplate template, bool visible) async {
    if (template.isGlobal) return;
    final now = DateTime.now();
    final globalId = (template.globalTemplateId != null && template.globalTemplateId!.isNotEmpty)
        ? template.globalTemplateId!
        : _globalTemplates.doc().id;
    if (visible) {
      final shared = template.copyWith(
        id: globalId,
        isGlobal: true,
        active: template.active,
        visibleToEveryone: true,
        sourceDoctorId: _uid,
        sourceTemplateId: template.id,
        updatedAt: now,
      );
      await _globalTemplates.doc(globalId).set(shared.toMap());
      await _templates.doc(template.id).set(
        {
          'visibleToEveryone': true,
          'globalTemplateId': globalId,
          'updatedAt': Timestamp.fromDate(now),
        },
        SetOptions(merge: true),
      );
      return;
    }
    final existing = template.globalTemplateId;
    if (existing != null && existing.isNotEmpty) {
      await _globalTemplates.doc(existing).delete();
    }
    await _templates.doc(template.id).set(
      {
        'visibleToEveryone': false,
        'updatedAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> deleteFormTemplate(ClinicFormTemplate template) async {
    if (!template.isGlobal) {
      final globalId = template.globalTemplateId;
      if (globalId != null && globalId.isNotEmpty) {
        try {
          await _globalTemplates.doc(globalId).delete();
        } on FirebaseException catch (error) {
          if (error.code != 'permission-denied') rethrow;
        }
      }
    }
    await _templateCollection(template.isGlobal).doc(template.id).delete();
  }

  Future<void> setFormTemplateActive(ClinicFormTemplate template, bool active) async {
    final now = Timestamp.fromDate(DateTime.now());
    await _templateCollection(template.isGlobal).doc(template.id).set(
      {'active': active, 'updatedAt': now},
      SetOptions(merge: true),
    );
    final globalId = template.globalTemplateId;
    if (!template.isGlobal && template.visibleToEveryone && globalId != null && globalId.isNotEmpty) {
      await _globalTemplates.doc(globalId).set(
        {'active': active, 'updatedAt': now},
        SetOptions(merge: true),
      );
    }
  }

  Future<String> uploadFormTemplateSource({
    required String templateId,
    required File file,
    required String fileName,
    bool isGlobal = false,
  }) async {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'bin';
    final path = isGlobal
        ? 'globalFormTemplates/$templateId/source.$ext'
        : 'doctors/$_uid/formTemplates/$templateId/source.$ext';
    final ref = _storage.ref(path);
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Stream<List<PatientFormEntry>> watchPatientForms(String patientId) {
    return _cache.mirrorSnapshots(
      snapshots: _forms(patientId).orderBy('createdAt', descending: true).snapshots(),
      decode: (snapshot) => snapshot.docs.map(PatientFormEntry.fromDoc).toList(),
      read: () => _cache.readForms(patientId),
      write: (forms) async {
        await _cache.writeForms(patientId, forms);
        for (final entry in forms) {
          for (var i = 0; i < entry.scanUrls.length; i++) {
            unawaited(
              _cache.ensureScanFile(
                patientId: patientId,
                formId: entry.id,
                index: i,
                storagePath: 'doctors/$_uid/patients/$patientId/forms/${entry.id}/scan_$i.jpg',
              ),
            );
          }
        }
      },
    );
  }

  Future<String> savePatientForm(String patientId, PatientFormEntry entry) async {
    final now = DateTime.now();
    final data = entry.toMap();
    data['updatedAt'] = Timestamp.fromDate(now);
    late final String id;
    if (entry.id.isEmpty) {
      data['createdAt'] = Timestamp.fromDate(now);
      final doc = await _forms(patientId).add(data);
      id = doc.id;
    } else {
      await _forms(patientId).doc(entry.id).set(data, SetOptions(merge: true));
      id = entry.id;
    }
    await _touchPatient(patientId, now);
    return id;
  }

  Future<void> deletePatientForm(String patientId, String formId) async {
    await _forms(patientId).doc(formId).delete();
    try {
      final folder = await _storage.ref('doctors/$_uid/patients/$patientId/forms/$formId').listAll();
      for (final item in folder.items) {
        await item.delete();
      }
    } catch (_) {}
  }

  Future<List<String>> uploadFormScans({
    required String patientId,
    required String formId,
    required List<String> localPaths,
  }) async {
    final urls = <String>[];
    for (var i = 0; i < localPaths.length; i++) {
      final file = File(localPaths[i]);
      final ref = _storage.ref('doctors/$_uid/patients/$patientId/forms/$formId/scan_$i.jpg');
      await ref.putFile(file);
      urls.add(await ref.getDownloadURL());
      try {
        await _cache.keepScanFile(patientId: patientId, formId: formId, index: i, source: file);
      } catch (_) {}
    }
    return urls;
  }

  Stream<List<PatientMedia>> watchPatientMedia(String patientId) {
    return _cache.mirrorSnapshots(
      snapshots: _media(patientId).orderBy('createdAt', descending: true).snapshots(),
      decode: (snapshot) => snapshot.docs.map(PatientMedia.fromDoc).toList(),
      read: () => _cache.readMedia(patientId),
      write: (items) async {
        await _cache.writeMedia(patientId, items);
        for (final item in items) {
          unawaited(_cache.ensureMediaFile(patientId: patientId, media: item));
        }
      },
    );
  }

  Future<void> uploadPatientMedia({
    required String patientId,
    required File file,
    required String fileName,
    required String contentType,
    required String displayName,
    String? sessionId,
    String? sessionTitle,
    DateTime? sessionStartsAt,
    void Function(double progress)? onProgress,
    void Function(UploadTask task)? onTask,
    bool Function()? isCancelled,
  }) async {
    final id = _media(patientId).doc().id;
    final ext = _mediaExtension(fileName, contentType);
    final storagePath = 'doctors/$_uid/patients/$patientId/media/$id$ext';
    final ref = _storage.ref(storagePath);
    final task = ref.putFile(file, SettableMetadata(contentType: contentType));
    onTask?.call(task);
    if (onProgress != null) {
      task.snapshotEvents.listen((event) {
        final total = event.totalBytes;
        if (total > 0) onProgress(event.bytesTransferred / total);
      });
    }
    try {
      await task;
    } on FirebaseException catch (error) {
      if (error.code == 'canceled') {
        try {
          await ref.delete();
        } catch (_) {}
      }
      rethrow;
    }
    if (isCancelled?.call() == true) {
      try {
        await ref.delete();
      } catch (_) {}
      throw FirebaseException(plugin: 'firebase_storage', code: 'canceled', message: 'iptal');
    }
    final url = await ref.getDownloadURL();
    final now = DateTime.now();
    final kind = PatientMediaKind.fromContentType(contentType, fileName);
    await _media(patientId).doc(id).set({
      'kind': kind.name,
      'fileName': fileName,
      'storagePath': storagePath,
      'url': url,
      'contentType': contentType,
      'displayName': displayName,
      if (sessionId != null) 'sessionId': sessionId,
      if (sessionTitle != null) 'sessionTitle': sessionTitle,
      if (sessionStartsAt != null) 'sessionStartsAt': Timestamp.fromDate(sessionStartsAt),
      'createdAt': Timestamp.fromDate(now),
    });
    await _touchPatient(patientId, now);
    unawaited(_finishMediaSideFiles(
      patientId: patientId,
      mediaId: id,
      file: file,
      fileName: fileName,
      contentType: contentType,
      kind: kind,
    ));
  }

  Future<void> _finishMediaSideFiles({
    required String patientId,
    required String mediaId,
    required File file,
    required String fileName,
    required String contentType,
    required PatientMediaKind kind,
  }) async {
    try {
      await _cache.keepMediaFile(
        patientId: patientId,
        mediaId: mediaId,
        source: file,
        fileName: fileName,
        contentType: contentType,
      );
    } catch (_) {}
    if (kind != PatientMediaKind.video) return;
    final saved = await _storeVideoThumbnail(patientId: patientId, mediaId: mediaId, source: file.path);
    if (saved == null) return;
    try {
      await _media(patientId).doc(mediaId).set(
        {'thumbnailUrl': saved.url, 'thumbnailPath': saved.path},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  Future<void> renamePatientMedia(String patientId, String mediaId, String displayName) {
    return _media(patientId).doc(mediaId).set(
      {'displayName': displayName.trim()},
      SetOptions(merge: true),
    );
  }

  Future<void> deletePatientMedia(String patientId, PatientMedia media) async {
    if (media.kind == PatientMediaKind.video && media.storagePath.isNotEmpty) {
      await _removedMedia.doc(media.id).set({
        'patientId': patientId,
        'displayName': media.title,
        'fileName': media.fileName,
        'storagePath': media.storagePath,
        'url': media.url,
        'contentType': media.contentType,
        'kind': media.kind.name,
        if (media.thumbnailUrl != null) 'thumbnailUrl': media.thumbnailUrl,
        if (media.thumbnailPath != null) 'thumbnailPath': media.thumbnailPath,
        if (media.sessionId != null) 'sessionId': media.sessionId,
        if (media.sessionTitle != null) 'sessionTitle': media.sessionTitle,
        if (media.sessionStartsAt != null) 'sessionStartsAt': Timestamp.fromDate(media.sessionStartsAt!),
        'createdAt': Timestamp.fromDate(media.createdAt),
        'removedAt': FieldValue.serverTimestamp(),
      });
    }
    await _media(patientId).doc(media.id).delete();
    await _cache.deleteMediaFile(patientId, media.id);
    if (media.kind == PatientMediaKind.video) return;
    if (media.storagePath.isNotEmpty) {
      try {
        await _storage.ref(media.storagePath).delete();
      } catch (_) {}
    }
    final thumb = media.thumbnailPath;
    if (thumb != null && thumb.isNotEmpty) {
      try {
        await _storage.ref(thumb).delete();
      } catch (_) {}
    }
  }

  static final _thumbnailSaves = <String>{};

  Future<void> saveVideoThumbnail({
    required String patientId,
    required String mediaId,
    required Uint8List jpeg,
  }) async {
    if (jpeg.isEmpty || _thumbnailSaves.contains(mediaId)) return;
    _thumbnailSaves.add(mediaId);
    try {
      final stored = await _putThumbnail(patientId: patientId, mediaId: mediaId, jpeg: jpeg);
      await _media(patientId).doc(mediaId).set(
        {'thumbnailUrl': stored.url, 'thumbnailPath': stored.path},
        SetOptions(merge: true),
      );
    } catch (_) {
      _thumbnailSaves.remove(mediaId);
    }
  }

  Future<({String url, String path})?> _storeVideoThumbnail({
    required String patientId,
    required String mediaId,
    required String source,
  }) async {
    final jpeg = await videoThumbnailBytes(source);
    if (jpeg == null) return null;
    try {
      return await _putThumbnail(patientId: patientId, mediaId: mediaId, jpeg: jpeg);
    } catch (_) {
      return null;
    }
  }

  Future<({String url, String path})> _putThumbnail({
    required String patientId,
    required String mediaId,
    required Uint8List jpeg,
  }) async {
    final path = 'doctors/$_uid/patients/$patientId/media/${mediaId}_thumb.jpg';
    final ref = _storage.ref(path);
    await ref.putData(jpeg, SettableMetadata(contentType: 'image/jpeg'));
    return (url: await ref.getDownloadURL(), path: path);
  }

  String _mediaExtension(String fileName, String contentType) {
    final dot = fileName.lastIndexOf('.');
    if (dot >= 0 && dot < fileName.length - 1) {
      final ext = fileName.substring(dot).toLowerCase();
      if (ext.length <= 8 && !ext.contains('/') && !ext.contains('\\')) return ext;
    }
    final kind = PatientMediaKind.fromContentType(contentType, fileName);
    switch (kind) {
      case PatientMediaKind.video:
        return '.mp4';
      case PatientMediaKind.audio:
        return '.m4a';
      case PatientMediaKind.photo:
        return '.jpg';
    }
  }

  Future<List<int>?> downloadBytes(String url, {String? patientId, String? mediaId}) async {
    try {
      if (patientId != null && mediaId != null) {
        final local = await _cache.mediaFile(patientId, mediaId);
        if (local != null) return local.readAsBytes();
      }
      if (url.startsWith('http')) {
        return await _storage.refFromURL(url).getData();
      }
      final file = File(url);
      if (await file.exists()) {
        return file.readAsBytes();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _touchPatient(String patientId, DateTime now) {
    return _patients.doc(patientId).set(
      {'updatedAt': Timestamp.fromDate(now)},
      SetOptions(merge: true),
    );
  }
}
