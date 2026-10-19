import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/theme.dart';
import 'package:kotta_qani_diet/widgets/product_image.dart';

Future<void> pump(WidgetTester tester, Widget child,
    {required bool light}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  AppColors.light = light;
  addTearDown(() {
    tester.view.reset();
    AppColors.light = false;
  });
  await tester.pumpWidget(MaterialApp(
      theme: AppTheme.current(), home: Scaffold(body: Center(child: child))));
  await tester.pump();
}

void main() {
  for (final light in [false, true]) {
    testWidgets('rasmsiz mahsulot paneli radial gradient, light=$light',
        (tester) async {
      await pump(
          tester, const ProductImage(category: 'Forma', name: 'Demo', size: 60),
          light: light);
      final box =
          tester.widgetList<Container>(find.byType(Container)).firstWhere(
                (c) =>
                    c.decoration is BoxDecoration &&
                    (c.decoration as BoxDecoration).gradient is RadialGradient,
              );
      final g = (box.decoration as BoxDecoration).gradient as RadialGradient;
      expect(g.colors.length, 2);
      expect(
          g.colors.first.computeLuminance() > g.colors.last.computeLuminance(),
          isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
