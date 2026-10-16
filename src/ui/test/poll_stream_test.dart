import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/services/api/api_error.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';

const _tick = Duration(milliseconds: 30);
const _wait = Duration(milliseconds: 150);

void main() {
  sharedStreamTests();
  late ChangeBus bus;
  late PollActivity activity;

  setUp(() {
    bus = ChangeBus();
    activity = PollActivity();
  });

  Stream<int> counter(int Function() next, {Set<String> tags = const {}, Duration every = _tick}) =>
      pollStream<int>(() async => next(), every: every, tags: tags, bus: bus, activity: activity);

  test('first value arrives immediately', () async {
    var calls = 0;
    final first = await counter(() => ++calls, every: const Duration(hours: 1)).first;
    expect(first, 1);
    expect(calls, 1);
  });

  test('no subscriber means no request', () async {
    var calls = 0;
    counter(() => ++calls);
    await Future<void>.delayed(_wait);
    expect(calls, 0);
  });

  test('polls on the interval and stops after cancel', () async {
    var calls = 0;
    final sub = counter(() => ++calls).listen((_) {});
    await Future<void>.delayed(_wait);
    await sub.cancel();
    final atCancel = calls;
    expect(atCancel, greaterThan(2));
    await Future<void>.delayed(_wait);
    expect(calls, atCancel);
  });

  test('touch with matching tag refetches at once', () async {
    var calls = 0;
    final values = <int>[];
    final sub = counter(() => ++calls, tags: {'orders'}, every: const Duration(hours: 1))
        .listen(values.add);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    bus.touch('orders');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    bus.touch('other');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();
    expect(values, [1, 2]);
  });

  test('after() touches tags only when the write succeeds', () async {
    final seen = <String>[];
    final sub = bus.changes.listen(seen.add);
    await bus.after(Future.value(1), ['a', 'b']);
    await expectLater(bus.after(Future<int>.error(StateError('x')), ['c']), throwsStateError);
    await sub.cancel();
    expect(seen, ['a', 'b']);
  });

  test('first failure is an error, later failures keep the last value', () async {
    var calls = 0;
    final events = <Object>[];
    final stream = pollStream<int>(
      () async {
        calls++;
        if (calls == 1) throw StateError('first');
        if (calls == 2) return 7;
        throw StateError('later');
      },
      every: _tick,
      bus: bus,
      activity: activity,
    );
    final sub = stream.listen(events.add, onError: events.add);
    await Future<void>.delayed(_wait);
    await sub.cancel();
    expect(events.length, 2);
    expect(events[0], isA<StateError>());
    expect(events[1], 7);
    expect(calls, greaterThan(3));
  });

  test('error is emitted once while there is no value', () async {
    var calls = 0;
    var errors = 0;
    final sub = pollStream<int>(
      () async {
        calls++;
        throw StateError('down');
      },
      every: _tick,
      bus: bus,
      activity: activity,
    ).listen((_) {}, onError: (_) => errors++);
    await Future<void>.delayed(_wait);
    await sub.cancel();
    expect(calls, greaterThan(2));
    expect(errors, 1);
  });

  test('401 stops polling', () async {
    var calls = 0;
    final sub = pollStream<int>(
      () async {
        calls++;
        throw const ApiException(code: 'unauthorized', message: 'x', status: 401);
      },
      every: _tick,
      bus: bus,
      activity: activity,
    ).listen((_) {}, onError: (_) {});
    await Future<void>.delayed(_wait);
    await sub.cancel();
    expect(calls, 1);
  });

  test('paused app stops polling and resume refetches', () async {
    var calls = 0;
    final sub = counter(() => ++calls).listen((_) {});
    await Future<void>.delayed(_wait);
    activity.value = false;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    final paused = calls;
    await Future<void>.delayed(_wait);
    expect(calls, paused);
    activity.value = true;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();
    expect(calls, paused + 1);
  });

  test('touch during an in-flight fetch queues exactly one more', () async {
    var calls = 0;
    final gate = Completer<void>();
    final sub = pollStream<int>(
      () async {
        calls++;
        if (calls == 1) await gate.future;
        return calls;
      },
      every: const Duration(hours: 1),
      tags: {'x'},
      bus: bus,
      activity: activity,
    ).listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 10));
    bus.touch('x');
    bus.touch('x');
    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    await sub.cancel();
    expect(calls, 2);
  });
}

void sharedStreamTests() {
  group('SharedStream', () {
    test('opens the source once for many listeners and replays the last value', () async {
      var opens = 0;
      late StreamController<int> source;
      final shared = SharedStream<int>(() {
        opens++;
        source = StreamController<int>();
        return source.stream;
      });
      final a = <int>[];
      final b = <int>[];
      final subA = shared.stream.listen(a.add);
      source.add(1);
      await Future<void>.delayed(Duration.zero);
      final subB = shared.stream.listen(b.add);
      await Future<void>.delayed(Duration.zero);
      source.add(2);
      await Future<void>.delayed(Duration.zero);
      expect(opens, 1);
      expect(a, [1, 2]);
      expect(b, [1, 2]);
      expect(shared.listeners, 2);
      await subA.cancel();
      await subB.cancel();
    });

    test('push reaches listeners and is ignored with none', () async {
      final shared = SharedStream<int>(() => const Stream<int>.empty());
      shared.push(9);
      final seen = <int>[];
      final sub = shared.stream.listen(seen.add);
      await Future<void>.delayed(Duration.zero);
      expect(seen, isEmpty);
      shared.push(4);
      await Future<void>.delayed(Duration.zero);
      expect(seen, [4]);
      await sub.cancel();
    });

    test('last listener cancels the source and clears the cache', () async {
      var cancelled = false;
      var opens = 0;
      final shared = SharedStream<int>(() {
        opens++;
        final c = StreamController<int>(onCancel: () => cancelled = true);
        return c.stream;
      });
      final sub = shared.stream.listen((_) {});
      shared.push(1);
      await sub.cancel();
      expect(cancelled, isTrue);
      expect(shared.listeners, 0);
      final seen = <int>[];
      final again = shared.stream.listen(seen.add);
      await Future<void>.delayed(Duration.zero);
      expect(opens, 2);
      expect(seen, isEmpty);
      await again.cancel();
    });

    test('source errors reach every listener', () async {
      late StreamController<int> source;
      final shared = SharedStream<int>(() {
        source = StreamController<int>();
        return source.stream;
      });
      final errors = <Object>[];
      final sub = shared.stream.listen((_) {}, onError: errors.add);
      source.addError('boom');
      await Future<void>.delayed(Duration.zero);
      expect(errors, ['boom']);
      await sub.cancel();
    });
  });
}
