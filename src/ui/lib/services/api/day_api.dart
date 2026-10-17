import '../../models/gym.dart';
import '../../models/models.dart';
import 'api_service.dart';
import 'json_helpers.dart';
import 'poll_stream.dart';

class DayApi extends ApiService {
  DayApi(super.client, {super.bus, super.activity});

  static const _every = Duration(seconds: 15);

  final _days = <String, SharedStream<Map<String, dynamic>>>{};

  static const feedbackDays = 7;

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _base(String uid, String day) => '/v1/users/$uid/days/$day';

  SharedStream<Map<String, dynamic>> _shared(String uid, String day) {
    return _days.putIfAbsent(
      '$uid|$day',
      () => SharedStream(
        () => poll(() => client.getJson(_base(uid, day)), _every, {'day:$uid:$day'}),
      ),
    );
  }

  Stream<Map<String, dynamic>> _day(String uid, String day) => _shared(uid, day).stream;

  Future<void> _mark(String method, String uid, String day, String suffix, Object? body) async {
    final updated = await client.request<Map<String, dynamic>>(
      method,
      '${_base(uid, day)}$suffix',
      data: body,
    );
    if (updated != null) _shared(uid, day).push(updated);
    bus.touch('day:$uid:$day');
  }

  Stream<Set<int>> doneMeals(String uid, String day) =>
      _day(uid, day).map((d) => jsonInts(d['done']).toSet());

  Future<void> toggleMeal(String uid, String day, int index, bool done) =>
      _mark('PUT', uid, day, '/meals/$index', {'done': done});

  Stream<List<ExtraFood>> extras(String uid, String day) => _day(uid, day).map(
        (d) => jsonMaps(d['extras']).map(ExtraFood.fromJson).toList()
          ..sort((a, b) => a.at.compareTo(b.at)),
      );

  Future<void> addExtra(String uid, String day, ExtraFood e) =>
      _mark('POST', uid, day, '/extras', e.toMap());

  Future<void> removeExtra(String uid, String day, ExtraFood e) =>
      _mark('DELETE', uid, day, '/extras/${e.at}', null);

  Stream<WorkoutProgress> workout(String uid, String day) =>
      _day(uid, day).map(WorkoutProgress.fromJson);

  Future<void> startWorkout(String uid, String day) =>
      _mark('PUT', uid, day, '/workout/start', null);

  Future<void> toggleExercise(String uid, String day, String key, bool done) =>
      _mark('PUT', uid, day, '/workout/exercises/${Uri.encodeComponent(key)}', {'done': done});

  Future<void> setFeedback(String uid, String day, int rating) =>
      _mark('PUT', uid, day, '/workout/feedback', {'rating': rating});

  Stream<Map<String, int>> feedbackWeek(String uid) => poll(() async {
        final today = DateTime.now();
        final from = DateTime(today.year, today.month, today.day - (feedbackDays - 1));
        final rows = await client.getList('/v1/users/$uid/days', query: {
          'from': _dayKey(from),
          'to': _dayKey(today),
        });
        return {
          for (final row in jsonMaps(rows))
            if (parseFeedback(row['feedback']) case final f?) jsonString(row['day']): f,
        };
      }, _every, {'feedback:$uid'});

  Stream<int> water(String uid, String day) => _day(uid, day).map((d) => jsonInt(d['water']));

  Future<void> setWater(String uid, String day, int glasses) =>
      _mark('PUT', uid, day, '/water', {'glasses': glasses});
}
