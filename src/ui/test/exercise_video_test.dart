import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/exercises.dart';
import 'package:kotta_qani_diet/models/gym.dart';
import 'package:kotta_qani_diet/screens/user/muscles_screen.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/api_error.dart';
import 'package:kotta_qani_diet/services/api/catalog_api.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';

import 'support/fake_api.dart';

void main() {
  late FakeAdapter adapter;
  late CatalogApi api;
  late ChangeBus bus;
  late List<String> touched;
  Future<ResponseBody> Function(RequestOptions) respond = (o) async => jsonBody({}, 200);

  setUp(() {
    respond = (o) async => jsonBody({}, 200);
    adapter = FakeAdapter((o) => respond(o));
    final client = ApiClient(store: MemorySessionStore(), baseUrl: 'http://x', adapter: adapter);
    client.setAppVersion('1.0.0+7');
    bus = ChangeBus();
    touched = [];
    bus.changes.listen(touched.add);
    api = CatalogApi(client, bus: bus, activity: PollActivity());
  });

  Map<String, dynamic> json({bool hasVideo = false}) => {
        'id': 'e1',
        'name': 'Tortish',
        'muscle': 'back',
        'sets': '3 × 10',
        'tip': 't',
        'has_video': hasVideo,
      };

  test('Exercise.fromJson reads has_video', () {
    expect(Exercise.fromJson(json(hasVideo: true))!.hasVideo, isTrue);
    expect(Exercise.fromJson(json())!.hasVideo, isFalse);
    expect(Exercise.fromJson({...json()}..remove('has_video'))!.hasVideo, isFalse);
  });

  test('Exercise.fromJson reads video_status and maxVideoBytes is 100 MB', () {
    expect(Exercise.fromJson({...json(), 'video_status': 'processing'})!.videoProcessing, isTrue);
    expect(Exercise.fromJson({...json(), 'video_status': 'failed'})!.videoFailed, isTrue);
    expect(Exercise.fromJson({...json(), 'video_status': null})!.videoStatus, '');
    expect(Exercise.fromJson(json())!.videoStatus, '');
    expect(Exercise.maxVideoBytes, 100 * 1024 * 1024);
  });

  test('Exercise.videoContentType maps extension and mime', () {
    expect(Exercise.videoContentType('a.MP4'), 'video/mp4');
    expect(Exercise.videoContentType('a.mov'), 'video/quicktime');
    expect(Exercise.videoContentType('a.webm'), 'video/webm');
    expect(Exercise.videoContentType('a.bin', 'video/quicktime'), 'video/quicktime');
    expect(Exercise.videoContentType('a.mkv'), isNull);
    expect(Exercise.videoContentType('noext'), isNull);
    expect(Exercise.videoContentType('a.mkv', 'video/webm; codecs=vp9'), 'video/webm');
  });

  test('uploadExerciseVideo: slot, direct PUT without app headers, confirm, touch', () async {
    respond = (o) async {
      if (o.path == '/v1/exercises/e1/video/upload-url') {
        return jsonBody({'key': 'videos/e1/abc', 'upload_url': 'https://r2.test/put?sig=1'}, 201);
      }
      if (o.uri.host == 'r2.test') return ResponseBody.fromString('', 200);
      return jsonBody({'status': 'processing'}, 202);
    };
    await api.uploadExerciseVideo(
      'e1',
      size: 1000,
      contentType: 'video/quicktime',
      bytes: Uint8List(1000),
    );
    final calls = adapter.calls;
    expect(calls.map((c) => '${c.method} ${c.uri.host}${c.uri.path}'), [
      'POST x/v1/exercises/e1/video/upload-url',
      'PUT r2.test/put',
      'PUT x/v1/exercises/e1/video',
    ]);
    expect(calls[0].data, {'size': 1000, 'content_type': 'video/quicktime'});
    expect(calls[1].headers.containsKey('X-App-Version'), isFalse);
    expect(calls[1].headers.containsKey('Authorization'), isFalse);
    expect(calls[1].contentType, 'video/quicktime');
    expect(calls[2].data, {'key': 'videos/e1/abc'});
    expect(touched, ['exercises']);
  });

  test('uploadExerciseVideo: stream upload sets content length and type', () async {
    respond = (o) async {
      if (o.path.endsWith('/upload-url')) {
        return jsonBody({'key': 'k', 'upload_url': 'https://r2.test/put'}, 201);
      }
      if (o.uri.host == 'r2.test') return ResponseBody.fromString('', 200);
      return jsonBody({'status': 'processing'}, 202);
    };
    await api.uploadExerciseVideo(
      'e1',
      size: 6,
      contentType: 'video/webm',
      open: () => Stream.value(Uint8List(6)),
    );
    final put = adapter.calls[1];
    expect(put.contentType, 'video/webm');
    expect(put.headers[Headers.contentLengthHeader], 6);
    expect(touched, ['exercises']);
  });

  test('uploadExerciseVideo: over 100 MB rejected before any request', () async {
    await expectLater(
      api.uploadExerciseVideo(
        'e1',
        size: Exercise.maxVideoBytes + 1,
        contentType: 'video/mp4',
        bytes: Uint8List(1),
      ),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'video_too_large')),
    );
    expect(adapter.calls, isEmpty);
    expect(touched, isEmpty);
  });

  test('uploadExerciseVideo: unsupported type rejected before any request', () async {
    await expectLater(
      api.uploadExerciseVideo('e1', size: 1, contentType: 'video/x-matroska', bytes: Uint8List(1)),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'video_type_unsupported')),
    );
    expect(adapter.calls, isEmpty);
  });

  test('uploadExerciseVideo: missing slot fails and never confirms', () async {
    respond = (o) async => jsonBody({}, 200);
    await expectLater(
      api.uploadExerciseVideo('e1', size: 10, contentType: 'video/mp4', bytes: Uint8List(10)),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'upload_slot_missing')),
    );
    expect(adapter.calls, hasLength(1));
    expect(touched, isEmpty);
  });

  test('uploadExerciseVideo: failed PUT does not confirm', () async {
    respond = (o) async {
      if (o.path.endsWith('/upload-url')) {
        return jsonBody({'key': 'videos/e1/abc', 'upload_url': 'https://r2.test/put'}, 201);
      }
      return ResponseBody.fromString('', 403);
    };
    await expectLater(
      api.uploadExerciseVideo('e1', size: 10, contentType: 'video/mp4', bytes: Uint8List(10)),
      throwsA(isA<ApiException>()),
    );
    expect(adapter.calls.where((c) => c.method == 'PUT' && c.uri.host == 'x'), isEmpty);
    expect(touched, isEmpty);
  });

  group('waitVideoReady', () {
    const fast = Duration(milliseconds: 1);

    test('polls until ready and touches exercises', () async {
      final statuses = ['processing', 'processing', 'ready'];
      respond = (o) async => jsonBody({'status': statuses.removeAt(0), 'url': null}, 200);
      expect(await api.waitVideoReady('e1', interval: fast), 'ready');
      expect(touched, ['exercises']);
      expect(adapter.calls.where((c) => c.path == '/v1/exercises/e1/video'), hasLength(3));
    });

    test('returns failed', () async {
      respond = (o) async => jsonBody({'status': 'failed', 'url': null}, 200);
      expect(await api.waitVideoReady('e1', interval: fast), 'failed');
    });

    test('stops when cancelled without further requests', () async {
      respond = (o) async => jsonBody({'status': 'processing', 'url': null}, 200);
      var polls = 0;
      final result = await api.waitVideoReady(
        'e1',
        interval: fast,
        cancelled: () => polls++ >= 2,
      );
      expect(result, 'processing');
      expect(adapter.calls, hasLength(2));
    });

    test('survives a network error and times out as failed', () async {
      var n = 0;
      respond = (o) async {
        if (n++ == 0) return ResponseBody.fromString('', 503);
        return jsonBody({'status': 'processing', 'url': null}, 200);
      };
      expect(
        await api.waitVideoReady('e1', interval: fast, timeout: const Duration(milliseconds: 20)),
        'failed',
      );
      expect(n, greaterThan(1));
    });

    test('client errors are rethrown', () async {
      respond = (o) async => jsonBody({'detail': 'x'}, 404);
      await expectLater(
        api.waitVideoReady('e1', interval: fast),
        throwsA(isA<ApiException>()),
      );
    });
  });

  test('exerciseVideoUrl: GET returns url', () async {
    respond = (o) async => jsonBody({'status': 'ready', 'url': 'https://r2.test/get?sig=2'}, 200);
    expect(await api.exerciseVideoUrl('e1'), 'https://r2.test/get?sig=2');
    expect(adapter.calls.last.method, 'GET');
    expect(adapter.calls.last.path, '/v1/exercises/e1/video');
  });

  test('deleteExerciseVideo: DELETE and touch exercises', () async {
    respond = (o) async => ResponseBody.fromString('', 204);
    await api.deleteExerciseVideo('e1');
    expect(adapter.calls.last.method, 'DELETE');
    expect(adapter.calls.last.path, '/v1/exercises/e1/video');
    expect(touched, ['exercises']);
  });

  test('apiErrorText maps video error codes', () {
    String text(String code) => apiErrorText(ApiException(code: code, message: ''));
    expect(text('video_too_large'), isNot('video_too_large'));
    expect(text('video_type_unsupported'), isNot('video_type_unsupported'));
    expect(text('video_not_uploaded'), isNot('video_not_uploaded'));
  });

  group('muscle screen player', () {
    Exercise stored() => Exercise('R2 mashq', 'chest', '3 × 10', 'Sekin',
        id: 'v1', hasVideo: true, createdAt: DateTime.now());

    Future<void> open(WidgetTester t, Exercise e) async {
      t.view.physicalSize = const Size(420, 7000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      addTearDown(() {
        debugVideoPlayer = null;
        debugVideoUrl = null;
      });
      await t.pumpWidget(MaterialApp(
        home: MusclesScreen(
            gymDays: evenDays, weekday: DateTime.tuesday, onBack: () {}, custom: Stream.value([e])),
      ));
      await t.pump(const Duration(seconds: 3));
      await t.tap(find.text(e.name));
      await t.pump(const Duration(seconds: 1));
    }

    testWidgets('hasVideo: loads signed url and shows stored player', (t) async {
      final asked = <String>[];
      String? shown;
      debugVideoUrl = (id) async {
        asked.add(id);
        return 'https://r2.test/get';
      };
      debugVideoPlayer = (u) {
        shown = u;
        return const Text('R2-PLAYER');
      };
      await open(t, stored());
      await t.pump(const Duration(milliseconds: 200));
      expect(asked, ['v1']);
      expect(shown, 'https://r2.test/get');
      expect(find.text('R2-PLAYER'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('no hasVideo: no player and no signed url requested', (t) async {
      var asked = 0;
      debugVideoUrl = (id) async {
        asked++;
        return 'x';
      };
      debugVideoPlayer = (u) => const Text('R2-PLAYER');
      await open(
        t,
        Exercise('Videosiz mashq', 'chest', '3 × 10', 'Sekin', id: 'v2', createdAt: DateTime.now()),
      );
      expect(asked, 0);
      expect(find.text('R2-PLAYER'), findsNothing);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.byIcon(Icons.videocam_off_outlined), findsNothing);
    });

    testWidgets('processing without url shows preparing placeholder', (t) async {
      debugVideoUrl = (id) async => '';
      debugVideoPlayer = (u) => const Text('R2-PLAYER');
      await open(
        t,
        Exercise('Tayyorlanayotgan', 'chest', '3 × 10', 'Sekin',
            id: 'v3', videoStatus: 'processing', createdAt: DateTime.now()),
      );
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('Video tayyorlanmoqda'), findsOneWidget);
      expect(find.text('R2-PLAYER'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('failed without url shows nothing', (t) async {
      var asked = 0;
      debugVideoUrl = (id) async {
        asked++;
        return '';
      };
      debugVideoPlayer = (u) => const Text('R2-PLAYER');
      await open(
        t,
        Exercise('Buzilgan', 'chest', '3 × 10', 'Sekin',
            id: 'v4', videoStatus: 'failed', createdAt: DateTime.now()),
      );
      expect(asked, 0);
      expect(find.text('Video tayyorlanmoqda'), findsNothing);
      expect(find.text('R2-PLAYER'), findsNothing);
    });

    testWidgets('processing with previous video keeps the player', (t) async {
      debugVideoUrl = (id) async => 'https://r2.test/old';
      debugVideoPlayer = (u) => const Text('R2-PLAYER');
      await open(
        t,
        Exercise('Almashmoqda', 'chest', '3 × 10', 'Sekin',
            id: 'v5', hasVideo: true, videoStatus: 'processing', createdAt: DateTime.now()),
      );
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('R2-PLAYER'), findsOneWidget);
    });

    testWidgets('url fetch error shows retry, retry loads player', (t) async {
      var fail = true;
      debugVideoUrl = (id) async {
        if (fail) {
          throw const ApiException(code: ApiException.networkCode, message: '');
        }
        return 'https://r2.test/get';
      };
      debugVideoPlayer = (u) => const Text('R2-PLAYER');
      await open(t, stored());
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('R2-PLAYER'), findsNothing);
      fail = false;
      await t.tap(find.byType(TextButton).last);
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('R2-PLAYER'), findsOneWidget);
    });
  });
}
