import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/services/chat_audio.dart';
import 'package:kotta_qani_diet/services/voice_recorder.dart';
import 'package:kotta_qani_diet/widgets/chat_attach_sheet.dart';
import 'package:kotta_qani_diet/widgets/chat_audio_bubble.dart';
import 'package:kotta_qani_diet/widgets/voice_record_sheet.dart';

class FakeRecorder implements VoiceRecorder {
  FakeRecorder({this.allowed = true});
  final bool allowed;
  Duration time = Duration.zero;
  bool cancelled = false;
  bool stopped = false;
  bool disposed = false;

  @override
  Duration get elapsed => time;

  @override
  Future<bool> start() async => allowed;

  @override
  Future<VoiceClip?> stop() async {
    stopped = true;
    return VoiceClip(path: '/tmp/none.m4a', durationMs: time.inMilliseconds, size: 1234);
  }

  @override
  Future<void> cancel() async => cancelled = true;

  @override
  Future<void> dispose() async => disposed = true;
}

class FakeEngine implements AudioEngine {
  final positionCtl = StreamController<Duration>.broadcast();
  final playingCtl = StreamController<bool>.broadcast();
  final completedCtl = StreamController<void>.broadcast();
  final log = <String>[];
  bool failOpen = false;

  @override
  Stream<Duration> get position => positionCtl.stream;
  @override
  Stream<bool> get playing => playingCtl.stream;
  @override
  Stream<void> get completed => completedCtl.stream;

  @override
  Future<void> open(String url) async {
    if (failOpen) throw Exception('x');
    log.add('open $url');
  }

  @override
  void play() {
    log.add('play');
    playingCtl.add(true);
  }

  @override
  Future<void> pause() async {
    log.add('pause');
    playingCtl.add(false);
  }

  @override
  Future<void> seekToStart() async => log.add('seek0');

  @override
  Future<void> stop() async {
    log.add('stop');
    playingCtl.add(false);
  }

  @override
  Future<void> dispose() async {}
}

ChatMessage audio(String url, int ms) => ChatMessage(
      'u1',
      '',
      DateTime.utc(2026, 5, 10),
      mediaKind: 'audio',
      mediaStatus: 'ready',
      mediaUrl: url,
      mediaDurationMs: ms,
    );

Future<void> openSheet(WidgetTester tester, FakeRecorder rec) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showVoiceRecordSheet(context, recorderBuilder: () => rec),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  test('voiceRecordSupported only on Android app', () {
    expect(voiceRecordSupported(isWeb: false, platform: TargetPlatform.android), true);
    expect(voiceRecordSupported(isWeb: true, platform: TargetPlatform.android), false);
    expect(voiceRecordSupported(isWeb: false, platform: TargetPlatform.iOS), false);
  });

  test('formatVoiceTime', () {
    expect(formatVoiceTime(const Duration(seconds: 4)), '0:04');
    expect(formatVoiceTime(const Duration(seconds: 125)), '2:05');
  });

  group('VoiceRecordSheet', () {
    testWidgets('cancel discards the recording', (tester) async {
      final rec = FakeRecorder();
      await openSheet(tester, rec);
      expect(find.byKey(const Key('voice-timer')), findsOneWidget);
      await tester.tap(find.byKey(const Key('voice-cancel')));
      await tester.pumpAndSettle();
      expect(rec.cancelled, true);
      expect(find.byKey(const Key('voice-timer')), findsNothing);
    });

    testWidgets('send stops and returns the clip', (tester) async {
      final rec = FakeRecorder();
      await openSheet(tester, rec);
      rec.time = const Duration(seconds: 3);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('0:03'), findsOneWidget);
      await tester.tap(find.byKey(const Key('voice-send')));
      await tester.pumpAndSettle();
      expect(rec.stopped, true);
      expect(rec.cancelled, false);
      expect(find.byKey(const Key('voice-timer')), findsNothing);
    });

    testWidgets('clip shorter than a second is not sent', (tester) async {
      final rec = FakeRecorder();
      await openSheet(tester, rec);
      rec.time = const Duration(milliseconds: 400);
      await tester.tap(find.byKey(const Key('voice-send')));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Yozuv juda qisqa'), findsOneWidget);
      expect(find.byKey(const Key('voice-timer')), findsNothing);
    });

    testWidgets('reaching 5 minutes stops and offers sending', (tester) async {
      final rec = FakeRecorder();
      await openSheet(tester, rec);
      rec.time = const Duration(milliseconds: ChatMessage.maxAudioMs);
      await tester.pump(const Duration(milliseconds: 300));
      expect(rec.stopped, true);
      expect(find.text('Yozuv 5 daqiqaga yetdi'), findsOneWidget);
      expect(find.text('5:00'), findsOneWidget);
      expect(find.byKey(const Key('voice-send')), findsOneWidget);
    });

    testWidgets('denied permission shows guidance, not an error', (tester) async {
      final rec = FakeRecorder(allowed: false);
      await openSheet(tester, rec);
      expect(find.byKey(const Key('voice-denied')), findsOneWidget);
      expect(find.byKey(const Key('voice-send')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('voice-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('voice-denied')), findsNothing);
    });
  });

  group('attach sheet', () {
    Future<void> open(WidgetTester tester, {required bool voice}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => pickChatAttachment(context, voiceSupported: voice),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the audio row when voice is supported', (tester) async {
      await open(tester, voice: true);
      expect(find.text('Audio — ovoz yozish'), findsOneWidget);
    });

    testWidgets('hides the audio row when voice is not supported', (tester) async {
      await open(tester, voice: false);
      expect(find.text('Video'), findsOneWidget);
      expect(find.text('Audio — ovoz yozish'), findsNothing);
    });

    testWidgets('picking audio records and returns an audio attachment', (tester) async {
      final rec = FakeRecorder();
      ChatAttachment? picked;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked = await pickChatAttachment(
                context,
                voiceSupported: true,
                recorderBuilder: () => rec,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Audio — ovoz yozish'));
      await tester.pumpAndSettle();
      rec.time = const Duration(seconds: 2);
      await tester.tap(find.byKey(const Key('voice-send')));
      await tester.pumpAndSettle();
      expect(picked?.isAudio, true);
      expect(picked?.contentType, 'audio/mp4');
      expect(picked?.durationMs, 2000);
      expect(picked?.size, 1234);
    });
  });

  group('ChatAudioBubble', () {
    late FakeEngine engine;
    late ChatAudioController controller;

    setUp(() {
      engine = FakeEngine();
      controller = ChatAudioController(engine);
    });

    tearDown(() => controller.dispose());

    Future<void> pump(WidgetTester tester, List<ChatMessage> messages) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                child: Column(children: [
                  for (final m in messages) ChatAudioBubble(message: m, controller: controller),
                ]),
              ),
            ),
          ),
        );

    testWidgets('shows duration, plays and pauses', (tester) async {
      await pump(tester, [audio('http://r2/a', 12000)]);
      expect(find.text('0:12'), findsOneWidget);
      await tester.tap(find.byKey(const Key('audio-play')));
      await tester.pump();
      expect(engine.log, ['open http://r2/a', 'play']);
      expect(find.byIcon(Icons.pause), findsOneWidget);
      engine.positionCtl.add(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('0:03 / 0:12'), findsOneWidget);
      await tester.tap(find.byKey(const Key('audio-play')));
      await tester.pump();
      expect(engine.log.last, 'pause');
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('starting another audio replaces the first', (tester) async {
      await pump(tester, [audio('http://r2/a', 5000), audio('http://r2/b', 7000)]);
      final buttons = find.byKey(const Key('audio-play'));
      await tester.tap(buttons.at(0));
      await tester.pump();
      await tester.tap(buttons.at(1));
      await tester.pump();
      expect(controller.url, 'http://r2/b');
      expect(controller.isPlaying('http://r2/a'), false);
      expect(controller.isPlaying('http://r2/b'), true);
      expect(engine.log.where((e) => e.startsWith('open')).length, 2);
    });

    testWidgets('open failure shows the error text', (tester) async {
      engine.failOpen = true;
      await pump(tester, [audio('http://r2/a', 5000)]);
      await tester.tap(find.byKey(const Key('audio-play')));
      await tester.pump();
      expect(find.text("Ijro bo'lmadi"), findsOneWidget);
    });

    testWidgets('completion resets to the play state', (tester) async {
      await pump(tester, [audio('http://r2/a', 5000)]);
      await tester.tap(find.byKey(const Key('audio-play')));
      await tester.pump();
      engine.completedCtl.add(null);
      engine.playingCtl.add(false);
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.text('0:05'), findsOneWidget);
    });

    testWidgets('fits 360 px without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, [audio('http://r2/a', 300000)]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('stop() halts playback', (tester) async {
      await pump(tester, [audio('http://r2/a', 5000)]);
      await tester.tap(find.byKey(const Key('audio-play')));
      await tester.pump();
      await controller.stop();
      await tester.pump();
      expect(engine.log.last, 'stop');
      expect(controller.url, isNull);
    });
  });
}
