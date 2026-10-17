import 'dart:typed_data';

import '../../models/exercises.dart';
import '../../models/models.dart';
import 'api_error.dart';
import 'api_service.dart';
import 'json_helpers.dart';

class CatalogApi extends ApiService {
  CatalogApi(super.client, {super.bus, super.activity});

  static const _rare = Duration(minutes: 5);
  static const _plan = Duration(seconds: 60);

  Stream<List<Food>> foods() => poll(() async {
        final rows = await client.getList('/v1/foods');
        return jsonMaps(rows).map(Food.fromJson).toList();
      }, _rare, {'foods'});

  Future<void> saveFood(Food f) {
    if (f.id.isEmpty) return write('POST', '/v1/foods', f.toMap(), ['foods']);
    return write('PUT', '/v1/foods/${f.id}', f.toMap(), ['foods']);
  }

  Future<void> deleteFood(String id) => write('DELETE', '/v1/foods/$id', null, ['foods']);

  Future<Food> uploadFoodImage(
    String id,
    Uint8List bytes, {
    String contentType = 'image/jpeg',
    void Function(int sent, int total)? onProgress,
  }) async {
    final key = await uploadImage(
      '/v1/foods/$id/image/upload-url',
      bytes,
      contentType: contentType,
      onProgress: onProgress,
    );
    final saved = await bus.after(
      client.request<Map<String, dynamic>>('PUT', '/v1/foods/$id/image', data: {'key': key}),
      ['foods'],
    );
    return Food.fromJson(saved ?? const {});
  }

  Future<void> deleteFoodImage(String id) =>
      write('DELETE', '/v1/foods/$id/image', null, ['foods']);

  Stream<List<Exercise>> customExercises() => poll(() async {
        final rows = await client.getList('/v1/exercises');
        return [
          for (final row in jsonMaps(rows))
            if (Exercise.fromJson(row) case final e?) e,
        ];
      }, _rare, {'exercises'});

  Future<String> saveExercise(Exercise e) async {
    final body = {
      'name': e.name,
      'muscle': e.muscle,
      'sets': e.sets,
      'tip': e.tip,
      'also': e.also,
      'level': e.level,
    };
    if (e.id.isNotEmpty) {
      await write('PUT', '/v1/exercises/${e.id}', body, ['exercises']);
      return e.id;
    }
    final created = await bus.after(
      client
          .request<Map<String, dynamic>>('POST', '/v1/exercises', data: {...body, 'base': e.base}),
      ['exercises'],
    );
    return jsonString(created?['id']);
  }

  Future<void> deleteExercise(String id) =>
      write('DELETE', '/v1/exercises/$id', null, ['exercises']);

  Future<void> uploadExerciseVideo(
    String id, {
    required int size,
    required String contentType,
    Uint8List? bytes,
    Stream<List<int>> Function()? open,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (size > Exercise.maxVideoBytes) {
      throw const ApiException(code: 'video_too_large', message: '');
    }
    if (!Exercise.videoTypes.containsValue(contentType) || (bytes == null && open == null)) {
      throw const ApiException(code: 'video_type_unsupported', message: '');
    }
    final slot = await client.request<Map<String, dynamic>>(
      'POST',
      '/v1/exercises/$id/video/upload-url',
      data: {'size': size, 'content_type': contentType},
    );
    final key = jsonString(slot?['key']);
    final target = jsonString(slot?['upload_url']);
    if (key.isEmpty || target.isEmpty) {
      throw const ApiException(code: 'upload_slot_missing', message: '');
    }
    if (bytes != null) {
      await client.uploadBytes(target, bytes, contentType: contentType, onProgress: onProgress);
    } else {
      await client.uploadStream(target, open!(), size,
          contentType: contentType, onProgress: onProgress);
    }
    await write('PUT', '/v1/exercises/$id/video', {'key': key}, ['exercises']);
  }

  Future<ExerciseVideo> exerciseVideo(String id) async {
    final res = await client.getJson('/v1/exercises/$id/video');
    return ExerciseVideo(jsonString(res['status']), jsonString(res['url']));
  }

  Future<String> exerciseVideoUrl(String id) async => (await exerciseVideo(id)).url;

  Future<String> waitVideoReady(
    String id, {
    bool Function()? cancelled,
    Duration interval = const Duration(seconds: 3),
    Duration timeout = const Duration(minutes: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      if (cancelled?.call() ?? false) return 'processing';
      try {
        final status = (await exerciseVideo(id)).status;
        if (status == 'ready' || status == '' || status == 'failed') {
          bus.touchAll(['exercises']);
          return status == 'failed' ? 'failed' : 'ready';
        }
      } on ApiException catch (e) {
        if (!e.isNetwork && (e.status ?? 0) < 500) rethrow;
      }
      if (!DateTime.now().isBefore(deadline)) return 'failed';
      await Future<void>.delayed(interval);
    }
  }

  Future<void> deleteExerciseVideo(String id) =>
      write('DELETE', '/v1/exercises/$id/video', null, ['exercises']);

  Future<void> setProgram(String uid, String muscle, List<String> keys) async {
    final current = await client.getJson('/v1/users/$uid');
    final program = <String, dynamic>{
      for (final e in ((current['program'] as Map?) ?? const {}).entries) '${e.key}': e.value,
    };
    if (keys.isEmpty) {
      program.remove(muscle);
    } else {
      program[muscle] = keys;
    }
    return write('PATCH', '/v1/users/$uid', {'program': program}, ['users', 'user:$uid']);
  }

  Stream<List<Plan>> plans() => poll(() async {
        final rows = await client.getList('/v1/plans');
        return jsonMaps(rows).map(Plan.fromJson).toList();
      }, _rare, {'plans'});

  Stream<Plan?> plan(String id) => poll(() async {
        try {
          return Plan.fromJson(await client.getJson('/v1/plans/$id'));
        } on ApiException catch (e) {
          if (e.status == 404) return null;
          rethrow;
        }
      }, _plan, {'plans', 'plan:$id'});

  Future<String> savePlan(Plan p) async {
    if (p.id.isEmpty) {
      final created = await client.request<Map<String, dynamic>>(
        'POST',
        '/v1/plans',
        data: p.toMap(),
      );
      bus.touch('plans');
      return jsonString(created?['id']);
    }
    await write('PUT', '/v1/plans/${p.id}', p.toMap(), ['plans', 'plan:${p.id}']);
    return p.id;
  }

  Future<void> deletePlan(String id) =>
      write('DELETE', '/v1/plans/$id', null, ['plans', 'plan:$id']);
}
