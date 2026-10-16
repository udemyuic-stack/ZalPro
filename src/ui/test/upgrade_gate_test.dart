import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/screens/upgrade_screen.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/api_error.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';
import 'package:kotta_qani_diet/services/api/upgrade_gate.dart';

import 'support/fake_api.dart';

const _upgradeDetail = {
  'detail': {
    'code': 'upgrade_required',
    'message': 'Ilova eskirgan',
    'download_url': 'https://example.test/app.apk',
  }
};

void main() {
  late MemorySessionStore store;

  setUp(() {
    store = MemorySessionStore();
    upgradeRequired.value = null;
  });

  test('version header is sent on authed and bare requests', () async {
    final adapter = FakeAdapter((o) async {
      if (o.path == '/v1/auth/login') {
        return jsonBody({'access_token': fakeJwt('u1'), 'refresh_token': 'r1'}, 200);
      }
      return jsonBody({'ok': true}, 200);
    });
    final client = ApiClient(store: store, baseUrl: 'http://x', adapter: adapter)
      ..setAppVersion('1.0.0+7');

    await client.login('p', 'q');
    await client.getJson('/v1/users/me');

    expect(adapter.calls.first.headers[appVersionHeader], '1.0.0+7');
    expect(adapter.calls.last.headers[appVersionHeader], '1.0.0+7');
  });

  test('no version header before setAppVersion', () async {
    final adapter = FakeAdapter((o) async => jsonBody({'ok': true}, 200));
    final client = ApiClient(store: store, baseUrl: 'http://x', adapter: adapter);

    await client.getJson('/v1/users/me');

    expect(adapter.calls.single.headers.containsKey(appVersionHeader), isFalse);
  });

  test('426 raises upgradeRequired with download url', () async {
    final adapter = FakeAdapter((o) async => jsonBody(_upgradeDetail, 426));
    final client = ApiClient(store: store, baseUrl: 'http://x', adapter: adapter);

    await expectLater(
      client.getJson('/v1/users/me'),
      throwsA(isA<ApiException>().having((e) => e.isUpgradeRequired, 'isUpgradeRequired', true)),
    );

    expect(upgradeRequired.value?.downloadUrl, 'https://example.test/app.apk');
  });

  test('426 on refresh keeps the stored session', () async {
    await store.writeRefreshToken('r1');
    final adapter = FakeAdapter((o) async => jsonBody(_upgradeDetail, 426));
    final client = ApiClient(store: store, baseUrl: 'http://x', adapter: adapter);

    await expectLater(client.restore(), completes);

    expect(await store.readRefreshToken(), 'r1');
    expect(upgradeRequired.value, isNotNull);
  });

  test('other errors do not trigger the gate', () async {
    final adapter = FakeAdapter((o) async => jsonBody({
          'detail': {'code': 'not_found'}
        }, 404));
    final client = ApiClient(store: store, baseUrl: 'http://x', adapter: adapter);

    await expectLater(client.getJson('/v1/users/me'), throwsA(isA<ApiException>()));

    expect(upgradeRequired.value, isNull);
  });

  testWidgets('UpgradeGate replaces the child while an upgrade is required', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: UpgradeGate(child: Text('home')),
    ));
    expect(find.text('home'), findsOneWidget);

    upgradeRequired.value = const UpgradeInfo(downloadUrl: 'https://example.test/app.apk');
    await tester.pumpAndSettle();

    expect(find.text('home'), findsNothing);
    expect(find.byType(UpgradeScreen), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('UpgradeScreen hides the button without a download url', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UpgradeScreen(downloadUrl: '')));
    await tester.pumpAndSettle();

    expect(find.byType(FilledButton), findsNothing);
  });
}
