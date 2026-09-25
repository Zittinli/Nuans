import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/appointment.dart';
import '../models/clinic_form.dart';
import '../models/note.dart';
import '../models/patient.dart';

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

  CollectionReference<Map<String, dynamic>> _notes(String patientId) =>
      _patients.doc(patientId).collection('notes');

  CollectionReference<Map<String, dynamic>> _forms(String patientId) =>
      _patients.doc(patientId).collection('forms');

  Stream<List<Patient>> watchPatients() {
    return _patients.orderBy('updatedAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map(Patient.fromDoc).toList(),
        );
  }

  Future<void> savePatient(Patient patient) async {
    final now = DateTime.now();
    final data = patient.copyWith(updatedAt: now).toMap();
    if (patient.id.isEmpty) {
      data['createdAt'] = Timestamp.fromDate(now);
      data['updatedAt'] = Timestamp.fromDate(now);
      await _patients.add(data);
      return;
    }
    final batch = _db.batch();
    batch.set(_patients.doc(patient.id), data, SetOptions(merge: true));
    final related = await _appointments.where('patientId', isEqualTo: patient.id).get();
    for (final doc in related.docs) {
      batch.update(doc.reference, {'patientName': patient.fullName});
    }
    await batch.commit();
  }

  Future<void> deletePatient(String patientId) async {
    final notes = await _notes(patientId).get();
    final forms = await _forms(patientId).get();
    final appointments = await _appointments.where('patientId', isEqualTo: patientId).get();
    final batch = _db.batch();
    for (final doc in notes.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in forms.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in appointments.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_patients.doc(patientId));
    await batch.commit();
    try {
      final folder = await _storage.ref('doctors/$_uid/patients/$patientId').listAll();
      for (final prefix in folder.prefixes) {
        final nested = await prefix.listAll();
        for (final item in nested.items) {
          await item.delete();
        }
      }
      for (final item in folder.items) {
        await item.delete();
      }
    } catch (_) {}
  }

  Stream<List<Note>> watchNotes(String patientId) {
    return _notes(patientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Note.fromDoc).toList());
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
    return _templates.orderBy('updatedAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map(ClinicFormTemplate.fromDoc).toList(),
        );
  }

  Future<String> saveFormTemplate(ClinicFormTemplate template) async {
    final now = DateTime.now();
    final data = template.toMap();
    data['updatedAt'] = Timestamp.fromDate(now);
    if (template.id.isEmpty) {
      data['createdAt'] = Timestamp.fromDate(now);
      final doc = await _templates.add(data);
      return doc.id;
    }
    await _templates.doc(template.id).set(data, SetOptions(merge: true));
    return template.id;
  }

  Future<void> deleteFormTemplate(String templateId) {
    return _templates.doc(templateId).delete();
  }

  Future<void> setFormTemplateActive(String templateId, bool active) async {
    await _templates.doc(templateId).set(
      {'active': active, 'updatedAt': Timestamp.fromDate(DateTime.now())},
      SetOptions(merge: true),
    );
  }

  Future<String> uploadFormTemplateSource({
    required String templateId,
    required File file,
    required String fileName,
  }) async {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'bin';
    final ref = _storage.ref('doctors/$_uid/formTemplates/$templateId/source.$ext');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Stream<List<PatientFormEntry>> watchPatientForms(String patientId) {
    return _forms(patientId).orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map(PatientFormEntry.fromDoc).toList(),
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
    }
    return urls;
  }

  Future<List<int>?> downloadBytes(String url) async {
    try {
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
