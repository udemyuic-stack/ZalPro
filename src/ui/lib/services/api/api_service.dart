import 'dart:typed_data';

import '../../l10n/tr.dart';
import 'api_client.dart';
import 'api_error.dart';
import 'json_helpers.dart';
import 'poll_stream.dart';

abstract class ApiService {
  ApiService(this.client, {ChangeBus? bus, PollActivity? activity})
      : bus = bus ?? changeBus,
        activity = activity ?? pollActivity;

  final ApiClient client;
  final ChangeBus bus;
  final PollActivity activity;

  Stream<T> poll<T>(Future<T> Function() fetch, Duration every, Set<String> tags) =>
      pollStream<T>(fetch, every: every, tags: tags, bus: bus, activity: activity);

  Future<void> write(String method, String path, Object? body, Iterable<String> tags) =>
      bus.after(client.request<void>(method, path, data: body), tags);

  static const maxImageBytes = 5 * 1024 * 1024;

  Future<String> uploadImage(
    String slotPath,
    Uint8List bytes, {
    String contentType = 'image/jpeg',
    void Function(int sent, int total)? onProgress,
  }) async {
    if (bytes.length > maxImageBytes) {
      throw ApiException(code: 'image_too_large', message: tr('Rasm 5 MB dan katta'));
    }
    final slot = await client.request<Map<String, dynamic>>(
      'POST',
      slotPath,
      data: {'size': bytes.length, 'content_type': contentType},
    );
    final key = jsonString(slot?['key']);
    final target = jsonString(slot?['upload_url']);
    if (key.isEmpty || target.isEmpty) {
      throw const ApiException(code: 'upload_slot_missing', message: '');
    }
    await client.uploadBytes(target, bytes, contentType: contentType, onProgress: onProgress);
    return key;
  }
}
