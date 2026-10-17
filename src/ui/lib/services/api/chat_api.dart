import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/api_config.dart';
import '../../l10n/tr.dart';
import '../../models/exercises.dart';
import '../../models/models.dart';
import 'api_error.dart';
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
          known[m.id] = ChatMessage(
            m.senderId,
            m.text,
            m.createdAt,
            mediaKind: m.mediaKind,
            mediaStatus: m.mediaStatus,
            mediaUrl: m.mediaUrl,
            mediaDurationMs: m.mediaDurationMs,
          );
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
    final source = live ? _live(chatUid) : messageEvents(chatUid);
    return source.map((rows) => [for (final (_, m) in rows) m]);
  }

  Stream<ChatEvents> messageEvents(String chatUid) {
    return _watchers
        .putIfAbsent(
          chatUid,
          () => SharedStream(() => _polled(chatUid, _recent, _notify)),
        )
        .stream;
  }

  Future<void> send(String chatUid, String text) => sendMessage(chatUid, text: text);

  Future<void> sendMessage(
    String chatUid, {
    String text = '',
    String? mediaKey,
    String? mediaKind,
    int? durationMs,
  }) {
    final body = <String, Object?>{
      if (text.isNotEmpty || mediaKey == null) 'text': text,
      if (mediaKey != null) 'media_key': mediaKey,
      if (mediaKey != null) 'media_kind': mediaKind,
      if (durationMs != null) 'media_duration_ms': durationMs,
    };
    return write('POST', '/v1/chats/$chatUid/messages', body, ['chat:$chatUid']);
  }

  Future<({String key, String uploadUrl})> createMediaUpload(
    String chatUid, {
    required String kind,
    required String contentType,
    required int size,
  }) async {
    final slot = await client.request<Map<String, dynamic>>(
      'POST',
      '/v1/chats/$chatUid/media/upload-url',
      data: {'kind': kind, 'content_type': contentType, 'size': size},
    );
    final key = jsonString(slot?['key']);
    final target = jsonString(slot?['upload_url']);
    if (key.isEmpty || target.isEmpty) {
      throw const ApiException(code: 'upload_slot_missing', message: '');
    }
    return (key: key, uploadUrl: target);
  }

  Future<String> uploadChatMedia(
    String chatUid, {
    required String kind,
    required String contentType,
    required int size,
    Uint8List? bytes,
    Stream<List<int>> Function()? open,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final isVideo = kind == ChatMessage.mediaVideo;
    final isAudio = kind == ChatMessage.mediaAudio;
    if (isAudio) {
      if (size > ChatMessage.maxAudioBytes) {
        throw ApiException(code: 'chat_audio_too_large', message: tr('Audio 5 MB dan katta'));
      }
      if (contentType != ChatMessage.audioContentType) {
        throw const ApiException(code: 'audio_type_unsupported', message: '');
      }
    }
    if (isVideo && size > ChatMessage.maxVideoBytes) {
      throw ApiException(code: 'chat_video_too_large', message: tr('Video 50 MB dan katta'));
    }
    if (!isVideo && !isAudio && size > ApiService.maxImageBytes) {
      throw ApiException(code: 'image_too_large', message: tr('Rasm 5 MB dan katta'));
    }
    if (isVideo && !Exercise.videoTypes.containsValue(contentType)) {
      throw const ApiException(code: 'video_type_unsupported', message: '');
    }
    if (bytes == null && open == null) {
      throw const ApiException(code: 'upload_slot_missing', message: '');
    }
    final slot = await createMediaUpload(
      chatUid,
      kind: kind,
      contentType: contentType,
      size: size,
    );
    if (bytes != null) {
      await client.uploadBytes(
        slot.uploadUrl,
        bytes,
        contentType: contentType,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } else {
      await client.uploadStream(
        slot.uploadUrl,
        open!(),
        size,
        contentType: contentType,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    }
    return slot.key;
  }
}
