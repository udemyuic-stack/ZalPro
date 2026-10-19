import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/screens/user/chat_screen.dart';
import 'package:kotta_qani_diet/theme.dart';

ChatMessage message(String text, {Map<String, dynamic>? extra}) => ChatMessage.fromJson({
      'sender_id': 't1',
      'text': text,
      'created_at': '2026-10-17T09:30:00Z',
      ...?extra,
    });

Future<void> pump(WidgetTester tester, ChatMessage m, {bool mine = false}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(child: ChatBubble(message: m, mine: mine, tight: false)),
      ),
    ),
  ));
}

void main() {
  test('kind defaults to user and is read from json', () {
    expect(message('salom').kind, 'user');
    expect(message('salom', extra: {'kind': 'user'}).kind, 'user');
    expect(message('salom', extra: {'kind': 'system'}).kind, 'system');
    expect(message('salom', extra: {'kind': 'system'}).isSystem, isTrue);
    expect(message('salom').isSystem, isFalse);
  });

  testWidgets('system message renders as a note card with label and icon', (tester) async {
    await pump(tester, message('Abonement tugayapti', extra: {'kind': 'system'}));
    expect(find.byKey(const Key('system-note')), findsOneWidget);
    expect(find.text('Tizim xabari'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_outlined), findsOneWidget);
    expect(find.text('Abonement tugayapti'), findsOneWidget);
    expect(find.text(DateFormat('HH:mm').format(message('x').createdAt)), findsOneWidget);
  });

  testWidgets('user message and legacy message without kind stay plain bubbles', (tester) async {
    await pump(tester, message('salom'));
    expect(find.byKey(const Key('system-note')), findsNothing);
    expect(find.text('Tizim xabari'), findsNothing);
    expect(find.text('salom'), findsOneWidget);
    await pump(tester, message('salom', extra: {'kind': 'user'}), mine: true);
    expect(find.byKey(const Key('system-note')), findsNothing);
  });

  testWidgets('system note is centered, wraps 300 chars and stays within 90 percent',
      (tester) async {
    final long = List.filled(60, 'Eslatma').join(' ').substring(0, 300);
    await pump(tester, message(long, extra: {'kind': 'system'}));
    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byKey(const Key('system-note')));
    expect(size.width, lessThanOrEqualTo(336 * 0.9 + 0.01));
    final center = tester.getCenter(find.byKey(const Key('system-note'))).dx;
    expect(center, closeTo(180, 0.5));
    await tester.pumpWidget(const SizedBox());
    await pump(tester, message(long, extra: {'kind': 'system'}), mine: true);
    expect(tester.getCenter(find.byKey(const Key('system-note'))).dx, closeTo(180, 0.5));
    expect(tester.takeException(), isNull);
  });
}
