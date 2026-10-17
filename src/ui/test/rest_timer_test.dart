import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotta_qani_diet/widgets/rest_timer.dart';

class _FakeTicker {
  final List<StreamController<void>> made = [];
  DateTime now = DateTime(2026, 1, 1, 12);

  Stream<void> call() {
    final c = StreamController<void>();
    made.add(c);
    return c.stream;
  }

  DateTime clock() => now;

  StreamController<void> get last => made.last;

  void tick([int n = 1]) {
    for (var i = 0; i < n; i++) {
      now = now.add(const Duration(seconds: 1));
      last.add(null);
    }
  }
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

RestTimerController _make(
  _FakeTicker t, {
  VoidCallback? onFinished,
  void Function(DateTime)? onStarted,
  VoidCallback? onStopped,
}) =>
    RestTimerController(
      ticker: t.call,
      clock: t.clock,
      onFinished: onFinished,
      onStarted: onStarted,
      onStopped: onStopped,
    );

void main() {
  group('RestTimerController', () {
    test('counts down and finishes once at zero', () async {
      final ticker = _FakeTicker();
      var finished = 0;
      final c = _make(ticker, onFinished: () => finished++);
      expect(c.running, isFalse);
      c.start(const Duration(seconds: 3));
      expect(c.running, isTrue);
      expect(c.remaining, const Duration(seconds: 3));
      ticker.tick();
      await _settle();
      expect(c.remaining, const Duration(seconds: 2));
      ticker.tick(2);
      await _settle();
      expect(c.remaining, Duration.zero);
      expect(c.running, isFalse);
      expect(finished, 1);
      ticker.tick(2);
      await _settle();
      expect(finished, 1);
      expect(c.remaining, Duration.zero);
      c.dispose();
    });

    test('remaining follows the wall clock after a long gap without ticks', () {
      final ticker = _FakeTicker();
      final c = _make(ticker);
      c.start(const Duration(seconds: 90));
      ticker.now = ticker.now.add(const Duration(seconds: 40));
      c.refresh();
      expect(c.remaining, const Duration(seconds: 50));
      expect(c.running, isTrue);
      c.dispose();
    });

    test('refresh after the end finishes exactly once', () {
      final ticker = _FakeTicker();
      var finished = 0;
      final c = _make(ticker, onFinished: () => finished++);
      c.start(const Duration(seconds: 60));
      ticker.now = ticker.now.add(const Duration(minutes: 5));
      c.refresh();
      c.refresh();
      expect(c.running, isFalse);
      expect(c.remaining, Duration.zero);
      expect(finished, 1);
      c.dispose();
    });

    test('schedules on start and cancels on skip, finish, restart and dispose', () async {
      final ticker = _FakeTicker();
      final started = <DateTime>[];
      var stopped = 0;
      final c = _make(ticker, onStarted: started.add, onStopped: () => stopped++);
      final t0 = ticker.now;
      c.start(const Duration(seconds: 60));
      expect(started, [t0.add(const Duration(seconds: 60))]);
      expect(stopped, 0);
      c.skip();
      expect(stopped, 1);
      c.skip();
      expect(stopped, 1);

      c.start(const Duration(seconds: 2));
      ticker.tick(2);
      await _settle();
      expect(stopped, 2);

      c.start(const Duration(seconds: 30));
      c.start(const Duration(seconds: 45));
      expect(started.length, 4);
      c.dispose();
      expect(stopped, 3);
    });

    test('skip stops without calling onFinished', () async {
      final ticker = _FakeTicker();
      var finished = 0;
      final c = _make(ticker, onFinished: () => finished++);
      c.start(const Duration(seconds: 5));
      ticker.tick();
      await _settle();
      c.skip();
      expect(c.running, isFalse);
      expect(c.remaining, Duration.zero);
      ticker.tick(5);
      await _settle();
      expect(finished, 0);
      c.dispose();
    });

    test('restart resets remaining and ignores the old ticker', () async {
      final ticker = _FakeTicker();
      final c = _make(ticker);
      c.start(const Duration(seconds: 10));
      final first = ticker.last;
      ticker.tick(2);
      await _settle();
      expect(c.remaining, const Duration(seconds: 8));
      c.start(const Duration(seconds: 60));
      expect(c.remaining, const Duration(seconds: 60));
      expect(c.total, const Duration(seconds: 60));
      expect(first.hasListener, isFalse);
      ticker.tick();
      await _settle();
      expect(c.remaining, const Duration(seconds: 59));
      c.dispose();
    });

    test('dispose cancels the ticker', () {
      final ticker = _FakeTicker();
      final c = _make(ticker);
      c.start(const Duration(seconds: 5));
      c.dispose();
      expect(ticker.last.hasListener, isFalse);
    });

    test('formatRest renders mm:ss', () {
      expect(formatRest(const Duration(seconds: 90)), '01:30');
      expect(formatRest(const Duration(seconds: 5)), '00:05');
      expect(formatRest(Duration.zero), '00:00');
    });
  });

  group('RestTimerPrefs', () {
    test('defaults to 90 and ignores unsupported values', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await RestTimerPrefs.load(), 90);
      SharedPreferences.setMockInitialValues({restTimerKey: 45});
      expect(await RestTimerPrefs.load(), 90);
      SharedPreferences.setMockInitialValues({restTimerKey: 120});
      expect(await RestTimerPrefs.load(), 120);
    });

    test('stores duration per exercise and falls back to the last global choice', () async {
      SharedPreferences.setMockInitialValues({});
      await RestTimerPrefs.save(120, 'squat');
      await RestTimerPrefs.save(60, 'curl');
      expect(await RestTimerPrefs.load('squat'), 120);
      expect(await RestTimerPrefs.load('curl'), 60);
      expect(await RestTimerPrefs.load('bench'), 60);
      SharedPreferences.setMockInitialValues({});
      expect(await RestTimerPrefs.load('bench'), 90);
    });
  });

  group('RestTimerBar', () {
    testWidgets('shows chips and persists the chosen duration', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final ticker = _FakeTicker();
      final c = _make(ticker);
      addTearDown(c.dispose);
      c.start(const Duration(seconds: 90));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Align(alignment: Alignment.bottomCenter, child: RestTimerBar(controller: c))),
      ));
      expect(find.text('60 s'), findsOneWidget);
      expect(find.text('90 s'), findsOneWidget);
      expect(find.text('120 s'), findsOneWidget);
      expect(find.text('01:30'), findsOneWidget);

      await tester.tap(find.text('120 s'));
      await tester.pump();
      await tester.runAsync(_settle);
      expect(c.total, const Duration(seconds: 120));
      expect(find.text('02:00'), findsOneWidget);
      expect(await RestTimerPrefs.load(), 120);

      for (final chip in ['60 s', '90 s', '120 s']) {
        expect(
            tester
                .getSize(find.ancestor(of: find.text(chip), matching: find.byType(InkWell)).first)
                .height,
            greaterThanOrEqualTo(52));
      }
    });

    testWidgets('skip button stops the timer', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final ticker = _FakeTicker();
      final c = _make(ticker);
      addTearDown(c.dispose);
      c.start(const Duration(seconds: 60));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Align(alignment: Alignment.bottomCenter, child: RestTimerBar(controller: c))),
      ));
      await tester.tap(find.text("O'tkazib yuborish"));
      await tester.pump();
      expect(c.running, isFalse);
    });

    testWidgets('saves the pick under the exercise key and fits 360 px', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final ticker = _FakeTicker();
      final c = _make(ticker);
      addTearDown(c.dispose);
      c.start(const Duration(seconds: 90));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Align(
                alignment: Alignment.bottomCenter,
                child: RestTimerBar(controller: c, exerciseKey: 'squat'))),
      ));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('120 s'));
      await tester.pump();
      await tester.runAsync(_settle);
      expect(await RestTimerPrefs.load('squat'), 120);
      expect(await RestTimerPrefs.load('other'), 120);
    });
  });
}
