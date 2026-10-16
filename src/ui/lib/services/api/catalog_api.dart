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

  Stream<List<Exercise>> customExercises() => poll(() async {
        final rows = await client.getList('/v1/exercises');
        return [
          for (final row in jsonMaps(rows))
            if (Exercise.fromJson(row) case final e?) e,
        ];
      }, _rare, {'exercises'});

  Future<void> saveExercise(Exercise e) {
    final body = {
      'name': e.name,
      'muscle': e.muscle,
      'sets': e.sets,
      'tip': e.tip,
      'also': e.also,
      'video': e.video,
      'level': e.level,
    };
    if (e.id.isNotEmpty) return write('PUT', '/v1/exercises/${e.id}', body, ['exercises']);
    return write('POST', '/v1/exercises', {...body, 'base': e.base}, ['exercises']);
  }

  Future<void> deleteExercise(String id) =>
      write('DELETE', '/v1/exercises/$id', null, ['exercises']);

  Future<void> uploadExerciseVideo(
    String id,
    Uint8List bytes, {
    void Function(int sent, int total)? onProgress,
  }) async {
    if (bytes.length > Exercise.maxVideoBytes) {
      throw const ApiException(code: 'video_too_large', message: '');
    }
    final slot = await client.request<Map<String, dynamic>>(
      'POST',
      '/v1/exercises/$id/video/upload-url',
      data: {'size': bytes.length},
    );
    final key = jsonString(slot?['key']);
    final target = jsonString(slot?['upload_url']);
    if (key.isEmpty || target.isEmpty) {
      throw const ApiException(code: 'upload_slot_missing', message: '');
    }
    await client.uploadBytes(target, bytes, contentType: 'video/mp4', onProgress: onProgress);
    await write('PUT', '/v1/exercises/$id/video', {'key': key}, ['exercises']);
  }

  Future<String> exerciseVideoUrl(String id) async {
    final res = await client.getJson('/v1/exercises/$id/video');
    return jsonString(res['url']);
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
