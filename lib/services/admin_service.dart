import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/admin_config.dart';
import '../models/app_permission.dart';
import '../models/clinic_form.dart';
import '../models/doctor.dart';
import '../models/note.dart';
import '../models/patient.dart';

class AdminService {
  AdminService({FirebaseAuth? auth, FirebaseFirestore? firestore})
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

  CollectionReference<Map<String, dynamic>> get _doctors => _db.collection('doctors');

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
}
