import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/models.dart';

void main() {
  test('full payload', () {
    final u = AppUser.fromJson({
      'id': 'u1',
      'name': 'Ali',
      'phone': '998901234567',
      'role': 'admin',
      'gender': 'female',
      'age': 30,
      'height': 170.5,
      'weight': 65.2,
      'activity': 1.55,
      'metabolism': 'fast',
      'goal': 'lose',
      'plan_id': 'p1',
      'plan_assigned_at': '2026-01-02T03:04:05+00:00',
      'trainer_id': 't1',
      'gym_id': 'g1',
      'gym_days': [1, 3, 5],
      'home_workout_date': '2026-02-03',
      'subscription_expires_at': '2026-03-04T00:00:00Z',
      'last_weigh_in': '2026-04-05T10:00:00Z',
      'program': {
        'chest': ['a', 'b'],
        'bad': 'x',
      },
      'created_at': '2026-01-01T00:00:00Z',
    });
    expect(u.id, 'u1');
    expect(u.email, '');
    expect(u.role, 'admin');
    expect(u.gender, 'female');
    expect(u.age, 30);
    expect(u.height, 170.5);
    expect(u.weight, 65.2);
    expect(u.activity, 1.55);
    expect(u.metabolism, 'fast');
    expect(u.goal, 'lose');
    expect(u.planId, 'p1');
    expect(u.planAssignedAt, DateTime.parse('2026-01-02T03:04:05+00:00').toLocal());
    expect(u.trainerId, 't1');
    expect(u.gymId, 'g1');
    expect(u.gymDays, [1, 3, 5]);
    expect(u.homeWorkoutDate, '2026-02-03');
    expect(u.subscriptionExpiresAt, DateTime.parse('2026-03-04T00:00:00Z').toLocal());
    expect(u.lastWeighIn, DateTime.parse('2026-04-05T10:00:00Z').toLocal());
    expect(u.program, {
      'chest': ['a', 'b'],
    });
    expect(u.copyWith(age: 31).lastWeighIn, u.lastWeighIn);
  });

  test('minimal payload with nulls', () {
    final u = AppUser.fromJson({
      'id': 'u2',
      'name': 'Vali',
      'phone': '998900000000',
      'role': 'user',
      'gender': null,
      'age': null,
      'height': null,
      'weight': 70,
      'activity': null,
      'metabolism': null,
      'goal': null,
      'plan_id': null,
      'plan_assigned_at': null,
      'trainer_id': null,
      'gym_id': null,
      'gym_days': <int>[],
      'home_workout_date': null,
      'subscription_expires_at': null,
      'last_weigh_in': null,
      'program': <String, dynamic>{},
    });
    expect(u.gender, 'male');
    expect(u.age, 0);
    expect(u.height, 0.0);
    expect(u.activity, 1.375);
    expect(u.metabolism, '');
    expect(u.goal, '');
    expect(u.planId, isNull);
    expect(u.planAssignedAt, isNull);
    expect(u.trainerId, isNull);
    expect(u.gymId, isNull);
    expect(u.gymDays, isEmpty);
    expect(u.homeWorkoutDate, isNull);
    expect(u.subscriptionExpiresAt, isNull);
    expect(u.lastWeighIn, isNull);
    expect(u.program, isEmpty);
  });

  test('missing optional keys do not throw', () {
    final u = AppUser.fromJson({'id': 'u3'});
    expect(u.name, '');
    expect(u.role, 'user');
    expect(u.weight, 0.0);
    expect(u.gymDays, isEmpty);
  });

  test('int values become double', () {
    final u = AppUser.fromJson({
      'id': 'u4',
      'height': 180,
      'weight': 80,
      'activity': 2,
    });
    expect(u.height, 180.0);
    expect(u.weight, 80.0);
    expect(u.activity, 2.0);
    expect(u.height, isA<double>());
  });

  test('unknown role passes through', () {
    final u = AppUser.fromJson({'id': 'u5', 'role': 'superhero'});
    expect(u.role, 'superhero');
    expect(u.isAdmin, isFalse);
  });
}
