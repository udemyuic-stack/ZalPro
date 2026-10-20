import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/screens/user/chat_screen.dart';
import 'package:kotta_qani_diet/services/voice_recorder.dart';
import 'package:kotta_qani_diet/theme.dart';

import 'chat_voice_test.dart';

Future<void> pumpComposer(
  WidgetTester t,
  FakeRecorder rec,
  List<VoiceClip> sent, {
  Size size = const Size(360, 800),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = TextEditingController();
  addTearDown(c.dispose);
  await t.pumpWidget(MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      bottomNavigationBar: ChatComposer(
        controller: c,
        onSend: () {},
        onAttach: () {},
        recorderBuilder: () => rec,
        onVoice: (clip) async => sent.add(clip),
      ),
    ),
  ));
}

Future<TestGesture> hold(WidgetTester t) async {
  final g = await t.startGesture(t.getCenter(find.byKey(const Key('composer-mic'))));
  await t.pump(const Duration(milliseconds: 700));
  return g;
}

void testAndroid(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets(name, (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await body(t);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  testAndroid('hold shows timer, release sends the clip', (t) async {
    final rec = FakeRecorder();
    final sent = <VoiceClip>[];
    await pumpComposer(t, rec, sent);
    final g = await hold(t);
    expect(find.byKey(const Key('voice-timer')), findsOneWidget);
    rec.time = const Duration(seconds: 3);
    await g.up();
    await t.pumpAndSettle();
    expect(sent.length, 1);
    expect(sent.first.durationMs, 3000);
    expect(find.byKey(const Key('voice-timer')), findsNothing);
    expect(rec.disposed, true);
  });

  testAndroid('release under a second is not sent', (t) async {
    final rec = FakeRecorder();
    final sent = <VoiceClip>[];
    await pumpComposer(t, rec, sent);
    final g = await hold(t);
    rec.time = const Duration(milliseconds: 400);
    await g.up();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pump(const Duration(milliseconds: 50));
    expect(sent, isEmpty);
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Yozuv juda qisqa'), findsOneWidget);
  });

  testAndroid('slide left cancels and sends nothing', (t) async {
    final rec = FakeRecorder();
    final sent = <VoiceClip>[];
    await pumpComposer(t, rec, sent);
    final g = await hold(t);
    rec.time = const Duration(seconds: 3);
    await g.moveBy(const Offset(-130, 0));
    await t.pumpAndSettle();
    await g.up();
    await t.pumpAndSettle();
    expect(sent, isEmpty);
    expect(rec.cancelled, true);
    expect(find.byKey(const Key('voice-timer')), findsNothing);
  });

  testAndroid('slide up locks, then send button sends', (t) async {
    final rec = FakeRecorder();
    final sent = <VoiceClip>[];
    await pumpComposer(t, rec, sent);
    final g = await hold(t);
    await g.moveBy(const Offset(0, -100));
    await t.pump();
    await g.up();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('voice-send')), findsOneWidget);
    expect(find.byKey(const Key('voice-discard')), findsOneWidget);
    expect(sent, isEmpty);
    rec.time = const Duration(seconds: 2);
    await t.tap(find.byKey(const Key('voice-send')));
    await t.pumpAndSettle();
    expect(sent.length, 1);
  });

  testAndroid('locked discard cancels', (t) async {
    final rec = FakeRecorder();
    final sent = <VoiceClip>[];
    await pumpComposer(t, rec, sent);
    final g = await hold(t);
    await g.moveBy(const Offset(0, -100));
    await g.up();
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('voice-discard')));
    await t.pumpAndSettle();
    expect(sent, isEmpty);
    expect(rec.cancelled, true);
  });

  testAndroid('denied permission shows guidance and records nothing', (t) async {
    final rec = FakeRecorder(allowed: false);
    final sent = <VoiceClip>[];
    await pumpComposer(t, rec, sent);
    final g = await hold(t);
    await g.up();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Mikrofon ruxsati'), findsOneWidget);
    expect(sent, isEmpty);
  });

  testAndroid('a plain tap only shows the hold hint', (t) async {
    final rec = FakeRecorder();
    final sent = <VoiceClip>[];
    await pumpComposer(t, rec, sent);
    await t.tap(find.byKey(const Key('composer-mic')));
    await t.pump();
    expect(find.text('Yozish uchun mikrofonni bosib turing'), findsOneWidget);
    expect(sent, isEmpty);
  });

  testAndroid('recording bar fits 320 px', (t) async {
    final rec = FakeRecorder();
    await pumpComposer(t, rec, [], size: const Size(320, 640));
    final g = await hold(t);
    expect(t.takeException(), isNull);
    await g.up();
    await t.pumpAndSettle();
  });
}
