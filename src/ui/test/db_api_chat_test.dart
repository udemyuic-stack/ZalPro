import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/chat_api.dart';
import 'package:kotta_qani_diet/services/api/chat_socket.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';

import 'support/fake_api.dart';

class FakeSocket extends ChatSocket {
  FakeSocket(String uid)
      : super(
          baseUrl: 'http://x',
          chatUid: uid,
          accessToken: () async => 't',
          refresh: () async => true,
        );

  final feed = StreamController<ChatSocketMessage>.broadcast();
  var started = false;
  var disposed = false;

  @override
  Stream<ChatSocketMessage> get messages => feed.stream;

  @override
  Future<void> start() async => started = true;

  @override
  Future<void> dispose() async => disposed = true;
}

Map<String, dynamic> msg(String id, String sender, String at, [String text = 'salom']) => {
      'id': id,
      'chat_uid': 'u1',
      'sender_id': sender,
      'kind': 'user',
      'text': text,
      'created_at': at,
    };

void main() {
  late FakeAdapter adapter;
  late ChatApi api;
  late List<FakeSocket> sockets;
  late List<String> touched;
  Future<ResponseBody> Function(RequestOptions) respond = (o) async => jsonBody([], 200);

  setUp(() {
    respond = (o) async => jsonBody([], 200);
    adapter = FakeAdapter((o) => respond(o));
    final client = ApiClient(store: MemorySessionStore(), baseUrl: 'http://x', adapter: adapter);
    final bus = ChangeBus();
    touched = [];
    bus.changes.listen(touched.add);
    sockets = [];
    api = ChatApi(client, bus: bus, activity: PollActivity(), socketFactory: (uid) {
      final s = FakeSocket(uid);
      sockets.add(s);
      return s;
    });
  });

  RequestOptions last() => adapter.calls.last;

  test('messages live: REST last 50 newest first, socket frames merge without duplicates',
      () async {
    respond = (o) async => jsonBody([
          msg('b', 'u1', '2026-05-10T10:00:00Z', 'ikkinchi'),
          msg('a', 'u1', '2026-05-10T09:00:00Z', 'birinchi'),
        ], 200);
    final seen = <List<String>>[];
    final sub = api.messages('u1', live: true).listen((l) => seen.add([for (final m in l) m.text]));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(last().path, '/v1/chats/u1/messages');
    expect(last().queryParameters, {'limit': 50});
    expect(seen.last, ['ikkinchi', 'birinchi']);
    expect(sockets.single.started, true);

    sockets.single.feed.add(ChatSocketMessage(
      id: 'c',
      senderId: 't1',
      text: 'uchinchi',
      createdAt: DateTime.utc(2026, 5, 10, 11),
    ));
    sockets.single.feed.add(ChatSocketMessage(
      id: 'c',
      senderId: 't1',
      text: 'uchinchi',
      createdAt: DateTime.utc(2026, 5, 10, 11),
    ));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(seen.last, ['uchinchi', 'ikkinchi', 'birinchi']);

    await sub.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(sockets.single.disposed, true);
  });

  test('messages live: socket frame already in REST page does not duplicate', () async {
    respond = (o) async => jsonBody([msg('a', 'u1', '2026-05-10T09:00:00Z')], 200);
    List<String> ids = [];
    final sub = api.messages('u1', live: true).listen((l) => ids = [for (final m in l) m.text]);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    sockets.single.feed.add(ChatSocketMessage(
      id: 'a',
      senderId: 'u1',
      text: 'salom',
      createdAt: DateTime.utc(2026, 5, 10, 9),
    ));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(ids.length, 1);
    await sub.cancel();
  });

  test('messages not live: polls REST only and opens no socket', () async {
    respond = (o) async => jsonBody([msg('a', 'u1', '2026-05-10T09:00:00Z')], 200);
    final list = await api.messages('u1', live: false).first;
    expect(list.single.text, 'salom');
    expect(sockets, isEmpty);
  });

  test('messageEvents: limit 20 with ids, one shared poll per chat', () async {
    respond = (o) async => jsonBody([
          msg('b', 'u1', '2026-05-10T10:00:00Z'),
          msg('a', 'u1', '2026-05-10T09:00:00Z'),
        ], 200);
    final first = api.messageEvents('u1').listen((_) {});
    final second = await api.messageEvents('u1').first;
    expect(second.map((e) => e.$1), ['b', 'a']);
    expect(last().queryParameters, {'limit': 20});
    expect(adapter.count('/v1/chats/u1/messages'), 1);
    await first.cancel();
  });

  test('send: POST only text, touches chat tag', () async {
    respond = (o) async => jsonBody(msg('z', 't1', '2026-05-10T12:00:00Z', 'yo'), 201);
    await api.send('u1', 'yo');
    expect(last().method, 'POST');
    expect(last().path, '/v1/chats/u1/messages');
    expect(last().data, {'text': 'yo'});
    await Future<void>.delayed(Duration.zero);
    expect(touched, contains('chat:u1'));
  });

  test('send: failure surfaces and touches nothing', () async {
    respond = (o) async => jsonBody({
          'detail': {'code': 'forbidden', 'message': 'x'}
        }, 403);
    await expectLater(api.send('u1', 'yo'), throwsA(anything));
    await Future<void>.delayed(Duration.zero);
    expect(touched, isEmpty);
  });
}
