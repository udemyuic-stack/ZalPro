import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/tr.dart';
import '../models/exercises.dart';
import '../models/models.dart';
import '../services/api/api_error.dart';
import '../services/voice_recorder.dart';
import '../theme.dart';
import 'image_pick.dart';
import 'ui.dart';
import 'voice_record_sheet.dart';

enum ChatAttachChoice { gallery, camera, video, voice }

class ChatAttachment {
  final String kind;
  final String contentType;
  final int size;
  final Uint8List? bytes;
  final XFile? file;
  final int durationMs;
  const ChatAttachment({
    required this.kind,
    required this.contentType,
    required this.size,
    this.bytes,
    this.file,
    this.durationMs = 0,
  });

  bool get isVideo => kind == ChatMessage.mediaVideo;
  bool get isAudio => kind == ChatMessage.mediaAudio;
}

Future<ChatAttachment?> pickChatAttachment(
  BuildContext context, {
  VoiceRecorder Function()? recorderBuilder,
  bool? voiceSupported,
}) async {
  final voice =
      voiceSupported ?? voiceRecordSupported(isWeb: kIsWeb, platform: defaultTargetPlatform);
  final choice = await showSheet<ChatAttachChoice>(context, _ChatAttachSheet(voice: voice));
  if (choice == null || !context.mounted) return null;
  try {
    switch (choice) {
      case ChatAttachChoice.gallery:
        return _image(await pickGalleryImage());
      case ChatAttachChoice.camera:
        return _image(await pickCameraImage());
      case ChatAttachChoice.video:
        return await _video(context);
      case ChatAttachChoice.voice:
        return await pickChatVoice(context, recorderBuilder: recorderBuilder);
    }
  } catch (e) {
    if (context.mounted) showSnack(context, trf("Bo'lmadi: {0}", [apiErrorText(e)]));
    return null;
  }
}

ChatAttachment? _image(PickedImage? picked) {
  if (picked == null) return null;
  return ChatAttachment(
    kind: ChatMessage.mediaImage,
    contentType: picked.contentType,
    size: picked.bytes.length,
    bytes: picked.bytes,
  );
}

Future<ChatAttachment?> pickChatVoice(
  BuildContext context, {
  VoiceRecorder Function()? recorderBuilder,
}) async {
  final clip = await showVoiceRecordSheet(context, recorderBuilder: recorderBuilder);
  if (clip == null) return null;
  return chatVoiceAttachment(clip);
}

ChatAttachment chatVoiceAttachment(VoiceClip clip) => ChatAttachment(
      kind: ChatMessage.mediaAudio,
      contentType: ChatMessage.audioContentType,
      size: clip.size,
      file: XFile(clip.path),
      durationMs: clip.durationMs,
    );

Future<ChatAttachment?> _video(BuildContext context) async {
  final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
  if (file == null) return null;
  final type =
      Exercise.videoContentType(file.name, file.mimeType) ?? Exercise.videoContentType(file.path);
  if (type == null) {
    if (context.mounted) showSnack(context, tr("Video turi qo'llanmaydi (mp4, mov, webm)"));
    return null;
  }
  final size = await file.length();
  if (size > ChatMessage.maxVideoBytes) {
    if (context.mounted) showSnack(context, tr('Video 50 MB dan katta'));
    return null;
  }
  return ChatAttachment(
    kind: ChatMessage.mediaVideo,
    contentType: type,
    size: size,
    bytes: kIsWeb ? await file.readAsBytes() : null,
    file: file,
  );
}

class _ChatAttachSheet extends StatelessWidget {
  final bool voice;
  const _ChatAttachSheet({required this.voice});

  @override
  Widget build(BuildContext context) {
    Widget option(IconData icon, String label, ChatAttachChoice value) => ListTile(
          minVerticalPadding: 0,
          contentPadding: EdgeInsets.zero,
          minTileHeight: kTouchTarget,
          leading: Icon(icon),
          title: Text(label),
          onTap: () => Navigator.pop(context, value),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('Yuborish'), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpace.sm),
        option(Icons.photo_library_outlined, tr('Rasm — galereya'), ChatAttachChoice.gallery),
        option(Icons.photo_camera_outlined, tr('Rasm — kamera'), ChatAttachChoice.camera),
        option(Icons.videocam_outlined, tr('Video'), ChatAttachChoice.video),
        if (voice) option(Icons.mic_none, tr('Audio — ovoz yozish'), ChatAttachChoice.voice),
      ],
    );
  }
}
