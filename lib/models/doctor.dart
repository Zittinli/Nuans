import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/admin_config.dart';
import 'app_permission.dart';

class Doctor {
  const Doctor({
    required this.id,
    required this.fullName,
    required this.email,
    required this.createdAt,
    this.permissions = const {},
  });

  final String id;
  final String fullName;
  final String email;
  final DateTime createdAt;
  final Set<AppPermission> permissions;

  bool get isSuperAdmin => isSuperAdminEmail(email);

  bool get canAccessAdmin => isSuperAdmin || permissions.isNotEmpty;

  bool hasPermission(AppPermission permission) {
    return isSuperAdmin || permissions.contains(permission);
  }

  bool get canViewAllAccounts => hasPermission(AppPermission.viewAllAccounts);

  bool get canManagePermissions => hasPermission(AppPermission.managePermissions);

  bool get canManageDefaultForms => hasPermission(AppPermission.manageDefaultForms);

  factory Doctor.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Doctor(
      id: doc.id,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      createdAt: _readDate(data['createdAt']),
      permissions: AppPermission.parseList(data['permissions']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

DateTime _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}
