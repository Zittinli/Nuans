const kSuperAdminEmail = 'zttnlnkc@gmail.com';

bool isSuperAdminEmail(String? email) {
  return (email ?? '').trim().toLowerCase() == kSuperAdminEmail;
}
