import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../models/clinic_form.dart';
import '../models/note.dart';
import '../models/patient.dart';
import '../models/patient_media.dart';

class LocalClinicCache {
  LocalClinicCache({
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  static final _downloads = <String>{};

  String? get _uid => _auth.currentUser?.uid;

  Stream<List<T>> mirrorSnapshots<T>({
    required Stream<QuerySnapshot<Map<String, dynamic>>> snapshots,
    required List<T> Function(QuerySnapshot<Map<String, dynamic>> snapshot) decode,
    required Future<List<T>> Function() read,
    required Future<void> Function(List<T> items) write,
  }) {
    return Stream<List<T>>.multi((listener) {
      var open = true;
      read().then((local) {
        if (open && local.isNotEmpty) listener.add(local);
      }).catchError((Object _) {});
      final sub = snapshots.listen(
        (snapshot) async {
          final items = decode(snapshot);
          if (items.isEmpty && snapshot.metadata.isFromCache) {
            final local = await _stored(read);
            if (open) listener.add(local);
            return;
          }
          try {
            await write(items);
          } catch (_) {}
          if (open) listener.add(items);
        },
        onError: (Object error, StackTrace stack) async {
          final local = await _stored(read);
          if (!open) return;
          if (local.isNotEmpty) {
            listener.add(local);
          } else {
            listener.addError(error, stack);
          }
        },
        onDone: () {
          if (open) listener.close();
        },
      );
      listener.onCancel = () {
        open = false;
        sub.cancel();
      };
    });
  }

  Future<List<T>> _stored<T>(Future<List<T>> Function() read) async {
    try {
      return await read();
    } catch (_) {
      return <T>[];
    }
  }

  Future<void> writePatients(List<Patient> patients) {
    return _writeList(
      'patients.json',
      patients
          .map(
            (patient) => {
              'id': patient.id,
              'fullName': patient.fullName,
              'identityNumber': patient.identityNumber,
              'birthDate': patient.birthDate?.toIso8601String(),
              'gender': patient.gender,
              'phone': patient.phone,
              'diagnosis': patient.diagnosis,
              'referrer': patient.referrer,
              'createdAt': patient.createdAt.toIso8601String(),
              'updatedAt': patient.updatedAt.toIso8601String(),
            },
          )
          .toList(),
    );
  }

  Future<List<Patient>> readPatients() async {
    final rows = await _readList('patients.json');
    return rows
        .map(
          (row) => Patient(
            id: row['id'] as String? ?? '',
            fullName: row['fullName'] as String? ?? '',
            identityNumber: row['identityNumber'] as String?,
            birthDate: _dateOrNull(row['birthDate']),
            gender: row['gender'] as String? ?? 'Belirtilmedi',
            phone: row['phone'] as String?,
            diagnosis: row['diagnosis'] as String?,
            referrer: row['referrer'] as String?,
            createdAt: _date(row['createdAt']),
            updatedAt: _date(row['updatedAt']),
          ),
        )
        .where((patient) => patient.id.isNotEmpty)
        .toList();
  }

  Future<void> writeNotes(String patientId, List<Note> notes) {
    return _writeList(
      _patientFile(patientId, 'notes.json'),
      notes
          .map(
            (note) => {
              'id': note.id,
              'title': note.title,
              'content': note.content,
              'type': note.type.name,
              'createdAt': note.createdAt.toIso8601String(),
              'updatedAt': note.updatedAt.toIso8601String(),
            },
          )
          .toList(),
    );
  }

  Future<List<Note>> readNotes(String patientId) async {
    final rows = await _readList(_patientFile(patientId, 'notes.json'));
    return rows
        .map(
          (row) => Note(
            id: row['id'] as String? ?? '',
            title: row['title'] as String? ?? '',
            content: row['content'] as String? ?? '',
            type: NoteType.fromName(row['type'] as String?),
            createdAt: _date(row['createdAt']),
            updatedAt: _date(row['updatedAt']),
          ),
        )
        .where((note) => note.id.isNotEmpty)
        .toList();
  }

  Future<void> writeForms(String patientId, List<PatientFormEntry> forms) {
    return _writeList(
      _patientFile(patientId, 'forms.json'),
      forms
          .map(
            (entry) => {
              'id': entry.id,
              'templateId': entry.templateId,
              'title': entry.title,
              'source': entry.source.name,
              'values': _jsonSafe(entry.values),
              'scanUrls': entry.scanUrls,
              'createdAt': entry.createdAt.toIso8601String(),
              'updatedAt': entry.updatedAt.toIso8601String(),
            },
          )
          .toList(),
    );
  }

  Future<List<PatientFormEntry>> readForms(String patientId) async {
    final rows = await _readList(_patientFile(patientId, 'forms.json'));
    return rows
        .map(
          (row) => PatientFormEntry(
            id: row['id'] as String? ?? '',
            templateId: row['templateId'] as String?,
            title: row['title'] as String? ?? 'Form',
            source: PatientFormSource.fromName(row['source'] as String?),
            values: Map<String, dynamic>.from(row['values'] as Map? ?? {}),
            scanUrls: (row['scanUrls'] as List?)?.map((item) => '$item').toList() ?? const [],
            createdAt: _date(row['createdAt']),
            updatedAt: _date(row['updatedAt']),
          ),
        )
        .where((entry) => entry.id.isNotEmpty)
        .toList();
  }

  Future<void> writeMedia(String patientId, List<PatientMedia> items) {
    return _writeList(
      _patientFile(patientId, 'media.json'),
      items
          .map(
            (media) => {
              'id': media.id,
              'kind': media.kind.name,
              'fileName': media.fileName,
              'storagePath': media.storagePath,
              'url': media.url,
              'contentType': media.contentType,
              'createdAt': media.createdAt.toIso8601String(),
              'displayName': media.displayName,
              'thumbnailUrl': media.thumbnailUrl,
              'thumbnailPath': media.thumbnailPath,
              'sessionId': media.sessionId,
              'sessionTitle': media.sessionTitle,
              'sessionStartsAt': media.sessionStartsAt?.toIso8601String(),
            },
          )
          .toList(),
    );
  }

  Future<List<PatientMedia>> readMedia(String patientId) async {
    final rows = await _readList(_patientFile(patientId, 'media.json'));
    return rows
        .map(
          (row) => PatientMedia(
            id: row['id'] as String? ?? '',
            kind: PatientMediaKind.fromName(row['kind'] as String?),
            fileName: row['fileName'] as String? ?? 'dosya',
            storagePath: row['storagePath'] as String? ?? '',
            url: row['url'] as String? ?? '',
            contentType: row['contentType'] as String? ?? '',
            createdAt: _date(row['createdAt']),
            displayName: row['displayName'] as String?,
            thumbnailUrl: row['thumbnailUrl'] as String?,
            thumbnailPath: row['thumbnailPath'] as String?,
            sessionId: row['sessionId'] as String?,
            sessionTitle: row['sessionTitle'] as String?,
            sessionStartsAt: _dateOrNull(row['sessionStartsAt']),
          ),
        )
        .where((media) => media.id.isNotEmpty)
        .toList();
  }

  Future<void> keepMediaFile({
    required String patientId,
    required String mediaId,
    required File source,
    required String fileName,
    required String contentType,
  }) async {
    if (!await source.exists()) return;
    final ext = _extension(fileName, contentType);
    final name = '$mediaId$ext';
    final dest = await _mediaFile(patientId, name);
    if (source.absolute.path != dest.absolute.path) {
      await dest.parent.create(recursive: true);
      await source.copy(dest.path);
    }
    await _rememberMediaFile(patientId, mediaId, name);
  }

  Future<File?> mediaFile(String patientId, String mediaId) async {
    final index = await _readObject(_patientFile(patientId, 'media-files.json'));
    final name = index[mediaId] as String?;
    if (name == null || name.isEmpty) return null;
    final file = await _mediaFile(patientId, name);
    if (await file.exists() && await file.length() > 0) return file;
    return null;
  }

  Future<void> deleteMediaFile(String patientId, String mediaId) async {
    final file = await mediaFile(patientId, mediaId);
    if (file != null && await file.exists()) {
      await file.delete();
    }
    final index = await _readObject(_patientFile(patientId, 'media-files.json'));
    index.remove(mediaId);
    await _writeObject(_patientFile(patientId, 'media-files.json'), index);
  }

  Future<void> ensureMediaFile({
    required String patientId,
    required PatientMedia media,
  }) async {
    final uid = _uid;
    if (uid == null || media.storagePath.isEmpty) return;
    final key = '$uid/$patientId/${media.id}';
    if (_downloads.contains(key)) return;
    if (await mediaFile(patientId, media.id) != null) return;
    _downloads.add(key);
    try {
      final ext = _extension(media.fileName, media.contentType);
      final name = '${media.id}$ext';
      final dest = await _mediaFile(patientId, name);
      await dest.parent.create(recursive: true);
      await _storage.ref(media.storagePath).writeToFile(dest);
      if (await dest.exists() && await dest.length() > 0) {
        await _rememberMediaFile(patientId, media.id, name);
      }
    } catch (_) {
    } finally {
      _downloads.remove(key);
    }
  }

  Future<void> keepScanFile({
    required String patientId,
    required String formId,
    required int index,
    required File source,
  }) async {
    if (!await source.exists()) return;
    final dest = await _scanFile(patientId, formId, index);
    await dest.parent.create(recursive: true);
    if (source.absolute.path != dest.absolute.path) {
      await source.copy(dest.path);
    }
  }

  Future<File?> scanFile(String patientId, String formId, int index) async {
    final file = await _scanFile(patientId, formId, index);
    if (await file.exists() && await file.length() > 0) return file;
    return null;
  }

  Future<void> ensureScanFile({
    required String patientId,
    required String formId,
    required int index,
    required String storagePath,
  }) async {
    final uid = _uid;
    if (uid == null || storagePath.isEmpty) return;
    final key = '$uid/$patientId/$formId/scan_$index';
    if (_downloads.contains(key)) return;
    if (await scanFile(patientId, formId, index) != null) return;
    _downloads.add(key);
    try {
      final dest = await _scanFile(patientId, formId, index);
      await dest.parent.create(recursive: true);
      await _storage.ref(storagePath).writeToFile(dest);
    } catch (_) {
    } finally {
      _downloads.remove(key);
    }
  }

  Future<void> deletePatient(String patientId) async {
    final dir = await _patientDir(patientId, create: false);
    if (dir != null && await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> _rememberMediaFile(String patientId, String mediaId, String name) async {
    final index = await _readObject(_patientFile(patientId, 'media-files.json'));
    index[mediaId] = name;
    await _writeObject(_patientFile(patientId, 'media-files.json'), index);
  }

  Future<File> _mediaFile(String patientId, String name) async {
    final dir = await _patientDir(patientId, create: true);
    return File('${dir!.path}/files/$name');
  }

  Future<File> _scanFile(String patientId, String formId, int index) async {
    final dir = await _patientDir(patientId, create: true);
    return File('${dir!.path}/scans/${formId}_$index.jpg');
  }

  String _patientFile(String patientId, String name) => 'patients/$patientId/$name';

  Future<Directory?> _root({required bool create}) async {
    final uid = _uid;
    if (uid == null) return null;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/offline/$uid');
    if (create && !await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory?> _patientDir(String patientId, {required bool create}) async {
    final root = await _root(create: create);
    if (root == null) return null;
    final dir = Directory('${root.path}/patients/$patientId');
    if (create && !await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _writeList(String relative, List<Map<String, dynamic>> rows) async {
    final root = await _root(create: true);
    if (root == null) return;
    final file = File('${root.path}/$relative');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(rows));
  }

  Future<List<Map<String, dynamic>>> _readList(String relative) async {
    final root = await _root(create: false);
    if (root == null) return const [];
    final file = File('${root.path}/$relative');
    if (!await file.exists()) return const [];
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) return const [];
    return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<Map<String, dynamic>> _readObject(String relative) async {
    final root = await _root(create: false);
    if (root == null) return {};
    final file = File('${root.path}/$relative');
    if (!await file.exists()) return {};
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) return {};
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _writeObject(String relative, Map<String, dynamic> data) async {
    final root = await _root(create: true);
    if (root == null) return;
    final file = File('${root.path}/$relative');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data));
  }

  String _extension(String fileName, String contentType) {
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
}

DateTime _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}

DateTime? _dateOrNull(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

dynamic _jsonSafe(dynamic value) {
  if (value is Timestamp) return value.toDate().toIso8601String();
  if (value is DateTime) return value.toIso8601String();
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', _jsonSafe(item)));
  }
  if (value is List) return value.map(_jsonSafe).toList();
  return value;
}
