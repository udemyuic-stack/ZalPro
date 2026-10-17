import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/exercises.dart';
import 'package:kotta_qani_diet/models/gym.dart';

void main() {
  group('Exercise.fromJson', () {
    test('full payload', () {
      final e = Exercise.fromJson({
        'id': 'e1',
        'name': '  Shtanga  ',
        'muscle': 'chest',
        'sets': '4 x 10',
        'tip': 'Sekin',
        'also': ['triceps', 'chest', 'nope', 'shoulders'],
        'has_video': true,
        'created_at': '2026-01-02T03:04:05Z',
        'created_by': 'u1',
        'base': 'Otjimaniya',
        'level': 'pro',
      })!;
      expect(e.id, 'e1');
      expect(e.name, 'Shtanga');
      expect(e.muscle, 'chest');
      expect(e.sets, '4 x 10');
      expect(e.tip, 'Sekin');
      expect(e.also, ['triceps', 'shoulders']);
      expect(e.hasVideo, isTrue);
      expect(e.createdAt!.isAtSameMomentAs(DateTime.utc(2026, 1, 2, 3, 4, 5)), isTrue);
      expect(e.createdBy, 'u1');
      expect(e.base, 'Otjimaniya');
      expect(e.level, 'pro');
      expect(e.isCustom, isTrue);
      expect(e.isOverride, isTrue);
    });

    test('minimal payload and invalid input', () {
      final e = Exercise.fromJson({'id': 'e2', 'name': 'A', 'muscle': 'abs', 'level': 'x'})!;
      expect(e.sets, '');
      expect(e.tip, '');
      expect(e.also, isEmpty);
      expect(e.hasVideo, isFalse);
      expect(e.createdAt, isNull);
      expect(e.createdBy, '');
      expect(e.base, '');
      expect(e.level, '');
      expect(Exercise.fromJson({'id': 'e3', 'name': ' ', 'muscle': 'abs'}), isNull);
      expect(Exercise.fromJson({'id': 'e4', 'name': 'A', 'muscle': 'bad'}), isNull);
      expect(Exercise.fromJson({}), isNull);
    });
  });

  group('WorkoutProgress.fromJson', () {
    test('full payload', () {
      final w = WorkoutProgress.fromJson({
        'day': '2026-01-02',
        'gym_started': true,
        'gym_done': ['c:e1', 'Otjimaniya', 'c:e1'],
      });
      expect(w.started, isTrue);
      expect(w.done, {'c:e1', 'Otjimaniya'});
    });

    test('minimal payload', () {
      final w = WorkoutProgress.fromJson({});
      expect(w.started, isFalse);
      expect(w.done, isEmpty);
      final n = WorkoutProgress.fromJson({'gym_started': null, 'gym_done': null});
      expect(n.started, isFalse);
      expect(n.done, isEmpty);
    });
  });
}
