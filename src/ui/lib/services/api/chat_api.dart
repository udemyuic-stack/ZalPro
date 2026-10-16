import 'dart:async';

import '../../core/api_config.dart';
import '../../models/models.dart';
import 'api_service.dart';
import 'chat_socket.dart';
import 'json_helpers.dart';
import 'poll_stream.dart';

typedef ChatEvents = List<(String, ChatMessage)>;

class ChatApi extends ApiService {
  ChatApi(
    super.client, {
    super.bus,
    super.activity,
    ChatSocket Function(String chatUid)? socketFactory,
  }) : _socketFactory = socketFactory;

  static const _recent = 50;
  static const _events = 20;
  static const _fallback = Duration(seconds: 30);
  static const _notify = Duration(seconds: 25);

  final ChatSocket Function(String chatUid)? _socketFactory;
  final _watchers = <String, SharedStream<ChatEvents>>{};

  ChatSocket _socket(String chatUid) {
    final factory = _socketFactory;
    if (factory != null) return factory(chatUid);
    return ChatSocket(
      baseUrl: apiUrl,
      chatUid: chatUid,
      accessToken: () async => client.accessToken,
      refresh: client.refreshSession,
    );
  }

  Future<ChatEvents> _fetch(String chatUid, int limit) async {
    final rows = await client.getList('/v1/chats/$chatUid/messages', query: {'limit': limit});
    return [
      for (final row in jsonMaps(rows)) (jsonString(row['id']), ChatMessage.fromJson(row)),
    ];
  }

  Stream<ChatEvents> _polled(String chatUid, int limit, Duration every) =>
      poll(() => _fetch(chatUid, limit), every, {'chat:$chatUid'});

  Stream<ChatEvents> _live(String chatUid) {
    final known = <String, ChatMessage>{};
    StreamSubscription<ChatEvents>? rest;
    StreamSubscription<ChatSocketMessage>? live;
    ChatSocket? socket;
    late final StreamController<ChatEvents> out;

    void emit() {
      final all = known.entries.map((e) => (e.key, e.value)).toList()
        ..sort((a, b) => b.$2.createdAt.compareTo(a.$2.createdAt));
      if (!out.isClosed) out.add(all.take(_recent).toList());
    }

    out = StreamController<ChatEvents>(
      onListen: () {
        rest = _polled(chatUid, _recent, _fallback).listen((rows) {
          for (final (id, m) in rows) {
            known[id] = m;
          }
          emit();
        }, onError: out.addError);
        final s = _socket(chatUid);
        socket = s;
        live = s.messages.listen((m) {
          known[m.id] = ChatMessage(m.senderId, m.text, m.createdAt);
          emit();
        }, onError: (Object _) {});
        unawaited(s.start());
      },
      onCancel: () async {
        await rest?.cancel();
        await live?.cancel();
        await socket?.dispose();
        await out.close();
      },
    );
    return out.stream;
  }

  Stream<List<ChatMessage>> messages(String chatUid, {required bool live}) {
    final source = live ? _live(chatUid) : _polled(chatUid, _recent, _notify);
    return source.map((rows) => [for (final (_, m) in rows) m]);
  }

  Stream<ChatEvents> messageEvents(String chatUid) {
    return _watchers
        .putIfAbsent(
          chatUid,
          () => SharedStream(() => _polled(chatUid, _events, _notify)),
        )
        .stream;
  }

  Future<void> send(String chatUid, String text) =>
      write('POST', '/v1/chats/$chatUid/messages', {'text': text}, ['chat:$chatUid']);
}
