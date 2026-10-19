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
  Duration coalesce = const Duration(milliseconds: 300),
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
  var queued = false;
  DateTime? lastForced;
  Timer? trailing;

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

  void forced() {
    lastForced = DateTime.now();
    unawaited(run());
  }

  void fire() {
    if (closed || stopped || !active.value) return;
    if (running) {
      again = true;
      return;
    }
    final last = lastForced;
    final wait = last == null ? Duration.zero : coalesce - DateTime.now().difference(last);
    if (wait <= Duration.zero) {
      trailing?.cancel();
      trailing = null;
      forced();
      return;
    }
    trailing ??= Timer(wait, () {
      trailing = null;
      if (!closed) forced();
    });
  }

  void trigger() {
    if (queued) return;
    queued = true;
    scheduleMicrotask(() {
      queued = false;
      fire();
    });
  }

  void onActivity() {
    if (active.value) {
      trigger();
    } else {
      timer?.cancel();
      trailing?.cancel();
      trailing = null;
    }
  }

  controller = StreamController<T>(
    onListen: () {
      tagSub = changes.changes.listen((tag) {
        if (tags.contains(tag)) trigger();
      });
      active.addListener(onActivity);
      unawaited(run());
    },
    onCancel: () async {
      closed = true;
      timer?.cancel();
      trailing?.cancel();
      active.removeListener(onActivity);
      await tagSub?.cancel();
    },
  );
  return controller.stream;
}

class SharedStream<T> {
  SharedStream(this._open, {this.grace = Duration.zero});

  final Stream<T> Function() _open;
  final Duration grace;
  Timer? _closing;
  ({Object error, StackTrace stack})? _failure;
  final _hub = StreamController<T>.broadcast(sync: true);
  StreamSubscription<T>? _source;
  var _count = 0;
  ({T value})? _last;

  int get listeners => _count;

  void push(T value) {
    if (_count == 0 && _closing == null) return;
    _last = (value: value);
    _failure = null;
    _hub.add(value);
  }

  void _fail(Object error, StackTrace stack) {
    if (_last == null) _failure = (error: error, stack: stack);
    _hub.addError(error, stack);
  }

  Future<void> _close() async {
    _closing = null;
    if (_count > 0) return;
    final source = _source;
    _source = null;
    _last = null;
    _failure = null;
    await source?.cancel();
  }

  Stream<T> get stream => Stream<T>.multi((out) {
        _count++;
        _closing?.cancel();
        _closing = null;
        if (_source == null) {
          _source = _open().listen(push, onError: _fail);
        }
        final last = _last;
        final failure = _failure;
        if (last != null) {
          out.add(last.value);
        } else if (failure != null) {
          out.addError(failure.error, failure.stack);
        }
        final sub = _hub.stream.listen(out.add, onError: out.addError);
        out.onCancel = () async {
          await sub.cancel();
          if (--_count == 0) {
            if (grace == Duration.zero) {
              await _close();
            } else {
              _closing = Timer(grace, () => unawaited(_close()));
            }
          }
        };
      });
}
