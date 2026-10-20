import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => throw PlatformException(code: 'keystore', message: 'broken'),
    );
  });

  test('read failure means no session', () async {
    final store = SecureSessionStore(const FlutterSecureStorage());
    expect(await store.readRefreshToken(), isNull);
  });

  test('write and clear failures do not throw', () async {
    final store = SecureSessionStore(const FlutterSecureStorage());
    await store.writeRefreshToken('t');
    await store.clear();
  });
}
