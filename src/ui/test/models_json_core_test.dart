import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/models.dart';

void main() {
  group('Gym.fromJson', () {
    test('full payload', () {
      final g = Gym.fromJson({
        'id': 'g1',
        'name': 'Diamond',
        'address': 'Bunyodkor 12',
        'country': 'Uzbekistan',
        'region': 'Toshkent',
        'district': 'Chilonzor',
      });
      expect(g.id, 'g1');
      expect(g.name, 'Diamond');
      expect(g.address, 'Bunyodkor 12');
      expect(g.country, 'Uzbekistan');
      expect(g.region, 'Toshkent');
      expect(g.district, 'Chilonzor');
    });

    test('minimal payload', () {
      final g = Gym.fromJson({});
      expect(g.id, '');
      expect(g.name, '');
      expect(g.address, '');
      expect(g.country, '');
      expect(g.region, '');
      expect(g.district, '');
    });
  });

  group('TrainerInfo.fromJson', () {
    test('full payload', () {
      final t = TrainerInfo.fromJson({
        'id': 't1',
        'name': 'Vali',
        'bio': 'Coach',
        'accepting': false,
        'gym_id': 'g1',
      });
      expect(t.id, 't1');
      expect(t.name, 'Vali');
      expect(t.bio, 'Coach');
      expect(t.accepting, false);
      expect(t.gymId, 'g1');
    });

    test('minimal payload', () {
      final t = TrainerInfo.fromJson({'id': 't1', 'gym_id': null});
      expect(t.id, 't1');
      expect(t.name, '');
      expect(t.bio, '');
      expect(t.accepting, true);
      expect(t.gymId, '');
    });
  });

  group('TrainerRating.fromJson', () {
    test('full payload', () {
      final r = TrainerRating.fromJson({
        'trainer_id': 't1',
        'stars': 4,
        'comment': 'good',
        'updated_at': '2026-05-06T07:08:09Z',
      });
      expect(r.stars, 4);
      expect(r.comment, 'good');
      expect(r.updatedAt, DateTime.utc(2026, 5, 6, 7, 8, 9).toLocal());
    });

    test('minimal payload', () {
      final r = TrainerRating.fromJson({});
      expect(r.stars, 0);
      expect(r.comment, '');
      expect(r.updatedAt, isNull);
    });
  });

  group('Food.fromJson', () {
    test('full payload', () {
      final f = Food.fromJson({
        'id': 'f1',
        'name': 'Rice',
        'kcal': 130,
        'protein': 2.7,
        'fat': 0.3,
        'carbs': 28,
        'image': 'https://x/y.png',
      });
      expect(f.id, 'f1');
      expect(f.name, 'Rice');
      expect(f.kcal, 130.0);
      expect(f.protein, 2.7);
      expect(f.fat, 0.3);
      expect(f.carbs, 28.0);
      expect(f.image, 'https://x/y.png');
    });

    test('minimal payload', () {
      final f = Food.fromJson({});
      expect(f.id, '');
      expect(f.name, '');
      expect(f.kcal, 0.0);
      expect(f.protein, 0.0);
      expect(f.fat, 0.0);
      expect(f.carbs, 0.0);
      expect(f.image, '');
    });
  });

  group('MealItem.fromJson', () {
    test('full payload', () {
      final i = MealItem.fromJson({
        'name': 'Egg',
        'grams': 100,
        'kcal': 155.5,
        'protein': 13,
        'image': 'img',
      });
      expect(i.name, 'Egg');
      expect(i.grams, 100.0);
      expect(i.kcal, 155.5);
      expect(i.protein, 13.0);
      expect(i.image, 'img');
    });

    test('minimal payload', () {
      final i = MealItem.fromJson({});
      expect(i.name, '');
      expect(i.grams, 0.0);
      expect(i.kcal, 0.0);
      expect(i.protein, 0.0);
      expect(i.image, '');
    });
  });

  group('Meal.fromJson', () {
    test('full payload', () {
      final m = Meal.fromJson({
        'time': '07:00',
        'title': 'Breakfast',
        'items': [
          {'name': 'Egg', 'grams': 50, 'kcal': 70, 'protein': 6, 'image': ''},
          {'name': 'Bread', 'grams': 30, 'kcal': 80, 'protein': 3, 'image': 'b'},
        ],
      });
      expect(m.time, '07:00');
      expect(m.title, 'Breakfast');
      expect(m.items.length, 2);
      expect(m.items[0].name, 'Egg');
      expect(m.items[1].image, 'b');
      expect(m.kcal, 150.0);
      expect(m.protein, 9.0);
    });

    test('minimal payload', () {
      final m = Meal.fromJson({});
      expect(m.time, '');
      expect(m.title, '');
      expect(m.items, isEmpty);
    });
  });

  group('Plan.fromJson', () {
    test('full payload', () {
      final p = Plan.fromJson({
        'id': 'p1',
        'title': 'Ozish • 80-90 kg',
        'note': 'note',
        'forbidden': ['sugar', 'soda'],
        'meals': [
          {
            'time': '08:00',
            'title': 'A',
            'items': [
              {'name': 'x', 'grams': 100, 'kcal': 200, 'protein': 10, 'image': ''},
            ],
          },
        ],
        'week': {
          '1': [
            {'time': '09:00', 'title': 'Mon', 'items': []},
          ],
          '7': [],
          '9': [
            {'time': '', 'title': 'bad', 'items': []},
          ],
          'x': [],
        },
        'photos': {'1': 'assets/a.png', '3': 'https://x/y.png', '8': 'bad'},
      });
      expect(p.id, 'p1');
      expect(p.title, 'Ozish • 80-90 kg');
      expect(p.note, 'note');
      expect(p.forbidden, ['sugar', 'soda']);
      expect(p.meals.length, 1);
      expect(p.meals.first.items.first.kcal, 200.0);
      expect(p.week.keys.toList()..sort(), [1, 7]);
      expect(p.week[1]!.first.title, 'Mon');
      expect(p.week[7], isEmpty);
      expect(p.photos, {1: 'assets/a.png', 3: 'https://x/y.png'});
      expect(p.isWeekly, true);
    });

    test('minimal payload', () {
      final p = Plan.fromJson({'week': null, 'photos': null});
      expect(p.id, '');
      expect(p.title, '');
      expect(p.note, '');
      expect(p.meals, isEmpty);
      expect(p.week, isEmpty);
      expect(p.photos, isEmpty);
      expect(p.forbidden, isEmpty);
      expect(p.isWeekly, false);
    });
  });

  group('WeightLog.fromJson', () {
    test('full payload', () {
      final w = WeightLog.fromJson({
        'id': '00000000-0000-0000-0000-000000000001',
        'date': '2026-04-05T10:00:00Z',
        'weight': 72,
      });
      expect(w.date, DateTime.utc(2026, 4, 5, 10).toLocal());
      expect(w.weight, 72.0);
    });

    test('minimal payload', () {
      final before = DateTime.now();
      final w = WeightLog.fromJson({});
      expect(w.weight, 0.0);
      expect(w.date.isBefore(before), false);
    });
  });

  group('ChatMessage.fromJson', () {
    test('full payload', () {
      final c = ChatMessage.fromJson({
        'id': '00000000-0000-0000-0000-000000000002',
        'chat_uid': 'u1',
        'sender_id': 'u2',
        'kind': 'text',
        'text': 'salom',
        'created_at': '2026-01-02T03:04:05+00:00',
      });
      expect(c.senderId, 'u2');
      expect(c.text, 'salom');
      expect(c.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5).toLocal());
    });

    test('minimal payload', () {
      final before = DateTime.now();
      final c = ChatMessage.fromJson({});
      expect(c.senderId, '');
      expect(c.text, '');
      expect(c.createdAt.isBefore(before), false);
    });
  });

  group('ExtraFood.fromJson', () {
    test('full payload', () {
      final e = ExtraFood.fromJson({
        'name': 'Apple',
        'grams': 150,
        'kcal': 78.5,
        'protein': 0.4,
        'at': 1760000000000,
      });
      expect(e.name, 'Apple');
      expect(e.grams, 150.0);
      expect(e.kcal, 78.5);
      expect(e.protein, 0.4);
      expect(e.at, 1760000000000);
    });

    test('minimal payload', () {
      final e = ExtraFood.fromJson({});
      expect(e.name, '');
      expect(e.grams, 0.0);
      expect(e.kcal, 0.0);
      expect(e.protein, 0.0);
      expect(e.at, 0);
    });
  });
}
