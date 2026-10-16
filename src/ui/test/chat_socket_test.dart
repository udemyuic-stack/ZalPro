import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:kotta_qani_diet/services/api/chat_socket.dart';

class FakeSink implements WebSocketSink {
  FakeSink(this.owner);

  final FakeChannel owner;

  @override
  void add(dynamic data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) async {}

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    owner.clientClosed = true;
    await owner.incoming.close();
  }

  @override
  Future<void> get done => owner.incoming.done;
}

class FakeChannel implements WebSocketChannel {
  FakeChannel(this.uri);

  final Uri uri;
  final StreamController<dynamic> incoming = StreamController<dynamic>();
  bool clientClosed = false;
  int? serverCode;

  @override
  int? get closeCode => serverCode;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future.value();

  @override
  Stream<dynamic> get stream => incoming.stream;

  @override
  WebSocketSink get sink => FakeSink(this);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  void serverSend(Object frame) => incoming.add(frame);

  Future<void> serverClose(int? code) async {
    serverCode = code;
    await incoming.close();
  }
}

class CapturedTimer implements Timer {
  CapturedTimer(this.duration, this.callback);

  final Duration duration;
  final void Function() callback;
  bool cancelled = false;
  bool fired = false;

  void fire() {
    fired = true;
    callback();
  }

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled && !fired;

  @override
  int get tick => 0;
}

String frame(String id, {String text = 'hi'}) => jsonEncode({
      'id': id,
      'sender_id': 'u1',
      'text': text,
      'created_at': '2026-01-01T10:00:00Z',
    });

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late List<FakeChannel> channels;
  late List<CapturedTimer> timers;
  late int tokenCounter;
  late int refreshCalls;
  late bool refreshResult;
  late ChatSocket socket;

  setUp(() {
    channels = [];
    timers = [];
    tokenCounter = 0;
    refreshCalls = 0;
    refreshResult = true;
    socket = ChatSocket(
      baseUrl: 'https://api.example.com',
      chatUid: 'chat1',
      accessToken: () async => 'tok${++tokenCounter}',
      refresh: () async {
        refreshCalls++;
        return refreshResult;
      },
      connect: (uri) {
        final channel = FakeChannel(uri);
        channels.add(channel);
        return channel;
      },
      timerFactory: (duration, callback) {
        final timer = CapturedTimer(duration, callback);
        timers.add(timer);
        return timer;
      },
    );
  });

  tearDown(() async {
    await socket.dispose();
  });

  test('connects with token in query and wss for https', () async {
    await socket.start();
    expect(channels, hasLength(1));
    final uri = channels.single.uri;
    expect(uri.scheme, 'wss');
    expect(uri.host, 'api.example.com');
    expect(uri.path, '/v1/ws/chats/chat1');
    expect(uri.queryParameters['token'], 'tok1');
  });

  test('http base url maps to ws with port', () async {
    final local = ChatSocket(
      baseUrl: 'http://localhost:8000',
      chatUid: 'c',
      accessToken: () async => 't',
      refresh: () async => true,
      connect: (uri) {
        final channel = FakeChannel(uri);
        channels.add(channel);
        return channel;
      },
      timerFactory: (d, c) => CapturedTimer(d, c),
    );
    await local.start();
    expect(channels.single.uri.toString(), 'ws://localhost:8000/v1/ws/chats/c?token=t');
    await local.dispose();
  });

  test('delivers parsed message', () async {
    final received = <ChatSocketMessage>[];
    socket.messages.listen(received.add);
    await socket.start();
    channels.single.serverSend(frame('m1', text: 'hello'));
    await settle();
    expect(received, hasLength(1));
    expect(received.single.id, 'm1');
    expect(received.single.senderId, 'u1');
    expect(received.single.text, 'hello');
    expect(received.single.createdAt, DateTime.utc(2026, 1, 1, 10));
  });

  test('malformed frames are ignored', () async {
    final received = <ChatSocketMessage>[];
    final errors = <Object>[];
    socket.messages.listen(received.add, onError: errors.add);
    await socket.start();
    channels.single.serverSend('not json');
    channels.single.serverSend('[1,2]');
    channels.single.serverSend('{"id":"x"}');
    channels.single.serverSend(frame('ok'));
    await settle();
    expect(received.map((m) => m.id), ['ok']);
    expect(errors, isEmpty);
  });

  test('proactive timer reconnects with fresh token', () async {
    await socket.start();
    final proactive = timers.singleWhere((t) => t.duration == const Duration(minutes: 14));
    proactive.fire();
    await settle();
    expect(channels, hasLength(2));
    expect(channels[1].uri.queryParameters['token'], 'tok2');
    expect(channels[0].clientClosed, isTrue);
    expect(refreshCalls, 0);
  });

  test('1008 triggers single refresh then reconnect', () async {
    await socket.start();
    await channels[0].serverClose(1008);
    await settle();
    await settle();
    expect(refreshCalls, 1);
    expect(channels, hasLength(2));
    expect(channels[1].uri.queryParameters['token'], 'tok2');
  });

  test('1008 with refresh false stops with session_expired and no reconnect', () async {
    refreshResult = false;
    final errors = <Object>[];
    socket.messages.listen((_) {}, onError: errors.add);
    await socket.start();
    await channels[0].serverClose(1008);
    await settle();
    await settle();
    expect(refreshCalls, 1);
    expect(channels, hasLength(1));
    expect(errors, hasLength(1));
    expect(errors.single, isA<StateError>());
    expect((errors.single as StateError).message, 'session_expired');
    for (final timer in timers.where((t) => t.duration != const Duration(minutes: 14))) {
      expect(timer.fired, isFalse);
    }
  });

  test('repeated 1008 without a frame does not loop refresh', () async {
    final errors = <Object>[];
    socket.messages.listen((_) {}, onError: errors.add);
    await socket.start();
    await channels[0].serverClose(1008);
    await settle();
    await settle();
    await channels[1].serverClose(1008);
    await settle();
    await settle();
    expect(refreshCalls, 1);
    expect(channels, hasLength(2));
    expect(errors, hasLength(1));
  });

  test('generic drop reconnects with exponential backoff and resets after frame', () async {
    await socket.start();
    await channels[0].serverClose(1006);
    await settle();
    var backoff = timers.where((t) => t.duration < const Duration(minutes: 1) && !t.fired).last;
    expect(backoff.duration, const Duration(seconds: 1));
    backoff.fire();
    await settle();
    expect(channels, hasLength(2));

    await channels[1].serverClose(null);
    await settle();
    backoff = timers.where((t) => t.duration < const Duration(minutes: 1) && !t.fired).last;
    expect(backoff.duration, const Duration(seconds: 2));
    backoff.fire();
    await settle();
    expect(channels, hasLength(3));

    channels[2].serverSend(frame('m'));
    await settle();
    await channels[2].serverClose(1006);
    await settle();
    backoff = timers.where((t) => t.duration < const Duration(minutes: 1) && !t.fired).last;
    expect(backoff.duration, const Duration(seconds: 1));
    expect(refreshCalls, 0);
  });

  test('backoff is capped at maxBackoff', () async {
    await socket.start();
    for (var i = 0; i < 8; i++) {
      await channels.last.serverClose(1006);
      await settle();
      final backoff = timers.where((t) => t.duration < const Duration(minutes: 1) && !t.fired).last;
      expect(backoff.duration <= const Duration(seconds: 30), isTrue);
      backoff.fire();
      await settle();
    }
    final last = timers.where((t) => t.duration < const Duration(minutes: 1)).last;
    expect(last.duration, const Duration(seconds: 30));
  });

  test('dispose closes channel and prevents reconnect', () async {
    await socket.start();
    final channel = channels.single;
    await channel.serverClose(1006);
    await settle();
    final pending = timers.where((t) => t.duration < const Duration(minutes: 1) && !t.fired).last;
    await socket.dispose();
    pending.fire();
    await settle();
    expect(channels, hasLength(1));
    expect(timers.every((t) => t.cancelled || t.fired), isTrue);
  });

  test('dispose closes live channel', () async {
    await socket.start();
    await socket.dispose();
    expect(channels.single.clientClosed, isTrue);
    timers.first.fire();
    await settle();
    expect(channels, hasLength(1));
  });
}
