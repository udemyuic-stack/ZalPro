import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/widgets/chat_media_bubble.dart';

ChatMessage video(String status, [String url = '']) => ChatMessage(
      'u1',
      '',
      DateTime.utc(2026, 5, 10),
      mediaKind: 'video',
      mediaStatus: status,
      mediaUrl: url,
    );

Future<void> pump(WidgetTester tester, ChatMessage m) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: ChatMediaBubble(message: m)))),
    );

void main() {
  testWidgets('processing video shows the preparing label and a spinner', (tester) async {
    await pump(tester, video('processing'));
    expect(find.text('Video tayyorlanmoqda…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('failed video shows the failure label', (tester) async {
    await pump(tester, video('failed'));
    expect(find.text('Video yuborilmadi'), findsOneWidget);
  });

  testWidgets('ready video shows a play tile that opens the player', (tester) async {
    debugChatVideoPlayer = (url) => Text('player:$url');
    addTearDown(() => debugChatVideoPlayer = null);
    await pump(tester, video('ready', 'http://r2/v.mp4'));
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();
    expect(find.text('player:http://r2/v.mp4'), findsOneWidget);
  });
}
