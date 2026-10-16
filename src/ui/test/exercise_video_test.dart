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

  test('uploadExerciseVideo: slot, direct PUT without app headers, confirm, touch', () async {
    respond = (o) async {
      if (o.path == '/v1/exercises/e1/video/upload-url') {
        return jsonBody({'key': 'videos/e1/abc', 'upload_url': 'https://r2.test/put?sig=1'}, 200);
      }
      if (o.uri.host == 'r2.test') return ResponseBody.fromString('', 200);
      return jsonBody({}, 200);
    };
    final seen = <int>[];
    await api.uploadExerciseVideo('e1', Uint8List(1000), onProgress: (s, t) => seen.add(s));
    final calls = adapter.calls;
    expect(calls.map((c) => '${c.method} ${c.uri.host}${c.uri.path}'), [
      'POST x/v1/exercises/e1/video/upload-url',
      'PUT r2.test/put',
      'PUT x/v1/exercises/e1/video',
    ]);
    expect(calls[0].data, {'size': 1000});
    expect(calls[1].headers.containsKey('X-App-Version'), isFalse);
    expect(calls[1].headers.containsKey('Authorization'), isFalse);
    expect(calls[1].contentType, 'video/mp4');
    expect(calls[2].data, {'key': 'videos/e1/abc'});
    expect(touched, ['exercises']);
  });

  test('uploadExerciseVideo: over 60 MB rejected before any request', () async {
    await expectLater(
      api.uploadExerciseVideo('e1', Uint8List(Exercise.maxVideoBytes + 1)),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'video_too_large')),
    );
    expect(adapter.calls, isEmpty);
    expect(touched, isEmpty);
  });

  test('uploadExerciseVideo: missing slot fails and never confirms', () async {
    respond = (o) async => jsonBody({}, 200);
    await expectLater(
      api.uploadExerciseVideo('e1', Uint8List(10)),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'upload_slot_missing')),
    );
    expect(adapter.calls, hasLength(1));
    expect(touched, isEmpty);
  });

  test('uploadExerciseVideo: failed PUT does not confirm', () async {
    respond = (o) async {
      if (o.path.endsWith('/upload-url')) {
        return jsonBody({'key': 'videos/e1/abc', 'upload_url': 'https://r2.test/put'}, 200);
      }
      return ResponseBody.fromString('', 403);
    };
    await expectLater(api.uploadExerciseVideo('e1', Uint8List(10)), throwsA(isA<ApiException>()));
    expect(adapter.calls.where((c) => c.method == 'PUT' && c.uri.host == 'x'), isEmpty);
    expect(touched, isEmpty);
  });

  test('exerciseVideoUrl: GET returns url', () async {
    respond = (o) async => jsonBody({'url': 'https://r2.test/get?sig=2'}, 200);
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
    expect(text('video_not_uploaded'), isNot('video_not_uploaded'));
  });

  group('muscle screen player', () {
    Exercise stored() => Exercise('R2 mashq', 'chest', '3 × 10', 'Sekin',
        id: 'v1', hasVideo: true, video: 'https://youtu.be/dQw4w9WgXcQ', createdAt: DateTime.now());

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

    testWidgets('hasVideo: loads signed url and shows stored player, not YouTube', (t) async {
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

    testWidgets('no hasVideo: YouTube cover path unchanged, no signed url requested', (t) async {
      var asked = 0;
      debugVideoUrl = (id) async {
        asked++;
        return 'x';
      };
      debugVideoThumb = (u) => const SizedBox();
      addTearDown(() => debugVideoThumb = null);
      await open(
        t,
        Exercise('YT mashq', 'chest', '3 × 10', 'Sekin',
            id: 'v2', video: 'https://youtu.be/dQw4w9WgXcQ', createdAt: DateTime.now()),
      );
      expect(asked, 0);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
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
