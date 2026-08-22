// Firebase yapılandırması.
//
// 1. https://console.firebase.google.com adresinden bir proje oluşturun.
// 2. Authentication > Sign-in method > E-posta/Şifre'yi açın.
// 3. Firestore Database'i production modunda başlatın.
// 4. Project settings > Your apps > Android uygulaması ekleyin
//    Paket adı: com.nuans.nuans
// 5. Aşağıdaki değerleri Firebase konsolundaki Android uygulamasından doldurun
//    veya şu komutu çalıştırın:
//    dart pub global activate flutterfire_cli
//    flutterfire configure
// 6. firestore.rules dosyasını yayınlayın:
//    firebase deploy --only firestore:rules

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static bool get isConfigured =>
      android.apiKey != 'YOUR_ANDROID_API_KEY' &&
      android.appId != 'YOUR_ANDROID_APP_ID' &&
      android.projectId != 'YOUR_PROJECT_ID';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Nüans şu an yalnızca Android APK için yapılandırıldı.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Bu platform henüz yapılandırılmadı.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDedVA3hopTAoT8C64ipiEyO4VxUqYx9L0',
    appId: '1:42059537638:android:b572a26ae7cbb985a0ef27',
    messagingSenderId: '42059537638',
    projectId: 'nuans-4364d',
    storageBucket: 'nuans-4364d.firebasestorage.app',
  );
}
