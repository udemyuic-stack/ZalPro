import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/api_error.dart';
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

  @override
  Stream<ChatSocketMessage> get messages => feed.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> dispose() async {}
}

Map<String, dynamic> row(
  String id,
  String at, {
  String text = '',
  String? kind,
  String? status,
  String? url,
}) =>
    {
      'id': id,
      'chat_uid': 'u1',
      'sender_id': 'u1',
      'kind': 'user',
      'text': text,
      'created_at': at,
      'media_kind': kind,
      'media_status': status,
      'media_url': url,
    };

void main() {
  group('ChatMessage media', () {
    test('parses media fields', () {
      final m = ChatMessage.fromJson(
          row('a', '2026-05-10T09:00:00Z', kind: 'image', status: 'ready', url: 'http://r2/a'));
      expect(m.hasMedia, true);
      expect(m.isImage, true);
      expect(m.isVideo, false);
      expect(m.mediaStatus, 'ready');
      expect(m.mediaUrl, 'http://r2/a');
      expect(m.text, '');
    });

    test('plain text message has no media', () {
      final m = ChatMessage.fromJson({
        'sender_id': 'u1',
        'text': 'salom',
        'created_at': '2026-05-10T09:00:00Z',
      });
      expect(m.hasMedia, false);
      expect(m.mediaKind, '');
      expect(m.mediaUrl, '');
      expect(m.preview, 'salom');
    });

    test('processing video has no url and previews as video', () {
      final m = ChatMessage.fromJson(
          row('v', '2026-05-10T09:00:00Z', kind: 'video', status: 'processing'));
      expect(m.isVideo, true);
      expect(m.mediaStatus, 'processing');
      expect(m.mediaUrl, '');
      expect(m.preview, '🎥 Video');
    });

    test('media-only image previews as photo, caption wins over placeholder', () {
      final only = ChatMessage.fromJson(
          row('i', '2026-05-10T09:00:00Z', kind: 'image', status: 'ready', url: 'u'));
      final captioned = ChatMessage.fromJson(
          row('i', '2026-05-10T09:00:00Z', text: 'mana', kind: 'image', status: 'ready', url: 'u'));
      expect(only.preview, '📷 Rasm');
      expect(captioned.preview, 'mana');
    });
  });

  group('ChatApi media', () {
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

    test('createMediaUpload: POST kind, content_type, size and returns key and url', () async {
      respond = (o) async => jsonBody(
          {'key': 'chats/u1/image/ab.jpg', 'upload_url': 'http://r2/put?s=1', 'expires_in': 600},
          201);
      final slot = await api.createMediaUpload(
        'u1',
        kind: 'image',
        contentType: 'image/jpeg',
        size: 3,
      );
      expect(last().method, 'POST');
      expect(last().path, '/v1/chats/u1/media/upload-url');
      expect(last().data, {'kind': 'image', 'content_type': 'image/jpeg', 'size': 3});
      expect(slot.key, 'chats/u1/image/ab.jpg');
      expect(slot.uploadUrl, 'http://r2/put?s=1');
    });

    test('createMediaUpload: missing slot fields throw', () async {
      respond = (o) async => jsonBody({}, 201);
      await expectLater(
        api.createMediaUpload('u1', kind: 'video', contentType: 'video/mp4', size: 3),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'upload_slot_missing')),
      );
    });

    test('uploadChatMedia: asks slot, PUTs bytes without auth, returns key', () async {
      respond = (o) async {
        if (o.path.endsWith('/media/upload-url')) {
          return jsonBody({'key': 'k1', 'upload_url': 'http://r2/put', 'expires_in': 600}, 201);
        }
        return jsonBody({}, 200);
      };
      final key = await api.uploadChatMedia(
        'u1',
        kind: 'image',
        contentType: 'image/png',
        size: 3,
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      expect(key, 'k1');
      expect(adapter.calls.first.path, '/v1/chats/u1/media/upload-url');
      final put = last();
      expect(put.method, 'PUT');
      expect(put.uri.toString(), 'http://r2/put');
      expect(put.headers['Authorization'], isNull);
      expect(put.contentType, 'image/png');
    });

    test('uploadChatMedia: oversize image and video are rejected before any request', () async {
      await expectLater(
        api.uploadChatMedia('u1',
            kind: 'image',
            contentType: 'image/jpeg',
            size: 5 * 1024 * 1024 + 1,
            bytes: Uint8List(1)),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'image_too_large')),
      );
      await expectLater(
        api.uploadChatMedia('u1',
            kind: 'video',
            contentType: 'video/mp4',
            size: ChatMessage.maxVideoBytes + 1,
            open: () => const Stream.empty()),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'chat_video_too_large')),
      );
      await expectLater(
        api.uploadChatMedia('u1',
            kind: 'video', contentType: 'video/avi', size: 10, open: () => const Stream.empty()),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'video_type_unsupported')),
      );
      expect(adapter.calls, isEmpty);
    });

    test('uploadChatMedia: failed PUT rethrows', () async {
      respond = (o) async {
        if (o.path.endsWith('/media/upload-url')) {
          return jsonBody({'key': 'k1', 'upload_url': 'http://r2/put', 'expires_in': 600}, 201);
        }
        return jsonBody({}, 403);
      };
      await expectLater(
        api.uploadChatMedia('u1',
            kind: 'image', contentType: 'image/jpeg', size: 1, bytes: Uint8List(1)),
        throwsA(anything),
      );
    });

    test('sendMessage: media-only body carries key and kind, no text', () async {
      respond = (o) async => jsonBody(row('z', '2026-05-10T12:00:00Z', kind: 'image'), 201);
      await api.sendMessage('u1', mediaKey: 'chats/u1/image/ab.jpg', mediaKind: 'image');
      expect(last().method, 'POST');
      expect(last().path, '/v1/chats/u1/messages');
      expect(last().data, {'media_key': 'chats/u1/image/ab.jpg', 'media_kind': 'image'});
      await Future<void>.delayed(Duration.zero);
      expect(touched, contains('chat:u1'));
    });

    test('sendMessage: text with media keeps the text', () async {
      respond = (o) async => jsonBody(row('z', '2026-05-10T12:00:00Z', kind: 'video'), 201);
      await api.sendMessage('u1', text: 'mana', mediaKey: 'k', mediaKind: 'video');
      expect(last().data, {'text': 'mana', 'media_key': 'k', 'media_kind': 'video'});
    });

    test('audio message carries duration and parses it back', () async {
      respond = (o) async => jsonBody(row('z', '2026-05-10T12:00:00Z', kind: 'audio'), 201);
      await api.sendMessage('u1',
          mediaKey: 'chats/u1/audio/ab.m4a', mediaKind: 'audio', durationMs: 4200);
      expect(last().data, {
        'media_key': 'chats/u1/audio/ab.m4a',
        'media_kind': 'audio',
        'media_duration_ms': 4200,
      });
      final m = ChatMessage.fromJson({
        ...row('a', '2026-05-10T09:00:00Z', kind: 'audio', status: 'ready', url: 'http://r2/a'),
        'media_duration_ms': 4200,
      });
      expect(m.isAudio, true);
      expect(m.hasMedia, true);
      expect(m.mediaDurationMs, 4200);
      expect(m.preview, '🎤 Ovozli xabar');
    });

    test('uploadChatMedia: audio over 5 MB or wrong type is rejected locally', () async {
      await expectLater(
        api.uploadChatMedia('u1',
            kind: 'audio',
            contentType: 'audio/mp4',
            size: ChatMessage.maxAudioBytes + 1,
            open: () => const Stream.empty()),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'chat_audio_too_large')),
      );
      await expectLater(
        api.uploadChatMedia('u1',
            kind: 'audio', contentType: 'audio/mpeg', size: 10, open: () => const Stream.empty()),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'audio_type_unsupported')),
      );
      expect(adapter.calls, isEmpty);
    });

    test('uploadChatMedia: audio uploads through the slot', () async {
      respond = (o) async {
        if (o.path.endsWith('/media/upload-url')) {
          return jsonBody({'key': 'k2', 'upload_url': 'http://r2/put', 'expires_in': 600}, 201);
        }
        return jsonBody({}, 200);
      };
      final key = await api.uploadChatMedia('u1',
          kind: 'audio', contentType: 'audio/mp4', size: 3, bytes: Uint8List.fromList([1, 2, 3]));
      expect(key, 'k2');
      expect(adapter.calls.first.data, {'kind': 'audio', 'content_type': 'audio/mp4', 'size': 3});
    });

    test('send and text-only sendMessage keep the legacy body', () async {
      respond = (o) async => jsonBody(row('z', '2026-05-10T12:00:00Z', text: 'yo'), 201);
      await api.send('u1', 'yo');
      expect(last().data, {'text': 'yo'});
      await api.sendMessage('u1', text: 'yo');
      expect(last().data, {'text': 'yo'});
    });

    test('sendMessage: 422 media_key_invalid surfaces as ApiException', () async {
      respond = (o) async => jsonBody({
            'detail': {'code': 'media_key_invalid', 'message': 'x'}
          }, 422);
      await expectLater(
        api.sendMessage('u1', mediaKey: 'k', mediaKind: 'image'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'media_key_invalid')),
      );
      await Future<void>.delayed(Duration.zero);
      expect(touched, isEmpty);
    });

    test('messages live: REST rows carry media fields', () async {
      respond = (o) async => jsonBody([
            row('a', '2026-05-10T09:00:00Z', kind: 'image', status: 'ready', url: 'http://r2/a'),
          ], 200);
      final list = await api.messages('u1', live: true).first;
      expect(list.single.isImage, true);
      expect(list.single.mediaUrl, 'http://r2/a');
      expect(list.single.text, '');
    });

    test('messages live: updated socket frame replaces the message by id', () async {
      respond = (o) async => jsonBody([
            row('v', '2026-05-10T09:00:00Z', kind: 'video', status: 'processing'),
            row('a', '2026-05-10T08:00:00Z', text: 'oldin'),
          ], 200);
      var latest = <ChatMessage>[];
      final sub = api.messages('u1', live: true).listen((l) => latest = l);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(latest, hasLength(2));
      expect(latest.first.mediaStatus, 'processing');

      sockets.single.feed.add(ChatSocketMessage(
        id: 'v',
        senderId: 'u1',
        text: '',
        createdAt: DateTime.utc(2026, 5, 10, 9),
        mediaKind: 'video',
        mediaStatus: 'ready',
        mediaUrl: 'http://r2/v.mp4',
        updated: true,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(latest, hasLength(2));
      expect(latest.first.mediaStatus, 'ready');
      expect(latest.first.mediaUrl, 'http://r2/v.mp4');
      expect(latest.last.text, 'oldin');

      sockets.single.feed.add(ChatSocketMessage(
        id: 'v',
        senderId: 'u1',
        text: '',
        createdAt: DateTime.utc(2026, 5, 10, 9),
        mediaKind: 'video',
        mediaStatus: 'failed',
        updated: true,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(latest, hasLength(2));
      expect(latest.first.mediaStatus, 'failed');
      await sub.cancel();
    });

    test('messages live: new media message from socket is added with its fields', () async {
      respond = (o) async => jsonBody([], 200);
      var latest = <ChatMessage>[];
      final sub = api.messages('u1', live: true).listen((l) => latest = l);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      sockets.single.feed.add(ChatSocketMessage(
        id: 'i',
        senderId: 't1',
        text: '',
        createdAt: DateTime.utc(2026, 5, 10, 9),
        mediaKind: 'image',
        mediaStatus: 'ready',
        mediaUrl: 'http://r2/i',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(latest.single.isImage, true);
      expect(latest.single.mediaUrl, 'http://r2/i');
      await sub.cancel();
    });
  });

  test('apiErrorText maps chat media codes', () {
    for (final code in ['media_key_invalid', 'media_not_uploaded', 'media_too_large']) {
      expect(apiErrorText(ApiException(code: code, message: '', status: 422)),
          isNot('Xatolik yuz berdi'));
    }
  });
}
