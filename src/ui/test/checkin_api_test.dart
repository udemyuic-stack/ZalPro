import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/models/scan_result.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/api_error.dart';
import 'package:kotta_qani_diet/services/api/checkin_api.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';
import 'package:kotta_qani_diet/services/db.dart';
import 'package:kotta_qani_diet/theme.dart';
import 'package:kotta_qani_diet/widgets/checkin_qr_sheet.dart';
import 'package:kotta_qani_diet/widgets/scan_sheet.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'support/fake_api.dart';

Map<String, dynamic> scanJson({
  String subscription = 'active',
  bool already = false,
  int? daysLeft = 12,
}) =>
    {
      'user_id': 'u1',
      'name': 'Ali',
      'day': '2026-10-17',
      'already_present': already,
      'subscription_expires_at': subscription == 'none' ? null : '2026-10-29T00:00:00Z',
      'days_left': daysLeft,
      'subscription': subscription,
    };

ScanResult parsed(Map<String, dynamic> json) => ScanResult.fromJson(json);

void main() {
  late FakeAdapter adapter;
  late CheckinApi api;
  late List<String> touched;
  Future<ResponseBody> Function(RequestOptions) respond = (o) async => jsonBody({}, 200);

  setUp(() {
    respond = (o) async => jsonBody({}, 200);
    adapter = FakeAdapter((o) => respond(o));
    final client = ApiClient(store: MemorySessionStore(), baseUrl: 'http://x', adapter: adapter);
    final bus = ChangeBus();
    touched = [];
    bus.changes.listen(touched.add);
    api = CheckinApi(client, bus: bus, activity: PollActivity());
  });

  group('api', () {
    test('checkinToken: GET and returns the token string', () async {
      respond = (o) async => jsonBody({'token': 'abc.def.ghi', 'expires_in': 60}, 200);
      expect(await api.checkinToken(), 'abc.def.ghi');
      expect(adapter.calls.last.method, 'GET');
      expect(adapter.calls.last.path, '/v1/users/me/checkin-token');
    });

    test('scanCheckin: POST token, parses active and touches attendance keys', () async {
      respond = (o) async => jsonBody(scanJson(), 200);
      final r = await api.scanCheckin('tok');
      expect(adapter.calls.last.method, 'POST');
      expect(adapter.calls.last.path, '/v1/attendance/scan');
      expect(adapter.calls.last.data, {'token': 'tok'});
      expect(r.userId, 'u1');
      expect(r.name, 'Ali');
      expect(r.day, '2026-10-17');
      expect(r.alreadyPresent, false);
      expect(r.subscription, 'active');
      expect(r.daysLeft, 12);
      expect(r.subscriptionExpiresAt, isNotNull);
      expect(touched, contains('attendance:u1:2026-10-17'));
    });

    test('scanCheckin: parses expired', () async {
      respond = (o) async => jsonBody(scanJson(subscription: 'expired', daysLeft: null), 200);
      final r = await api.scanCheckin('tok');
      expect(r.subscription, 'expired');
      expect(r.daysLeft, isNull);
    });

    test('scanCheckin: parses none without expiry', () async {
      respond = (o) async => jsonBody(scanJson(subscription: 'none', daysLeft: null), 200);
      final r = await api.scanCheckin('tok');
      expect(r.subscription, 'none');
      expect(r.subscriptionExpiresAt, isNull);
    });

    test('scanCheckin: failure touches nothing and keeps the error code', () async {
      respond = (o) async => jsonBody({
            'detail': {'code': 'token_expired', 'message': 'expired'}
          }, 401);
      await expectLater(
        api.scanCheckin('tok'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'token_expired')),
      );
      expect(touched, isEmpty);
    });
  });

  group('error mapping', () {
    ApiException failure(String code, int status) =>
        ApiException(code: code, message: 'server text', status: status);

    test('checkin_not_member', () {
      expect(apiErrorText(failure('checkin_not_member', 422)), "Bu foydalanuvchi mijoz emas");
    });

    test('token_expired', () {
      expect(apiErrorText(failure('token_expired', 401)), 'QR kod eskirgan, mijoz yangilasin');
    });

    test('invalid_token', () {
      expect(apiErrorText(failure('invalid_token', 401)), "QR kod noto'g'ri");
    });

    test('network', () {
      expect(
        apiErrorText(const ApiException(code: ApiException.networkCode, message: '')),
        'Internet aloqasini tekshiring',
      );
    });
  });

  group('scanOutcome', () {
    test('active, first scan', () {
      final o = scanOutcome(parsed(scanJson()));
      expect(o.status, ScanStatus.arrived);
      expect(o.message, 'Keldi: Ali, 12 kun qoldi');
      expect(o.color(), AppColors.success);
      expect(o.note, isNull);
    });

    test('active, last day', () {
      final o = scanOutcome(parsed(scanJson(daysLeft: 0)));
      expect(o.message, 'Keldi: Ali, bugun tugaydi');
    });

    test('already present', () {
      final o = scanOutcome(parsed(scanJson(already: true)));
      expect(o.status, ScanStatus.alreadyPresent);
      expect(o.message, 'Bugun allaqachon belgilangan: Ali');
      expect(o.color(), AppColors.warning);
    });

    test('expired is red and says attendance was marked', () {
      final o = scanOutcome(parsed(scanJson(subscription: 'expired', daysLeft: null)));
      expect(o.status, ScanStatus.expired);
      expect(o.message, 'Ali: obuna tugagan');
      expect(o.color(), AppColors.danger);
      expect(o.note, 'Davomat belgilandi');
    });

    test('none is red', () {
      final o = scanOutcome(parsed(scanJson(subscription: 'none', daysLeft: null)));
      expect(o.status, ScanStatus.none);
      expect(o.message, "Ali: obuna yo'q");
      expect(o.color(), AppColors.danger);
    });

    test('expired wins over already present', () {
      final o =
          scanOutcome(parsed(scanJson(subscription: 'expired', already: true, daysLeft: null)));
      expect(o.status, ScanStatus.expired);
    });
  });

  group('widgets', () {
    AppUser me() => AppUser(
          id: 'u1',
          name: 'Ali Valiyev',
          email: '',
          gender: 'male',
          metabolism: 'normal',
          role: 'user',
        );

    Widget host(Widget child) => ProviderScope(
          overrides: [meProvider.overrideWith((ref) => Stream.value(me()))],
          child: MaterialApp(theme: AppTheme.dark(), home: Scaffold(body: child)),
        );

    testWidgets('QR sheet shows only the token, refreshes every 50 s', (t) async {
      var calls = 0;
      await t.pumpWidget(host(CheckinQrBody(
        showSubscription: false,
        fetchToken: () async => 'token-${++calls}',
      )));
      await t.pump();
      await t.pump();
      expect(find.text('Ali Valiyev'), findsOneWidget);
      expect(find.byKey(const ValueKey('qr:token-1')), findsOneWidget);
      await t.pump(const Duration(seconds: 50));
      await t.pump();
      expect(calls, 2);
      expect(find.byKey(const ValueKey('qr:token-2')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('QR sheet shows an error with retry', (t) async {
      var calls = 0;
      await t.pumpWidget(host(CheckinQrBody(
        showSubscription: false,
        fetchToken: () async {
          calls++;
          if (calls == 1) {
            throw const ApiException(code: ApiException.networkCode, message: '');
          }
          return 'ok-token';
        },
      )));
      await t.pump();
      await t.pump();
      expect(find.text('Internet aloqasini tekshiring'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      await t.tap(find.text('Qayta urinish'));
      await t.pump();
      await t.pump();
      expect(find.byKey(const ValueKey('qr:ok-token')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('scanner: manual code shows result then resumes', (t) async {
      final tokens = <String>[];
      await t.pumpWidget(host(CheckinScanner(
        camera: false,
        scan: (token) async {
          tokens.add(token);
          return parsed(scanJson());
        },
      )));
      await t.enterText(find.byType(TextField), ' manual-token ');
      await t.tap(find.byIcon(Icons.check));
      await t.pump();
      await t.pump();
      expect(tokens, ['manual-token']);
      expect(find.text('Keldi: Ali, 12 kun qoldi'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
      await t.pump();
      expect(find.text('Keldi: Ali, 12 kun qoldi'), findsNothing);
    });

    testWidgets('scanner: error is mapped through apiErrorText', (t) async {
      await t.pumpWidget(host(CheckinScanner(
        camera: false,
        scan: (token) async =>
            throw const ApiException(code: 'token_expired', message: '', status: 401),
      )));
      await t.enterText(find.byType(TextField), 'x');
      await t.tap(find.byIcon(Icons.check));
      await t.pump();
      await t.pump();
      expect(find.text('QR kod eskirgan, mijoz yangilasin'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
    });
  });
}
