import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/note.dart';
import '../models/patient.dart';

class ClinicService {
  ClinicService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Oturum açık değil.');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _patients =>
      _db.collection('doctors').doc(_uid).collection('patients');

  CollectionReference<Map<String, dynamic>> _notes(String patientId) =>
      _patients.doc(patientId).collection('notes');

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
    await _patients.doc(patient.id).set(data, SetOptions(merge: true));
  }

  Future<void> deletePatient(String patientId) async {
    final notes = await _notes(patientId).get();
    final batch = _db.batch();
    for (final doc in notes.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_patients.doc(patientId));
    await batch.commit();
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
    await _patients.doc(patientId).set(
      {'updatedAt': Timestamp.fromDate(now)},
      SetOptions(merge: true),
    );
  }

  Future<void> deleteNote(String patientId, String noteId) {
    return _notes(patientId).doc(noteId).delete();
  }
}
