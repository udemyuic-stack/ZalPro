import '../../models/exercise_set.dart';
import 'api_service.dart';
import 'json_helpers.dart';

class ExerciseSetApi extends ApiService {
  ExerciseSetApi(super.client, {super.bus, super.activity});

  List<ExerciseSet> _parse(Map<String, dynamic> row) =>
      jsonMaps(row['sets']).map(ExerciseSet.fromJson).toList();

  String _base(String uid) => '/v1/users/$uid/exercise-sets';

  Future<List<ExerciseSet>> sets(String uid, String day, String exerciseKey) async =>
      _parse(await client.getJson('${_base(uid)}/$day/${Uri.encodeComponent(exerciseKey)}'));

  Future<List<ExerciseSet>> previous(String uid, String exerciseKey, String before) async =>
      _parse(await client.getJson(
        '${_base(uid)}/${Uri.encodeComponent(exerciseKey)}/previous',
        query: {'before': before},
      ));

  Future<void> save(String uid, String day, String exerciseKey, List<ExerciseSet> sets) =>
      write(
        'PUT',
        '${_base(uid)}/$day/${Uri.encodeComponent(exerciseKey)}',
        {'sets': [for (final s in sets) s.toJson()]},
        const [],
      );
}
