import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/l10n/tr.dart';
import 'package:kotta_qani_diet/models/announcement.dart';
import 'package:kotta_qani_diet/screens/user/shop_screen.dart';
import 'package:kotta_qani_diet/widgets/announcement_banner.dart';
import 'package:kotta_qani_diet/widgets/app_nav_bar.dart';
import 'package:kotta_qani_diet/widgets/product_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotta_qani_diet/screens/admin/admin_home.dart';
import 'package:kotta_qani_diet/screens/user/today_screen.dart';
import 'package:kotta_qani_diet/theme.dart';
import 'package:kotta_qani_diet/widgets/ui.dart';

void setSize(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> pump360(WidgetTester tester, Widget child, {bool light = false}) async {
  setSize(tester, 360);
  AppColors.light = light;
  addTearDown(() => AppColors.light = false);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.current(), home: Scaffold(body: child)));
  await tester.pump();
}

Future<void> pumpWater(
  WidgetTester tester, {
  required int g,
  required Future<void> Function(int) set,
  double width = 360,
}) async {
  setSize(tester, width);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.current(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: WaterCard(uid: 'u', day: '2026-10-17', source: Stream.value(g), setGlasses: set),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('water shows the new value before the call completes', (tester) async {
    final gate = Completer<void>();
    await pumpWater(tester, g: 5, set: (_) => gate.future);
    await tester.tap(find.byKey(const Key('water-plus')));
    await tester.pump();
    expect(find.text('6'), findsOneWidget);
    expect(find.text('5'), findsNothing);
    gate.complete();
    await tester.pump();
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('water rolls back and shows a snack when the call fails', (tester) async {
    await pumpWater(tester, g: 5, set: (_) async => throw Exception('boom'));
    await tester.tap(find.byKey(const Key('water-plus')));
    await tester.pump();
    await tester.pump();
    expect(find.text('5'), findsOneWidget);
    expect(find.text('6'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('water glass tiles are at least 48x48 at 360 px', (tester) async {
    await pumpWater(tester, g: 3, set: (_) async {});
    for (var i = 1; i <= 8; i++) {
      final size = tester.getSize(find.bySemanticsLabel(RegExp('^$i ')).first);
      expect(size.width, greaterThanOrEqualTo(48), reason: 'tile $i');
      expect(size.height, greaterThanOrEqualTo(48), reason: 'tile $i');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppSegmented is at least 52 high and reports taps', (tester) async {
    setSize(tester, 360);
    var value = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.current(),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, set) => AppSegmented<int>(
            key: const Key('seg'),
            segments: const [
              AppSegment(value: 0, label: 'A'),
              AppSegment(value: 1, label: 'B'),
              AppSegment(value: 2, label: 'C'),
            ],
            selected: value,
            onChanged: (v) => set(() => value = v),
          ),
        ),
      ),
    ));
    expect(tester.getSize(find.byKey(const Key('seg'))).height, greaterThanOrEqualTo(52));
    await tester.tap(find.text('B'));
    await tester.pump();
    expect(value, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin header keeps the title on one line at 360 px', (tester) async {
    setSize(tester, 360);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.current(),
      home: Scaffold(
        appBar: AdminAppBar(title: 'Ovqatlanish rejalari', isOwner: true, onMore: () {}),
      ),
    ));
    await tester.pump();
    final title = tester.getSize(find.text('Ovqatlanish rejalari'));
    expect(title.height, lessThan(30));
    for (final tip in ['Skaner', "Ro'yxatdan o'tish QR kodi", "Ko'proq"]) {
      final size = tester.getSize(find.byTooltip(tip));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(tester.takeException(), isNull);
  });

  group('EdgeFade', () {
    testWidgets('8 chips at 360 px scroll horizontally without overflow', (tester) async {
      await pump360(
        tester,
        EdgeFade(
          child: Row(children: [
            for (var i = 0; i < 8; i++)
              Padding(
                padding: const EdgeInsets.only(right: AppSpace.sm),
                child: ChoiceChip(
                  key: Key('chip$i'),
                  selected: i == 0,
                  onSelected: (_) {},
                  label: Text('Kategoriya $i'),
                ),
              ),
          ]),
        ),
      );
      expect(tester.takeException(), isNull);
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      final before = tester.getTopLeft(find.byKey(const Key('chip7'))).dx;
      expect(before, greaterThan(360));
      await tester.drag(find.byType(EdgeFade), const Offset(-300, 0));
      await tester.pump();
      expect(scroll.position.pixels, greaterThan(0));
      expect(tester.getTopLeft(find.byKey(const Key('chip7'))).dx, lessThan(before));
      expect(tester.takeException(), isNull);
    });
  });

  group('ProductImage without a picture', () {
    for (final light in [false, true]) {
      for (final size in [56.0, 60.0]) {
        testWidgets('${light ? 'light' : 'dark'} $size: no overflow', (tester) async {
          await pump360(
            tester,
            Row(children: [
              ProductImage(category: 'Protein', name: 'zzz-yo\'q', size: size),
              ProductImage(category: 'Forma', name: 'zzz-yo\'q', size: size),
            ]),
            light: light,
          );
          expect(tester.getSize(find.byType(ProductImage).first), Size(size, size));
          expect(find.byIcon(shopIcon('Protein')), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('AppNavBar', () {
    const items = [
      AppNavItem(icon: Icon(Icons.home), label: 'Bosh'),
      AppNavItem(icon: Icon(Icons.restaurant), label: 'Ovqat'),
      AppNavItem(icon: Icon(Icons.shopping_bag), label: 'Do\'kon'),
      AppNavItem(icon: Icon(Icons.person), label: 'Profil'),
      AppNavItem(icon: Icon(Icons.settings), label: 'Sozlama'),
    ];

    Future<void> pumpBar(WidgetTester tester, {int? primary, required ValueChanged<int> on}) async {
      setSize(tester, 360);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.current(),
        home: Scaffold(
          bottomNavigationBar: AppNavBar(items: items, primary: primary, selected: 0, onSelected: on),
        ),
      ));
      await tester.pump();
    }

    testWidgets('selection callback fires with the tapped index', (tester) async {
      final picked = <int>[];
      await pumpBar(tester, on: picked.add);
      await tester.tap(find.text('Ovqat'));
      await tester.pump();
      expect(picked, [1]);
      expect(tester.takeException(), isNull);
    });

    testWidgets("Ko'proq variant opens the sheet and selects a hidden item", (tester) async {
      final picked = <int>[];
      await pumpBar(tester, primary: 3, on: picked.add);
      expect(find.text('Sozlama'), findsNothing);
      await tester.tap(find.text(tr("Ko'proq")));
      await tester.pumpAndSettle();
      expect(find.text('Sozlama'), findsOneWidget);
      await tester.tap(find.text('Sozlama'));
      await tester.pumpAndSettle();
      expect(picked, [4]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('visible destinations still select in the Ko\'proq variant', (tester) async {
      final picked = <int>[];
      await pumpBar(tester, primary: 3, on: picked.add);
      await tester.tap(find.text('Do\'kon'));
      await tester.pump();
      expect(picked, [2]);
    });
  });

  group('AnnouncementBanner', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('neutral card, dismiss button at least 52 px', (tester) async {
      await pump360(
        tester,
        AnnouncementBanner(
          userId: 'u',
          clock: () => DateTime(2026, 10, 19, 12),
          source: Stream.value([
            const Announcement(
              id: 'a1',
              title: 'Yangilik',
              body: 'Ertaga zal 10:00 da ochiladi',
              audience: AnnouncementAudience.all,
              authorId: 'x',
              authorName: 'Admin',
            ),
          ]),
        ),
      );
      await tester.pump();
      await tester.pump();
      final tile = tester.widget<BentoTile>(find.byKey(const Key('announcement-banner')));
      expect(tile.feature, isFalse);
      final size = tester.getSize(find.byKey(const Key('announcement-dismiss')));
      expect(size.width, greaterThanOrEqualTo(52));
      expect(size.height, greaterThanOrEqualTo(52));
      expect(tester.takeException(), isNull);
    });
  });
}
