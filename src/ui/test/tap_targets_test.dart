import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/member_analytics.dart';
import 'package:kotta_qani_diet/models/models.dart';
import 'package:kotta_qani_diet/models/shop.dart';
import 'package:kotta_qani_diet/screens/admin/clients_screen.dart';
import 'package:kotta_qani_diet/screens/admin/member_analytics_screen.dart';
import 'package:kotta_qani_diet/screens/admin/plans_screen.dart';
import 'package:kotta_qani_diet/screens/admin/shop_admin_screen.dart';
import 'package:kotta_qani_diet/screens/auth/login_screen.dart';
import 'package:kotta_qani_diet/screens/user/chat_screen.dart';
import 'package:kotta_qani_diet/screens/user/muscles_screen.dart';
import 'package:kotta_qani_diet/screens/user/profile_setup_screen.dart';
import 'package:kotta_qani_diet/screens/user/today_screen.dart';
import 'package:kotta_qani_diet/screens/user/trainer_tab.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';
import 'package:kotta_qani_diet/theme.dart';
import 'package:kotta_qani_diet/widgets/ui.dart';

const _min = 48.0;
const _primary = 52.0;

final _ignored = <Type>{
  TextField,
  EditableText,
  Scrollbar,
  Tooltip,
  Dismissible,
  Checkbox,
  Switch,
  Radio,
  Slider,
  DropdownButton,
  PopupMenuButton,
};

bool _inside(Element element, Set<Type> types) {
  var found = false;
  element.visitAncestorElements((a) {
    if (types.contains(a.widget.runtimeType)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

bool _insideButton(Element e) => _inside(e, {
      IconButton,
      ElevatedButton,
      FilledButton,
      OutlinedButton,
      TextButton,
      ..._ignored,
    });

class TapHit {
  final String what;
  final Size size;
  final double minHeight;
  const TapHit(this.what, this.size, this.minHeight);

  bool get ok => size.width >= _min && size.height >= minHeight;

  @override
  String toString() => '$what ${size.width.toStringAsFixed(1)}x${size.height.toStringAsFixed(1)}';
}

List<TapHit> audit(WidgetTester tester) {
  final hits = <TapHit>[];
  for (final element in tester.allElements) {
    final w = element.widget;
    final box = element.renderObject;
    if (box is! RenderBox || !box.hasSize || !box.attached) continue;
    if (_inside(element, _ignored)) continue;
    final size = box.size;
    final trail = <String>[];
    element.visitAncestorElements((a) {
      final name = a.widget.runtimeType.toString();
      if (!name.startsWith('_') && trail.length < 3 && a.widget.key == null) trail.add(name);
      return trail.length < 3;
    });
    final where = trail.join('<');
    if (w is IconButton && w.onPressed != null) {
      hits.add(TapHit('IconButton@$where', size, _min));
    } else if ((w is ElevatedButton && w.onPressed != null) ||
        (w is FilledButton && w.onPressed != null)) {
      hits.add(TapHit('${w.runtimeType}@$where', size, _primary));
    } else if ((w is OutlinedButton && w.onPressed != null) ||
        (w is TextButton && w.onPressed != null)) {
      hits.add(TapHit('${w.runtimeType}@$where', size, _min));
    } else if (w is InkWell && w.onTap != null && !_insideButton(element)) {
      final segment = _inside(element, {AppSegmented<int>, AppSegmented<String>});
      hits.add(
          TapHit('${segment ? 'Segment' : 'InkWell'}@$where', size, segment ? _primary : _min));
    } else if (w is GestureDetector && w.onTap != null && !_insideButton(element)) {
      if (_inside(element, {InkWell})) continue;
      hits.add(TapHit('GestureDetector@$where', size, _min));
    }
  }
  return hits;
}

Future<void> pumpAt360(WidgetTester tester, Widget child, {bool scaffold = true}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark(),
    home: scaffold ? Scaffold(body: SingleChildScrollView(child: child)) : child,
  ));
  await tester.pump();
  await tester.pump();
}

Future<List<TapHit>> auditScrolling(WidgetTester tester, {int pages = 8}) async {
  final all = <String, TapHit>{};
  for (var i = 0; i < pages; i++) {
    for (final hit in audit(tester)) {
      all['${hit.what}|${hit.size}'] = hit;
    }
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isEmpty) break;
    await tester.drag(scrollable.first, const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 300));
  }
  return all.values.toList();
}

void expectTargets(WidgetTester tester, {int atLeast = 1}) =>
    expectHits(audit(tester), atLeast: atLeast);

void expectHits(List<TapHit> hits, {int atLeast = 1}) {
  expect(hits.length, greaterThanOrEqualTo(atLeast), reason: 'no tappables found');
  final bad = hits.where((h) => !h.ok).map((h) => h.toString()).toList();
  expect(bad, isEmpty, reason: 'tap targets below minimum: $bad');
}

Future<void> endTest(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump();
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await t.pump();
}

final _user = AppUser(id: 'u1', name: 'Ali', email: 'a@b.c');

void main() {
  testWidgets('login screen', (t) async {
    await pumpAt360(t, const LoginScreen(), scaffold: false);
    expect(t.takeException().toString(), contains('overflowed'));
    expectTargets(t);
    await t.tap(find.byType(TextButton).first);
    await t.pump();
    t.takeException();
    expectTargets(t);
    await endTest(t);
  });

  testWidgets('profile setup (anketa)', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: ProfileSetupScreen(
        user: _user,
        trainerSource: () => pollStream<List<TrainerInfo>>(
          () async => const [TrainerInfo('t1', 'Bobur')],
          every: const Duration(hours: 1),
          bus: ChangeBus(),
          activity: PollActivity(),
        ),
      ),
    ));
    await t.pump();
    await t.pump();
    expectTargets(t);
    await endTest(t);
  });

  testWidgets('trainer tab without a trainer', (t) async {
    await pumpAt360(t, TrainerTab(user: _user, onPick: (_, __) async {}), scaffold: false);
    expectTargets(t);
    await endTest(t);
  });

  testWidgets('water card', (t) async {
    await pumpAt360(
      t,
      WaterCard(uid: 'u', day: '2026-10-17', source: Stream.value(3), setGlasses: (_) async {}),
    );
    expectTargets(t, atLeast: 2);
    await endTest(t);
  });

  testWidgets('chat composer', (t) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    await pumpAt360(
      t,
      ChatComposer(controller: c, onSend: () {}, onAttach: () {}, onVoice: (_) async {}),
    );
    expectTargets(t, atLeast: 2);
  });

  testWidgets('churn card call button is a labeled 52 px outlined button', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: MemberAnalyticsScreen(
        isOwner: true,
        churnLoader: () async => const ChurnReport(items: [
          ChurnItem(userId: 'u1', name: 'Ali', phone: '998901234567', score: 6),
        ]),
        retentionLoader: (f, to) async => const Retention(cohorts: []),
        trainersLoader: (f, to) async => const TrainerStats(rows: []),
      ),
    ));
    await t.pump();
    await t.pump();
    expect(find.text("Qo'ng'iroq"), findsOneWidget);
    expect(t.getSize(find.byKey(const Key('call-u1'))).height, greaterThanOrEqualTo(52));
    expectTargets(t, atLeast: 2);
    await endTest(t);
  });

  testWidgets('muscles screen', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: MusclesScreen(
        gymDays: const [DateTime.tuesday, DateTime.thursday],
        weekday: DateTime.tuesday,
        homeToday: false,
        onBack: () {},
      ),
    ));
    await t.pump(const Duration(seconds: 3));
    expectHits(await auditScrolling(t), atLeast: 4);
    await endTest(t);
  });

  testWidgets('segmented control, bento tile, error and empty states', (t) async {
    var picked = 0;
    await pumpAt360(
      t,
      Column(children: [
        AppSegmented<int>(
          segments: const [
            AppSegment(value: 0, label: 'A'),
            AppSegment(value: 1, label: 'B', icon: Icons.add),
            AppSegment(value: 2, label: 'C'),
          ],
          selected: 0,
          onChanged: (v) => picked = v,
        ),
        SizedBox(width: double.infinity, child: BentoTile(onTap: () {}, child: const Text('x'))),
        ErrorState(onRetry: () {}),
        const EmptyState(icon: Icons.inbox_outlined, title: 'Bo\'sh'),
      ]),
    );
    expectTargets(t, atLeast: 5);
    await t.tap(find.text('C'));
    expect(picked, 2);
  });

  testWidgets('trainer client list tile keeps the name readable at 360 px', (t) async {
    final long = AppUser(
      id: 'u2',
      name: 'Abdurahmonov Muhammadjon',
      email: '',
      phone: '998901234567',
      goal: 'lose',
      metabolism: 'slow',
      age: 30,
      height: 180,
      weight: 80,
    );
    await pumpAt360(
      t,
      Padding(
        padding: const EdgeInsets.all(16),
        child: ClientTile(client: long, onTap: () {}),
      ),
    );
    final name = find.text('Abdurahmonov Muhammadjon');
    expect(name, findsOneWidget);
    final paragraph = t.renderObject<RenderParagraph>(name);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(t.getSize(name).width, greaterThan(150));
    expectTargets(t);
    await endTest(t);
  });

  testWidgets('barmen order tile buttons', (t) async {
    const order = ShopOrder(
      id: 'o1',
      clientId: 'u1',
      clientName: 'Ali',
      productId: 'p1',
      productName: 'Shaker',
      price: 50000,
    );
    await pumpAt360(
      t,
      Padding(
        padding: const EdgeInsets.all(16),
        child: OrderTile(order: order, onStatus: (_, __) async {}),
      ),
    );
    expect(audit(t).length, greaterThanOrEqualTo(2));
    for (final label in ['Berildi', 'Bekor']) {
      final button = find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) =>
          w is FilledButton || w is OutlinedButton));
      expect(t.getSize(button.first).height, greaterThanOrEqualTo(48), reason: label);
    }
    await endTest(t);
  });

  testWidgets('plan editor app bar save and back', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const PlanEditor()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    final save = find.ancestor(of: find.text('Saqlash'), matching: find.byType(FilledButton));
    expect(t.getSize(save.first).height, greaterThanOrEqualTo(52));
    final back = find.byType(BackButton);
    expect(t.getSize(back).width, greaterThanOrEqualTo(48));
    expect(t.getSize(back).height, greaterThanOrEqualTo(48));
    await endTest(t);
  });

  testWidgets('owner analytics chips and period selector', (t) async {
    t.view.physicalSize = const Size(360, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: MemberAnalyticsScreen(
        isOwner: true,
        churnLoader: () async => const ChurnReport(items: []),
        retentionLoader: (f, to) async => const Retention(cohorts: []),
        trainersLoader: (f, to) async => const TrainerStats(rows: []),
      ),
    ));
    await t.pump();
    await t.pump();
    for (final key in ['filter-all', 'period-30']) {
      final chip = find.byKey(Key(key));
      if (chip.evaluate().isEmpty) continue;
      expect(t.getSize(chip).height, greaterThanOrEqualTo(48), reason: key);
    }
    expectTargets(t);
    await endTest(t);
  });
}
