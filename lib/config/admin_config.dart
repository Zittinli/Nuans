import 'package:firebase_auth/firebase_auth.dart';

import '../models/doctor.dart';

const kSuperAdminEmail = 'zttnlnkc@gmail.com';

String normalizeEmail(String? email) {
  var value = (email ?? '').trim().toLowerCase();
  if (value.isEmpty) return '';
  value = value.replaceFirst('@googlemail.com', '@gmail.com');
  final at = value.lastIndexOf('@');
  if (at <= 0) return value;
  var local = value.substring(0, at);
  final domain = value.substring(at + 1);
  if (domain == 'gmail.com') {
    final plus = local.indexOf('+');
    if (plus >= 0) local = local.substring(0, plus);
    local = local.replaceAll('.', '');
  }
  return '$local@$domain';
}

bool isSuperAdminEmail(String? email) {
  return normalizeEmail(email) == normalizeEmail(kSuperAdminEmail);
}

Iterable<String> signedInEmails(User? user) {
  if (user == null) return const [];
  return {
    if (user.email != null) user.email!,
    ...user.providerData.map((item) => item.email).whereType<String>(),
  };
}

bool isSuperAdminUser(User? user) {
  return signedInEmails(user).any(isSuperAdminEmail);
}

bool hasAdminAccess({User? user, Doctor? doctor}) {
  if (isSuperAdminUser(user) || isSuperAdminEmail(doctor?.email)) return true;
  return doctor?.permissions.isNotEmpty ?? false;
}

Doctor superAdminActor({User? user, Doctor? profile}) {
  return Doctor(
    id: profile?.id ?? user?.uid ?? '',
    fullName: (profile?.fullName.isNotEmpty == true)
        ? profile!.fullName
        : (user?.displayName ?? 'Yönetici'),
    email: kSuperAdminEmail,
    createdAt: profile?.createdAt ?? DateTime.now(),
    permissions: profile?.permissions ?? const {},
  );
}
