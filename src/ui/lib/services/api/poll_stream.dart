import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_error.dart';

class ChangeBus {
  final _controller = StreamController<String>.broadcast(sync: true);

  Stream<String> get changes => _controller.stream;

  void touch(String tag) => _controller.add(tag);

  void touchAll(Iterable<String> tags) {
    for (final tag in tags) {
      _controller.add(tag);
    }
  }

  Future<T> after<T>(Future<T> write, Iterable<String> tags) async {
    final result = await write;
    touchAll(tags);
    return result;
  }
}

class PollActivity extends ValueNotifier<bool> {
  PollActivity() : super(true);
}

final ChangeBus changeBus = ChangeBus();
final PollActivity pollActivity = PollActivity();

Stream<T> pollStream<T>(
  Future<T> Function() fetch, {
  Duration every = const Duration(seconds: 30),
  Set<String> tags = const {},
  ChangeBus? bus,
  PollActivity? activity,
}) {
  final changes = bus ?? changeBus;
  final active = activity ?? pollActivity;
  late final StreamController<T> controller;
  late final Future<void> Function() runner;
  StreamSubscription<String>? tagSub;
  Timer? timer;
  var running = false;
  var again = false;
  var hasValue = false;
  var failed = false;
  var stopped = false;
  var closed = false;

  void schedule() {
    timer?.cancel();
    if (closed || stopped || !active.value) return;
    timer = Timer(every, () => unawaited(runner()));
  }

  Future<void> run() async {
    if (closed || stopped || !active.value) return;
    if (running) {
      again = true;
      return;
    }
    running = true;
    try {
      final value = await fetch();
      if (closed) return;
      hasValue = true;
      failed = false;
      controller.add(value);
    } catch (error, stack) {
      if (closed) return;
      if (error is ApiException && error.status == 401) stopped = true;
      if (!hasValue && !failed) {
        failed = true;
        controller.addError(error, stack);
      }
    } finally {
      running = false;
    }
    if (closed) return;
    if (again) {
      again = false;
      unawaited(run());
    } else {
      schedule();
    }
  }

  runner = run;

  void onActivity() {
    if (active.value) {
      unawaited(run());
    } else {
      timer?.cancel();
    }
  }

  controller = StreamController<T>(
    onListen: () {
      tagSub = changes.changes.listen((tag) {
        if (tags.contains(tag)) unawaited(run());
      });
      active.addListener(onActivity);
      unawaited(run());
    },
    onCancel: () async {
      closed = true;
      timer?.cancel();
      active.removeListener(onActivity);
      await tagSub?.cancel();
    },
  );
  return controller.stream;
}

class SharedStream<T> {
  SharedStream(this._open);

  final Stream<T> Function() _open;
  final _hub = StreamController<T>.broadcast(sync: true);
  StreamSubscription<T>? _source;
  var _count = 0;
  ({T value})? _last;

  int get listeners => _count;

  void push(T value) {
    if (_count == 0) return;
    _last = (value: value);
    _hub.add(value);
  }

  Stream<T> get stream => Stream<T>.multi((out) {
        _count++;
        if (_count == 1) {
          _source = _open().listen(push, onError: _hub.addError);
        }
        final last = _last;
        if (last != null) out.add(last.value);
        final sub = _hub.stream.listen(out.add, onError: out.addError);
        out.onCancel = () async {
          await sub.cancel();
          if (--_count == 0) {
            final source = _source;
            _source = null;
            _last = null;
            await source?.cancel();
          }
        };
      });
}
