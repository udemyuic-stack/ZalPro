import '../../models/models.dart';
import 'api_service.dart';
import 'api_error.dart';
import 'json_helpers.dart';
import 'poll_stream.dart';

class UsersApi extends ApiService {
  UsersApi(super.client, {super.bus, super.activity, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  static const _page = 500;
  static const _profile = Duration(seconds: 30);
  static const _lists = Duration(seconds: 60);
  static const _rare = Duration(minutes: 5);

  final DateTime Function() _now;
  final _clientStreams = <String, SharedStream<List<AppUser>>>{};

  List<String> _userTags(String uid) => ['users', 'user:$uid'];

  Future<AppUser?> _fetchUser(String uid) async {
    try {
      return AppUser.fromJson(await client.getJson('/v1/users/$uid'));
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<List<AppUser>> _list(Map<String, dynamic> query) async {
    final all = <AppUser>[];
    for (var offset = 0;; offset += _page) {
      final rows = await client.getList(
        '/v1/users',
        query: {...query, 'limit': _page, 'offset': offset},
      );
      all.addAll(jsonMaps(rows).map(AppUser.fromJson));
      if (rows.length < _page) return all;
    }
  }

  Future<AppUser?> _fetchMe(String uid) async {
    if (client.userId != uid) return null;
    try {
      return AppUser.fromJson(await client.getJson('/v1/users/me'));
    } on ApiException catch (e) {
      if (e.status != 401 && e.status != 404) rethrow;
      if (client.userId == uid) await client.clearSession();
      return null;
    }
  }

  Stream<AppUser?> me(String uid) =>
      poll(() => _fetchMe(uid), _profile, {'user:$uid'}, key: 'me:$uid');

  Stream<AppUser?> user(String uid) =>
      poll(() => _fetchUser(uid), _profile, {'user:$uid'}, key: 'user:$uid');

  Stream<List<AppUser>> _sharedClients(String key, Map<String, dynamic> query) => _clientStreams
      .putIfAbsent(key, () => SharedStream(() => poll(() => _list(query), _lists, {'users'})))
      .stream;

  Stream<List<AppUser>> clients() => _sharedClients('', {'role': 'user'});

  Stream<List<AppUser>> clientsOf(String trainerId) =>
      _sharedClients(trainerId, {'role': 'user', 'trainer_id': trainerId});

  Stream<List<AppUser>> staff() => poll(
        () => _list({
          'role': ['admin', 'owner', 'barmen'],
        }),
        _lists,
        {'users'},
        key: 'staff',
      );

  Stream<List<AppUser>> trainers() =>
      poll(() => _list({'role': 'admin'}), _lists, {'users'}, key: 'trainers');

  Stream<List<Gym>> gyms() => poll(() async {
        final rows = await client.getList('/v1/gyms');
        return jsonMaps(rows).map(Gym.fromJson).toList()..sort((a, b) => a.name.compareTo(b.name));
      }, _rare, {'gyms'}, key: 'gyms');

  Future<String> saveGym(Gym g) async {
    if (g.id.isEmpty) {
      final created =
          await client.request<Map<String, dynamic>>('POST', '/v1/gyms', data: g.toMap());
      bus.touch('gyms');
      return jsonString(created?['id']);
    }
    await write('PUT', '/v1/gyms/${g.id}', g.toMap(), ['gyms']);
    return g.id;
  }

  Future<void> deleteGym(String id) =>
      write('DELETE', '/v1/gyms/$id', null, ['gyms', 'users', 'trainers']);

  Future<void> setUserGym(String uid, String? gymId) =>
      write('PUT', '/v1/users/$uid/gym', {'gym_id': gymId}, [..._userTags(uid), 'trainers']);

  Future<String> createStaff({
    required String name,
    required String phone,
    required String password,
    required String role,
    String? gymId,
  }) async {
    final created = await client.request<Map<String, dynamic>>('POST', '/v1/users', data: {
      'name': name.trim(),
      'phone': phone,
      'password': password,
      'role': role,
      'gym_id': gymId,
    });
    bus.touchAll(['users', 'trainers']);
    return jsonString(created?['id']);
  }

  Future<void> updateUser(AppUser u, {AppUser? before}) async {
    final body = <String, dynamic>{
      'name': u.name,
      'gender': u.gender,
      'age': u.age,
      'height': u.height,
      'activity': u.activity,
      'metabolism': u.metabolism,
      'goal': u.goal,
      if (before != null && before.weight == 0 && u.weight > 0) 'weight': u.weight,
    };
    await client.request<void>('PATCH', '/v1/users/${u.id}', data: body);
    if (u.trainerId != null && u.trainerId != before?.trainerId) {
      await client.request<void>(
        'PUT',
        '/v1/users/${u.id}/trainer',
        data: {'trainer_id': u.trainerId},
      );
    }
    bus.touchAll(_userTags(u.id));
  }

  Future<void> assignPlan(String uid, String? planId) => write(
        'PATCH',
        '/v1/users/$uid',
        {
          'plan_id': planId,
          'plan_assigned_at': planId == null ? null : _now().toUtc().toIso8601String(),
        },
        _userTags(uid),
      );

  Future<void> setGoal(String uid, String goal) =>
      write('PATCH', '/v1/users/$uid', {'goal': goal}, _userTags(uid));

  Future<void> assignTrainer(String uid, String? trainerId) =>
      write('PUT', '/v1/users/$uid/trainer', {'trainer_id': trainerId}, _userTags(uid));

  Future<void> setLeaderboardVisible(String uid, bool visible) => write(
        'PUT',
        '/v1/users/me/leaderboard',
        {'visible': visible},
        [..._userTags(uid), 'leaderboard'],
      );

  Future<void> setGameEnabled(String uid, bool enabled) => write(
        'PUT',
        '/v1/users/me/game',
        {'enabled': enabled},
        [..._userTags(uid), 'leaderboard', 'game'],
      );

  Future<void> setGymDays(String uid, List<int> days) => write(
        'PATCH',
        '/v1/users/$uid',
        {
          'gym_days': [...days]..sort()
        },
        _userTags(uid),
      );

  Future<void> setHomeWorkout(String uid, String? day) =>
      write('PATCH', '/v1/users/$uid', {'home_workout_date': day}, _userTags(uid));

  Future<List<TrainerInfo>> _fetchTrainers() async {
    final rows = await client.getList('/v1/trainers');
    return jsonMaps(rows).map(TrainerInfo.fromJson).toList();
  }

  Stream<List<TrainerInfo>> trainerDirectory() => poll(() async {
        final all = await _fetchTrainers();
        return all.where((t) => t.accepting).toList()..sort((a, b) => a.name.compareTo(b.name));
      }, _rare, {'trainers'}, key: 'trainerDirectory');

  Stream<TrainerInfo?> trainerProfile(String uid) => poll(() async {
        final all = await _fetchTrainers();
        return all.where((t) => t.id == uid).firstOrNull;
      }, _rare, {'trainers'}, key: 'trainerProfile:$uid');

  Future<void> saveTrainerProfile(TrainerInfo t) async {
    final body = {
      if (t.name.trim().isNotEmpty) 'name': t.name.trim(),
      'bio': t.bio,
      'accepting': t.accepting,
    };
    try {
      await client.request<void>('PUT', '/v1/trainers/${t.id}', data: body);
    } on ApiException catch (e) {
      if (e.status != 404) rethrow;
      await client.request<void>('POST', '/v1/trainers/${t.id}', data: body);
    }
    bus.touchAll(['trainers', 'user:${t.id}']);
  }

  Stream<Map<String, TrainerRating>> ratings() => poll(() async {
        final rows = await client.getList('/v1/ratings');
        return {
          for (final r in jsonMaps(rows)) jsonString(r['trainer_id']): TrainerRating.fromJson(r),
        };
      }, _rare, {'ratings'}, key: 'ratings');

  Future<void> saveRating(String trainerId, int stars, String comment) => write(
        'PUT',
        '/v1/ratings/$trainerId',
        {'stars': stars, 'comment': comment},
        ['ratings'],
      );

  Future<void> setRole(String uid, String role) =>
      write('PUT', '/v1/users/$uid/role', {'role': role}, [..._userTags(uid), 'trainers']);

  Future<void> deleteUser(String uid) =>
      write('DELETE', '/v1/users/$uid', null, [..._userTags(uid), 'trainers']);
}
