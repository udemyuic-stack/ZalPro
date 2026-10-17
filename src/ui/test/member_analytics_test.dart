import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/member_analytics.dart';
import 'package:kotta_qani_diet/screens/admin/member_analytics_screen.dart';
import 'package:kotta_qani_diet/services/api/analytics_api.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';
import 'package:kotta_qani_diet/theme.dart';

import 'support/fake_api.dart';

ChurnReport churnSample() {
  final last = DateTime.now().subtract(const Duration(days: 12));
  final day = '${last.year.toString().padLeft(4, '0')}-${last.month.toString().padLeft(2, '0')}-'
      '${last.day.toString().padLeft(2, '0')}';
  return ChurnReport(items: [
    ChurnItem(
      userId: 'u1',
      name: 'Juda uzun ismli shogird Abdurahmonov Muhammadjon',
      phone: '998901234567',
      trainerId: 't1',
      trainerName: 'Trener Aziz',
      reasons: const ['silent', 'drop', 'expiring', 'expired'],
      score: 10,
      lastVisit: day,
      visitsLast14: 0,
      visitsPrev14: 6,
    ),
    const ChurnItem(userId: 'u2', name: 'Vali', phone: '998901111111', reasons: ['expired']),
  ]);
}

Retention retentionSample({double? rate = 0.5}) => Retention(cohorts: [
      RetentionCohort(
        day: 30,
        eligible: 20,
        retained: 10,
        rate: rate,
        withTrainer: const RetentionSplit(eligible: 10, retained: 8),
        withoutTrainer: const RetentionSplit(eligible: 10, retained: 2),
      ),
      const RetentionCohort(day: 60, eligible: 0, retained: 0),
      const RetentionCohort(day: 90, eligible: 5, retained: 1, rate: 0.2),
    ]);

TrainerStats trainersSample() => const TrainerStats(rows: [
      TrainerRow(
        trainerId: 't1',
        name: 'Trener Aziz',
        students: 8,
        activeStudents: 6,
        visitsPerStudentWeek: 2.5,
        feedbackCount: 10,
        hardCount: 3,
        hardShare: 0.3,
      ),
      TrainerRow(name: 'x', students: 4, activeStudents: 1, visitsPerStudentWeek: 0.5),
    ]);

Future<void> pump(
  WidgetTester tester, {
  bool isOwner = true,
  ChurnLoader? churn,
  RetentionLoader? retention,
  TrainerStatsLoader? trainers,
  double width = 360,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: MemberAnalyticsScreen(
      isOwner: isOwner,
      churnLoader: churn ?? () async => churnSample(),
      retentionLoader: retention ?? (f, t) async => retentionSample(),
      trainersLoader: trainers ?? (f, t) async => trainersSample(),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

Future<void> openSegment(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump();
}

void main() {
  test('models parse churn, retention and trainer payloads', () {
    final c = ChurnReport.fromJson({
      'as_of': '2026-10-17',
      'items': [
        {
          'user_id': 'u',
          'name': 'A',
          'phone': '998',
          'trainer_id': null,
          'trainer_name': '',
          'reasons': ['silent'],
          'score': 3,
          'last_visit': null,
          'visits_last14': 0,
          'visits_prev14': 2,
          'expires_at': null,
        },
      ],
    });
    expect(c.items.single.hasTrainer, isFalse);
    expect(c.items.single.lastVisit, isNull);
    expect(c.items.single.reasons, ['silent']);

    final r = Retention.fromJson({
      'from': 'a',
      'to': 'b',
      'cohorts': [
        {
          'day': 30,
          'eligible': 4,
          'retained': 2,
          'rate': 0.5,
          'with_trainer': {'eligible': 1, 'retained': 1},
          'without_trainer': {'eligible': 3, 'retained': 1},
        },
        {'day': 60, 'eligible': 0, 'retained': 0, 'rate': null},
      ],
    });
    expect(r.cohorts.first.withoutTrainer.eligible, 3);
    expect(r.cohorts.last.rate, isNull);
    expect(r.isEmpty, isFalse);

    final t = TrainerStats.fromJson({
      'rows': [
        {
          'trainer_id': null,
          'name': 'Trenersiz',
          'students': 3,
          'active_students': 1,
          'visits_per_student_week': 1,
          'feedback_count': 0,
          'hard_count': 0,
          'hard_share': null,
        },
      ],
    });
    expect(t.rows.single.trainerId, isNull);
    expect(t.rows.single.visitsPerStudentWeek, 1.0);
    expect(t.rows.single.hardShare, isNull);
  });

  test('AnalyticsApi calls churn, retention and trainers endpoints', () async {
    final adapter =
        FakeAdapter((o) async => jsonBody({'items': [], 'cohorts': [], 'rows': []}, 200));
    final client = ApiClient(store: MemorySessionStore(), baseUrl: 'http://x', adapter: adapter);
    final api = AnalyticsApi(client, bus: ChangeBus(), activity: PollActivity());
    await api.churn();
    expect(adapter.calls.last.path, '/v1/analytics/churn');
    await api.retention(DateTime(2026, 4, 1), DateTime(2026, 10, 17));
    expect(adapter.calls.last.path, '/v1/analytics/retention');
    expect(adapter.calls.last.queryParameters, {'from': '2026-04-01', 'to': '2026-10-17'});
    await api.trainers(DateTime(2026, 9, 18), DateTime(2026, 10, 17));
    expect(adapter.calls.last.path, '/v1/analytics/trainers');
    expect(adapter.calls.last.queryParameters, {'from': '2026-09-18', 'to': '2026-10-17'});
  });

  testWidgets('owner sees three segments and the churn cards', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('segments')), findsOneWidget);
    expect(find.text('Xavf'), findsOneWidget);
    expect(find.text('Qolish'), findsOneWidget);
    expect(find.text('Trenerlar'), findsOneWidget);
    expect(find.text("Kelmay qo'ydi"), findsOneWidget);
    expect(find.text('Kelishi kamaydi'), findsOneWidget);
    expect(find.text('Abonement tugayapti'), findsOneWidget);
    expect(find.text('Abonement tugagan'), findsNWidgets(2));
    expect(find.text('Oxirgi kelgan: 12 kun oldin'), findsOneWidget);
    expect(find.text('Hali kelmagan'), findsOneWidget);
    expect(find.text('Trenersiz'), findsOneWidget);
    expect(find.text('Trener Aziz'), findsOneWidget);
    expect(find.byKey(const Key('call-u1')), findsOneWidget);
    expect(find.byKey(const Key('call-u2')), findsOneWidget);
    final size = tester.getSize(find.byKey(const Key('call-u1')));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('churn shows total and reason filters whose counts match the list', (tester) async {
    await pump(tester);
    expect(find.text('Jami: 2'), findsOneWidget);
    expect(find.text('Hammasi (2)'), findsOneWidget);
    expect(find.text("Kelmay qo'ydi (1)"), findsOneWidget);
    expect(find.text('Kelishi kamaydi (1)'), findsOneWidget);
    expect(find.text('Abonement tugayapti (1)'), findsOneWidget);
    expect(find.text('Abonement tugagan (2)'), findsOneWidget);
    expect(find.byKey(const Key('churn-u1')), findsOneWidget);
    expect(find.byKey(const Key('churn-u2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('filter-silent')));
    await tester.pump();
    expect(find.byKey(const Key('churn-u1')), findsOneWidget);
    expect(find.byKey(const Key('churn-u2')), findsNothing);

    await tester.tap(find.byKey(const Key('filter-expired')));
    await tester.pump();
    expect(find.byKey(const Key('churn-u1')), findsOneWidget);
    expect(find.byKey(const Key('churn-u2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('filter-all')));
    await tester.pump();
    expect(find.byKey(const Key('churn-u2')), findsOneWidget);
    expect(find.text('Jami: 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected segment uses the accent color', (tester) async {
    await pump(tester);
    final button = tester.widget<SegmentedButton<int>>(find.byKey(const Key('segments')));
    expect(button.style?.backgroundColor?.resolve({WidgetState.selected}), AppColors.accentFill);
  });

  testWidgets('admin sees only the churn section without segments', (tester) async {
    await pump(tester, isOwner: false);
    expect(find.byKey(const Key('segments')), findsNothing);
    expect(find.byKey(const Key('churn')), findsOneWidget);
    expect(find.text('Qolish'), findsNothing);
  });

  testWidgets('retention shows rows, dash for null rate and trainer split', (tester) async {
    await pump(tester, retention: (f, t) async => retentionSample(rate: null));
    await openSegment(tester, 'Qolish');
    expect(find.byKey(const Key('cohort-30')), findsOneWidget);
    expect(find.byKey(const Key('cohort-60')), findsOneWidget);
    expect(find.byKey(const Key('cohort-90')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('rate-30'))).data, '—');
    expect(find.text('20%'), findsOneWidget);
    expect(find.text('20 dan 10 qoldi'), findsOneWidget);
    expect(find.text('Trenerli: 80% · Trenersiz: 20%'), findsOneWidget);
    expect(find.text('Trenerli: — · Trenersiz: —'), findsNWidgets(2));
    for (final day in [30, 60, 90]) {
      expect(
        find.text(
            "Qoldi = a'zo bo'lgandan $day kun keyin keyingi 14 kun ichida kamida 1 marta kelgan"),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('retention period chips reload with the chosen window', (tester) async {
    final spans = <int>[];
    await pump(tester, retention: (f, t) async {
      spans.add(t.difference(f).inDays);
      return retentionSample();
    });
    await openSegment(tester, 'Qolish');
    expect(spans.last, 180);
    await tester.tap(find.byKey(const Key('period-365')));
    await tester.pump();
    await tester.pump();
    expect(spans.last, 365);
  });

  testWidgets('trainers show cards, Trenersiz for null and dash for null share', (tester) async {
    await pump(tester);
    await openSegment(tester, 'Trenerlar');
    expect(find.byKey(const Key('trainer-t1')), findsOneWidget);
    expect(find.text('30%'), findsOneWidget);
    expect(find.text('2.5'), findsOneWidget);
    expect(find.text('Trenersiz'), findsOneWidget);
    expect(find.text('x'), findsNothing);
    expect(find.text('—'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trainers sort toggle, bars and low-data badge', (tester) async {
    const stats = TrainerStats(rows: [
      TrainerRow(
        trainerId: 't1',
        name: 'Aziz',
        students: 8,
        visitsPerStudentWeek: 2.5,
        feedbackCount: 10,
        hardShare: 0.3,
      ),
      TrainerRow(
        trainerId: 't2',
        name: 'Bobur',
        students: 5,
        visitsPerStudentWeek: 1.0,
        feedbackCount: 4,
        hardShare: 0.6,
      ),
    ]);
    await pump(tester, trainers: (f, t) async => stats);
    await openSegment(tester, 'Trenerlar');
    double y(String id) => tester.getTopLeft(find.byKey(Key('trainer-$id'))).dy;
    expect(y('t2'), lessThan(y('t1')));
    expect(find.byKey(const Key('lowdata-t2')), findsOneWidget);
    expect(find.byKey(const Key('lowdata-t1')), findsNothing);
    expect(find.text("kam ma'lumot"), findsOneWidget);
    expect(find.byKey(const Key('hard-bar-t1')), findsOneWidget);
    expect(find.byKey(const Key('visits-bar-t1')), findsOneWidget);
    await tester.tap(find.text("Kelish bo'yicha"));
    await tester.pump();
    expect(y('t1'), lessThan(y('t2')));
    await tester.tap(find.text('"Qiyin" bo\'yicha'));
    await tester.pump();
    expect(y('t2'), lessThan(y('t1')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('trainer with feedback_count below 5 is flagged in the default sample',
      (tester) async {
    await pump(tester);
    await openSegment(tester, 'Trenerlar');
    expect(find.byKey(const Key('lowdata-none')), findsOneWidget);
    expect(find.byKey(const Key('lowdata-t1')), findsNothing);
  });

  testWidgets('each section has an empty state', (tester) async {
    await pump(
      tester,
      churn: () async => const ChurnReport(),
      retention: (f, t) async => const Retention(),
      trainers: (f, t) async => const TrainerStats(),
    );
    expect(find.text("Ketish xavfi ostida shogird yo'q"), findsOneWidget);
    await openSegment(tester, 'Qolish');
    expect(find.text("Bu davrda yangi a'zo yo'q"), findsOneWidget);
    await openSegment(tester, 'Trenerlar');
    expect(find.text("Trener ma'lumoti yo'q"), findsOneWidget);
  });

  testWidgets('error state offers retry', (tester) async {
    var n = 0;
    await pump(tester, churn: () async {
      n++;
      if (n == 1) throw Exception('boom');
      return churnSample();
    });
    expect(find.text('Qayta urinish'), findsOneWidget);
    await tester.tap(find.text('Qayta urinish'));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('call-u1')), findsOneWidget);
  });
}
