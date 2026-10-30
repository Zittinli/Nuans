import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../config/admin_config.dart';
import '../models/app_permission.dart';
import '../models/clinic_form.dart';
import '../models/doctor.dart';
import '../models/note.dart';
import '../models/feedback_message.dart';
import '../models/patient.dart';
import '../models/patient_media.dart';

class AdminService {
  AdminService({FirebaseAuth? auth, FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _auth = auth ?? FirebaseAuth.instance,
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

  CollectionReference<Map<String, dynamic>> get _doctors => _db.collection('doctors');

  CollectionReference<Map<String, dynamic>> get _feedback => _db.collection('feedback');

  Future<void> sendFeedback({
    required String message,
    required String senderName,
    required String senderEmail,
    List<File> images = const [],
  }) async {
    final text = message.trim();
    if (text.isEmpty) {
      throw StateError('Mesaj boş olamaz.');
    }
    if (images.length > 4) {
      throw StateError('En fazla 4 fotoğraf eklenebilir.');
    }
    final ref = _feedback.doc();
    final urls = <String>[];
    for (var i = 0; i < images.length; i++) {
      final file = images[i];
      final stored = _storage.ref('feedback/$_uid/${ref.id}/$i.jpg');
      await stored.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      urls.add(await stored.getDownloadURL());
    }
    await ref.set({
      'message': text,
      'senderUid': _uid,
      'senderName': senderName.trim(),
      'senderEmail': senderEmail.trim(),
      'imageUrls': urls,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<FeedbackMessage>> watchFeedback() {
    return _feedback.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map(FeedbackMessage.fromDoc).toList(),
        );
  }

  Future<void> setFeedbackResolved(String id, {required bool resolved}) {
    return _feedback.doc(id).update({
      'resolved': resolved,
      'resolvedAt': resolved ? FieldValue.serverTimestamp() : FieldValue.delete(),
    });
  }

  CollectionReference<Map<String, dynamic>> _doctorCol(String doctorId, String name) =>
      _doctors.doc(doctorId).collection(name);

  Stream<List<Doctor>> watchAccounts() {
    return _doctors.snapshots().map((snapshot) {
      final items = snapshot.docs.map(Doctor.fromDoc).toList();
      items.sort((a, b) {
        if (a.isSuperAdmin != b.isSuperAdmin) return a.isSuperAdmin ? -1 : 1;
        return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      });
      return items;
    });
  }

  Future<void> setPermissions({
    required Doctor target,
    required Set<AppPermission> permissions,
    required Doctor actor,
  }) async {
    if (!actor.canManagePermissions) {
      throw StateError('Yetki değiştirme izniniz yok.');
    }
    if (target.isSuperAdmin || isSuperAdminEmail(target.email)) {
      throw StateError('Bu hesabın yetkisi alınamaz.');
    }
    if (target.id == _uid && !actor.isSuperAdmin) {
      final stillAdmin = permissions.contains(AppPermission.managePermissions);
      if (!stillAdmin && actor.id == target.id) {
        throw StateError('Kendi yönetim yetkinizi kaldıramazsınız.');
      }
    }
    await _doctors.doc(target.id).update({
      'permissions': permissions.map((item) => item.id).toList(),
    });
  }

  Stream<List<Patient>> watchPatients(String doctorId) {
    return _doctorCol(doctorId, 'patients').orderBy('updatedAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map(Patient.fromDoc).toList(),
        );
  }

  Stream<List<Note>> watchNotes(String doctorId, String patientId) {
    return _doctorCol(doctorId, 'patients')
        .doc(patientId)
        .collection('notes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Note.fromDoc).toList());
  }

  Stream<List<PatientMedia>> watchPatientMedia(String doctorId, String patientId) {
    return _doctorCol(doctorId, 'patients')
        .doc(patientId)
        .collection('media')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(PatientMedia.fromDoc).toList());
  }

  Stream<List<PatientFormEntry>> watchPatientForms(String doctorId, String patientId) {
    return _doctorCol(doctorId, 'patients')
        .doc(patientId)
        .collection('forms')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(PatientFormEntry.fromDoc).toList());
  }

  Stream<List<ClinicFormTemplate>> watchFormTemplates(String doctorId) {
    return _doctorCol(doctorId, 'formTemplates')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ClinicFormTemplate.fromDoc).toList());
  }

  Stream<List<AccountFilledForm>> watchAccountFilledForms(String doctorId) {
    return watchPatients(doctorId).asyncExpand((patients) {
      if (patients.isEmpty) return Stream.value(const <AccountFilledForm>[]);
      return _combinePatientForms(doctorId, patients);
    });
  }

  Stream<List<AccountFilledForm>> _combinePatientForms(String doctorId, List<Patient> patients) {
    final controller = StreamController<List<AccountFilledForm>>();
    final latest = <String, List<AccountFilledForm>>{};
    final ready = <String>{};
    final subscriptions = <StreamSubscription<List<PatientFormEntry>>>[];

    void emit() {
      if (ready.length < patients.length || controller.isClosed) return;
      final items = latest.values.expand((forms) => forms).toList()
        ..sort((a, b) => b.entry.createdAt.compareTo(a.entry.createdAt));
      controller.add(items);
    }

    for (final patient in patients) {
      subscriptions.add(
        watchPatientForms(doctorId, patient.id).listen(
          (entries) {
            ready.add(patient.id);
            latest[patient.id] = [
              for (final entry in entries) AccountFilledForm(patient: patient, entry: entry),
            ];
            emit();
          },
          onError: controller.addError,
        ),
      );
    }

    controller.onCancel = () {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    };
    return controller.stream;
  }
}

class AccountFilledForm {
  const AccountFilledForm({required this.patient, required this.entry});

  final Patient patient;
  final PatientFormEntry entry;
}
