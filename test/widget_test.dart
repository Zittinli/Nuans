import 'package:flutter_test/flutter_test.dart';
import 'package:nuans/firebase_options.dart';
import 'package:nuans/utils/disposable_email.dart';

void main() {
  test('Firebase yapılandırması doldurulmuş olmalı', () {
    expect(DefaultFirebaseOptions.isConfigured, isTrue);
  });

  test('tek kullanımlık e-posta adreslerini reddeder', () {
    expect(isDisposableEmail('doktor@yopmail.com'), isTrue);
    expect(isDisposableEmail('ali@mailinator.com'), isTrue);
    expect(isDisposableEmail('hekim@gmail.com'), isFalse);
  });
}
