enum AppPermission {
  viewAllAccounts(
    'viewAllAccounts',
    'Hesapları incele',
    'Kayıtlı hesapların hastalarını, notlarını ve ekledikleri formları görüntüler.',
  ),
  managePermissions(
    'managePermissions',
    'Yetki ver / al',
    'Diğer kullanıcılara yetki tanımlar veya kaldırır. Tam yetkili hesabın yetkisi alınamaz.',
  ),
  manageDefaultForms(
    'manageDefaultForms',
    'Varsayılan formlar',
    'Tüm hesaplarda görünen varsayılan formları ekler veya kaldırır.',
  );

  const AppPermission(this.id, this.label, this.description);

  final String id;
  final String label;
  final String description;

  static AppPermission? fromId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final item in AppPermission.values) {
      if (item.id == id) return item;
    }
    return null;
  }

  static Set<AppPermission> parseList(dynamic raw) {
    if (raw is! List) return <AppPermission>{};
    return raw.map((item) => fromId('$item')).whereType<AppPermission>().toSet();
  }
}
