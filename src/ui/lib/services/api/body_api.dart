import 'dart:typed_data';

import '../../models/models.dart';
import '../../models/photo.dart';
import 'api_error.dart';
import 'api_service.dart';
import 'json_helpers.dart';
import 'poll_stream.dart';

class BodyApi extends ApiService {
  BodyApi(super.client, {super.bus, super.activity, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  static const _weights = Duration(seconds: 60);
  static const _photos = Duration(minutes: 4);
  static const _urlLife = Duration(minutes: 9);

  final DateTime Function() _now;
  final _weightStreams = <String, SharedStream<List<WeightLog>>>{};

  Stream<List<WeightLog>> weights(String uid) {
    return _weightStreams
        .putIfAbsent(
          uid,
          () => SharedStream(() => poll(() async {
                final rows = await client.getList('/v1/users/$uid/weights');
                final logs = [for (final row in jsonMaps(rows)) WeightLog.fromJson(row)];
                return logs..sort((a, b) => a.date.compareTo(b.date));
              }, _weights, {'weights:$uid'})),
        )
        .stream;
  }

  Future<void> addWeight(String uid, double w) => write('POST', '/v1/users/$uid/weights', {
        'weight': w
      }, [
        'weights:$uid',
        'user:$uid',
        'users',
      ]);

  Stream<List<ProgressPhoto>> photos(String uid) {
    return poll(() async {
      final rows = await client.getList('/v1/users/$uid/photos');
      final expires = _now().add(_urlLife);
      final list = [
        for (final row in jsonMaps(rows)) ProgressPhoto.fromJson(row, urlExpiresAt: expires),
      ];
      return list..sort((a, b) => _at(a).compareTo(_at(b)));
    }, _photos, {'photos:$uid'}, key: 'photos:$uid');
  }

  DateTime _at(ProgressPhoto p) => p.takenAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  Future<void> addPhoto(String uid, Uint8List bytes, double weight) async {
    final slot = await client.request<Map<String, dynamic>>(
      'POST',
      '/v1/users/$uid/photos/upload-url',
      data: {'weight': weight, 'size': bytes.length},
    );
    final id = jsonString(slot?['photo_id']);
    final target = jsonString(slot?['upload_url']);
    if (target.isEmpty) {
      throw const ApiException(code: 'upload_slot_missing', message: '');
    }
    try {
      await client.uploadBytes(target, bytes);
    } catch (_) {
      try {
        await client.request<void>('DELETE', '/v1/users/$uid/photos/$id');
      } catch (_) {}
      rethrow;
    }
    bus.touch('photos:$uid');
  }

  Future<void> deletePhoto(String uid, String id) =>
      write('DELETE', '/v1/users/$uid/photos/$id', null, ['photos:$uid']);
}
