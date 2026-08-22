import 'package:flutter_test/flutter_test.dart';
import 'package:nuans/firebase_options.dart';

void main() {
  test('Firebase yapılandırması yer tutucu anahtarlarla başlar', () {
    expect(DefaultFirebaseOptions.isConfigured, isFalse);
  });
}
