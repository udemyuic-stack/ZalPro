import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/announcement.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/widgets/announcement_banner.dart';
import 'package:kotta_qani_diet/widgets/announcement_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

final now = DateTime(2026, 5, 7, 12);

Announcement ann(
  String id, {
  String author = 'a',
  DateTime? expires,
  AnnouncementAudience audience = AnnouncementAudience.students,
}) =>
    Announcement(
      id: id,
      title: 'T$id',
      body: 'Body $id',
      audience: audience,
      authorId: author,
      authorName: 'Name',
      expiresAt: expires,
    );

AppUser user(String role, {String id = 'a'}) =>
    AppUser.fromJson({'id': id, 'name': 'X', 'role': role, 'phone': '998900000001'});

Widget host(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('fromJson maps audience and expiry', () {
    final a = Announcement.fromJson({
      'id': '1',
      'title': 't',
      'body': 'b',
      'audience': 'all',
      'author_id': 'x',
      'author_name': 'n',
      'created_at': '2026-05-07T10:00:00Z',
      'expires_at': null,
    });
    expect(a.audience, AnnouncementAudience.all);
    expect(a.expiresAt, isNull);
    expect(a.isActive(now), isTrue);
  });

  test('expired announcements are filtered out', () {
    final list = [ann('1', expires: now.subtract(const Duration(minutes: 1))), ann('2')];
    expect(activeAnnouncements(list, now).map((a) => a.id), ['2']);
  });

  test('announcementFull counts only own active', () {
    final own = [for (var i = 0; i < 20; i++) ann('$i')];
    expect(announcementFull(own, 'a', now), isTrue);
    expect(announcementFull(own, 'b', now), isFalse);
    final expired = [
      for (var i = 0; i < 20; i++) ann('$i', expires: now.subtract(const Duration(days: 1)))
    ];
    expect(announcementFull(expired, 'a', now), isFalse);
  });

  testWidgets('banner shows newest and dismissal hides only that one', (tester) async {
    await tester.pumpWidget(host(AnnouncementBanner(
      userId: 'u1',
      clock: () => now,
      source: Stream.value([ann('1'), ann('2')]),
    )));
    await tester.pump();
    await tester.pump();
    expect(find.text('T1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('announcement-dismiss')));
    await tester.pump();
    expect(find.text('T1'), findsNothing);
    expect(find.text('T2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('announcement-dismiss')));
    await tester.pump();
    expect(find.byKey(const Key('announcement-banner')), findsNothing);
  });

  testWidgets('dismissal survives rebuild via shared_preferences', (tester) async {
    SharedPreferences.setMockInitialValues({
      'announcement_dismissed_u1': ['1'],
    });
    await tester.pumpWidget(host(AnnouncementBanner(
      userId: 'u1',
      clock: () => now,
      source: Stream.value([ann('1'), ann('2')]),
    )));
    await tester.pump();
    await tester.pump();
    expect(find.text('T1'), findsNothing);
    expect(find.text('T2'), findsOneWidget);
  });

  testWidgets('banner hides expired and empty', (tester) async {
    await tester.pumpWidget(host(AnnouncementBanner(
      userId: 'u1',
      clock: () => now,
      source: Stream.value([ann('1', expires: now.subtract(const Duration(hours: 1)))]),
    )));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('announcement-banner')), findsNothing);
  });

  testWidgets('banner stays silent on stream error', (tester) async {
    await tester.pumpWidget(host(AnnouncementBanner(
      userId: 'u1',
      clock: () => now,
      source: Stream<List<Announcement>>.error(Exception('x')),
    )));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('announcement-banner')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trainer sees no audience selector, owner does', (tester) async {
    await tester.pumpWidget(host(AnnouncementManager(
      me: user('admin'),
      source: Stream.value(const []),
    )));
    await tester.pump();
    expect(find.byKey(const Key('announcement-audience-all')), findsNothing);
    expect(find.text('Butun zal'), findsNothing);

    await tester.pumpWidget(host(AnnouncementManager(
      me: user('owner'),
      source: Stream.value(const []),
    )));
    await tester.pump();
    expect(find.byKey(const Key('announcement-audience-all')), findsOneWidget);
  });

  testWidgets('add disabled with hint at 20 active own announcements', (tester) async {
    final items = [for (var i = 0; i < 20; i++) ann('$i')];
    await tester.pumpWidget(host(AnnouncementManager(
      me: user('admin'),
      source: Stream.value(items),
    )));
    await tester.pump();
    tester.view.physicalSize = const Size(800, 12000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(AnnouncementManager(
      me: user('admin'),
      source: Stream.value(items),
    )));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('announcement-title')), 'a');
    await tester.enterText(find.byKey(const Key('announcement-body')), 'b');
    await tester.pump();
    expect(find.byKey(const Key('announcement-full-hint')), findsOneWidget);
    expect(
        tester.widget<FilledButton>(find.byKey(const Key('announcement-add'))).onPressed, isNull);
  });

  testWidgets('trainer manages only own announcements, owner all', (tester) async {
    final items = [ann('1', author: 'a'), ann('2', author: 'z')];
    await tester.pumpWidget(host(AnnouncementManager(
      me: user('admin'),
      source: Stream.value(items),
    )));
    await tester.pump();
    expect(find.byKey(const Key('announcement-delete-1')), findsOneWidget);
    expect(find.byKey(const Key('announcement-delete-2')), findsNothing);

    await tester.pumpWidget(host(AnnouncementManager(
      me: user('owner'),
      source: Stream.value(items),
    )));
    await tester.pump();
    expect(find.byKey(const Key('announcement-delete-2')), findsOneWidget);
  });
}
