# Nüans

Doktorlar için Firebase destekli hasta not uygulaması. Flutter ile Android APK olarak geliştirilmiştir.

Her doktor kendi hesabıyla giriş yapar; hastalar ve klinik notlar Firestore’da yalnızca o doktora ait koleksiyonlarda saklanır.

## Özellikler

- E-posta/şifre ile kayıt ve giriş
- Şifre sıfırlama
- Hasta listesi, arama, ekleme, düzenleme, silme
- Hasta bazlı klinik notlar (muayene, kontrol, laboratuvar, reçete)
- Bulut senkronizasyonu (Firebase Auth + Cloud Firestore)

## Firebase kurulumu

1. [Firebase Console](https://console.firebase.google.com) üzerinden proje oluşturun.
2. Authentication > Sign-in method içinde **E-posta/Şifre** yöntemini açın.
3. Firestore Database’i production modunda başlatın.
4. Project settings içinden Android uygulaması ekleyin. Paket adı: `com.nuans.nuans`
5. Yapılandırmayı aktarın:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

veya `lib/firebase_options.dart` içindeki `YOUR_...` alanlarını doldurun.

6. Güvenlik kurallarını yayınlayın:

```bash
firebase deploy --only firestore:rules
```

Kurallar her doktorun yalnızca `doctors/{kendiUid}` altındaki verilere erişmesine izin verir.

## Çalıştırma ve APK

```bash
flutter pub get
flutter run
flutter build apk --release
```

Çıktı: `build/app/outputs/flutter-apk/app-release.apk`
