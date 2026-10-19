import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/screens/admin/clients_screen.dart';
import 'package:kotta_qani_diet/screens/admin/subscriptions_screen.dart';
import 'package:kotta_qani_diet/screens/barmen/barmen_home.dart';
import 'package:kotta_qani_diet/screens/user/gym_screen.dart';
import 'package:kotta_qani_diet/screens/user/progress_screen.dart';
import 'package:kotta_qani_diet/screens/user/today_screen.dart';
import 'package:kotta_qani_diet/services/api/api_instance.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';
import 'package:kotta_qani_diet/services/db.dart';
import 'package:kotta_qani_diet/theme.dart';
import 'package:kotta_qani_diet/widgets/ui.dart';

import 'support/fake_api.dart';

const _sizes = <String, Size>{
  '360x740': Size(360, 740),
  '390x844': Size(390, 844)
};

const _themes = <String, bool>{'light': true, 'dark': false};

Map<String, dynamic> _userJson(String id, String name,
        {String role = 'user'}) =>
    {
      'id': id,
      'name': name,
      'phone': '998901234567',
      'role': role,
      'gender': 'male',
      'age': 28,
      'height': 178,
      'weight': 82,
      'goal': 'lose',
      'plan_id': 'p1',
      'gym_id': 'g1',
      'gym_days': [1, 3, 5],
      'subscription_expires_at': '2099-01-01T00:00:00Z',
    };

final _plan = {
  'id': 'p1',
  'title': 'Ozish • 80-90 kg',
  'note': 'Suv ichishni unutmang',
  'meals': [
    {
      'time': '08:00',
      'title': 'Nonushta',
      'items': [
        {'name': 'Tuxum', 'grams': 120, 'kcal': 180, 'protein': 15},
        {'name': 'Jo\'xori bo\'tqasi', 'grams': 80, 'kcal': 290, 'protein': 10},
      ],
    },
    {
      'time': '13:00',
      'title': 'Tushlik',
      'items': [
        {'name': 'Tovuq ko\'krak', 'grams': 200, 'kcal': 330, 'protein': 60},
      ],
    },
  ],
  'forbidden': ['Shirinlik'],
};

Map<String, dynamic> _subJson(String id) => {
      'id': id,
      'user_id': 'c1',
      'start_date': '2026-10-01T00:00:00Z',
      'months': 1,
      'days': 0,
      'price': 500000,
      'currency': 'UZS',
      'paid_date': '2026-10-01T00:00:00Z',
      'created_at': '2026-10-01T00:00:00Z',
      'expires_at': '2026-11-01T00:00:00Z',
    };

Future<ResponseBody> _route(RequestOptions o) async {
  final path = o.path;
  if (path == '/v1/users/me') {
    return jsonBody(_userJson('b1', 'Barmen', role: 'barmen'), 200);
  }
  if (path == '/v1/users') {
    return jsonBody(
        [_userJson('c1', 'Ali Valiyev'), _userJson('c2', 'Bobur Karimov')],
        200);
  }
  if (path.startsWith('/v1/users/c')) {
    return jsonBody(_userJson('c1', 'Ali Valiyev'), 200);
  }
  if (path == '/v1/plans/p1') {
    return jsonBody(_plan, 200);
  }
  if (path == '/v1/plans') {
    return jsonBody([_plan], 200);
  }
  if (path.endsWith('/weights')) {
    return jsonBody([
      {'date': '2026-10-01T00:00:00Z', 'weight': 84.5},
      {'date': '2026-10-10T00:00:00Z', 'weight': 83.1},
      {'date': '2026-10-18T00:00:00Z', 'weight': 82.0},
    ], 200);
  }
  if (path == '/v1/subscriptions') {
    return jsonBody([_subJson('s1')], 200);
  }
  if (path == '/v1/memberships') {
    return jsonBody([
      {..._subJson('m1'), 'name': 'Ali Valiyev', 'gym_id': 'g1'},
      {..._subJson('m2'), 'name': 'Bobur Karimov', 'gym_id': 'g1'},
    ], 200);
  }
  if (path == '/v1/products') {
    return jsonBody([
      {
        'id': 'pr1',
        'category': 'Ichimlik',
        'name': 'Protein kokteyl',
        'price': 25000,
        'currency': 'UZS',
        'stock': 10,
        'active': true,
      },
    ], 200);
  }
  if (RegExp(r'/(days|attendance)/[\d-]+$').hasMatch(path)) {
    return jsonBody(<String, dynamic>{}, 200);
  }
  return jsonBody(<dynamic>[], 200);
}

final _student = AppUser.fromJson(_userJson('u1', 'Ali'));
final _owner = AppUser.fromJson(_userJson('o1', 'Rahbar', role: 'owner'));
final _barmen = AppUser.fromJson(_userJson('b1', 'Barmen', role: 'barmen'));

typedef _Build = Widget Function();

class _Screen {
  final String name;
  final _Build build;
  final String? tab;
  const _Screen(this.name, this.build, {this.tab});
}

final _screens = <_Screen>[
  _Screen('student Bugun', () => TodayScreen(user: _student)),
  _Screen('student Progress', () => ProgressScreen(user: _student)),
  _Screen('student Zal', () => GymScreen(user: _student)),
  _Screen('admin Mijozlar', () => ClientsScreen(admin: _owner)),
  _Screen('admin Obuna', () => SubscriptionsScreen(admin: _owner)),
  _Screen("barmen Do'kon", () => const BarmenHome()),
  _Screen("barmen To'lovlar", () => const BarmenHome(), tab: "To'lovlar"),
];

bool _inside(Element element, bool Function(Widget) test) {
  var found = false;
  element.visitAncestorElements((a) {
    if (test(a.widget)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

bool _isButton(Widget w) =>
    w is IconButton ||
    w is ElevatedButton ||
    w is FilledButton ||
    w is OutlinedButton ||
    w is TextButton ||
    w is PopupMenuButton ||
    w is TextField ||
    w is Switch ||
    w is Checkbox ||
    w is Slider ||
    w is Scrollbar ||
    w is Tooltip;

({int checked, List<String> small}) _targets(WidgetTester tester) {
  final bad = <String>{};
  var checked = 0;
  for (final element in tester.allElements) {
    final w = element.widget;
    final box = element.renderObject;
    if (box is! RenderBox || !box.hasSize || !box.attached) {
      continue;
    }
    final tappable = switch (w) {
      IconButton(:final onPressed) => onPressed != null,
      ElevatedButton(:final onPressed) => onPressed != null,
      FilledButton(:final onPressed) => onPressed != null,
      OutlinedButton(:final onPressed) => onPressed != null,
      TextButton(:final onPressed) => onPressed != null,
      InkWell(:final onTap) => onTap != null && !_inside(element, _isButton),
      GestureDetector(:final onTap) =>
        onTap != null && !_inside(element, (x) => _isButton(x) || x is InkWell),
      _ => false,
    };
    if (!tappable || (w is! IconButton && _inside(element, _isButton))) {
      continue;
    }
    checked++;
    final size = box.size;
    if (size.width < kTouchTarget || size.height < kTouchTarget) {
      bad.add(
          '${w.runtimeType} ${size.width.toStringAsFixed(1)}x${size.height.toStringAsFixed(1)}');
    }
  }
  return (checked: checked, small: bad.toList()..sort());
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  pollActivity.value = false;
  for (var i = 0; i < 3; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(minutes: 10));
  }
  pollActivity.value = true;
}

void main() {
  final savedLight = AppColors.light;

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    apiClient.useAdapter(FakeAdapter(_route));
  });

  tearDown(() {
    AppColors.light = savedLight;
  });

  for (final size in _sizes.entries) {
    for (final theme in _themes.entries) {
      for (final screen in _screens) {
        testWidgets('${screen.name} @ ${size.key} / ${theme.key}',
            (tester) async {
          tester.view.physicalSize = size.value;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          AppColors.light = theme.value;

          await tester.pumpWidget(ProviderScope(
            overrides: [
              meProvider.overrideWith((ref) => Stream.value(_barmen))
            ],
            child: MaterialApp(
              theme: AppTheme.dark(),
              home: Scaffold(body: screen.build()),
            ),
          ));
          for (var i = 0; i < 6; i++) {
            await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 20)));
            await tester.pump(const Duration(milliseconds: 100));
          }
          if (screen.tab != null) {
            await tester.tap(find.text(screen.tab!).last);
            for (var i = 0; i < 6; i++) {
              await tester.runAsync(
                  () => Future<void>.delayed(const Duration(milliseconds: 20)));
              await tester.pump(const Duration(milliseconds: 100));
            }
          }

          final errors = <String>[];
          for (Object? e = tester.takeException();
              e != null;
              e = tester.takeException()) {
            errors.add(e.toString().split('\n').first);
          }
          expect(errors, isEmpty, reason: 'render errors: $errors');
          expect(find.byType(ErrorState), findsNothing);
          final targets = _targets(tester);
          expect(targets.checked, greaterThan(0));
          expect(targets.small, isEmpty);

          await _dispose(tester);
        });
      }
    }
  }
}
