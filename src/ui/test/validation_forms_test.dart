import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/core/input_rules.dart';
import 'package:kotta_qani_diet/screens/auth/login_screen.dart';
import 'package:kotta_qani_diet/theme.dart';

Future<void> _host(WidgetTester t, Widget child) async {
  t.view.physicalSize = const Size(400, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(theme: AppTheme.dark(), home: Scaffold(body: child)));
}

class _Harness extends StatefulWidget {
  final void Function(bool ok) onResult;
  const _Harness({required this.onResult});
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final age = TextEditingController();
  final sizes = TextEditingController();

  @override
  Widget build(BuildContext context) => Form(
        key: form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(children: [
          TextFormField(
            key: const Key('name'),
            controller: name,
            maxLength: InputLimits.name,
            buildCounter: InputRules.counterAtEighty,
            validator: InputRules.required(InputLimits.name),
          ),
          TextFormField(
            key: const Key('age'),
            controller: age,
            inputFormatters: InputRules.digitsMax(3),
            validator: InputRules.intRange(InputLimits.ageMin, InputLimits.ageMax),
          ),
          TextFormField(
            key: const Key('sizes'),
            controller: sizes,
            validator: InputRules.variantsText,
          ),
          TextButton(
            key: const Key('save'),
            onPressed: () => widget.onResult(InputRules.validateAndFocus(form)),
            child: const Text('save'),
          ),
        ]),
      );
}

Finder _field(String key) => find.byKey(Key(key));

bool _focused(WidgetTester t, String key) {
  final editable = find.descendant(of: _field(key), matching: find.byType(EditableText));
  return t.widget<EditableText>(editable).focusNode.hasFocus;
}

void main() {
  group('form harness', () {
    testWidgets('name longer than 60 cannot be typed or pasted', (t) async {
      await _host(t, _Harness(onResult: (_) {}));
      await t.enterText(_field('name'), 'a' * 75);
      await t.pump();
      final text = t.widget<TextFormField>(_field('name')).controller!.text;
      expect(text.length, 60);
    });

    testWidgets('counter hidden until 80 percent then visible', (t) async {
      await _host(t, _Harness(onResult: (_) {}));
      await t.enterText(_field('name'), 'a' * 47);
      await t.pump();
      expect(find.text('47/60'), findsNothing);
      await t.enterText(_field('name'), 'a' * 48);
      await t.pump();
      expect(find.text('48/60'), findsOneWidget);
    });

    testWidgets('age field rejects letters minus and spaces', (t) async {
      await _host(t, _Harness(onResult: (_) {}));
      await t.enterText(_field('age'), '1a- 2');
      await t.pump();
      expect(t.widget<TextFormField>(_field('age')).controller!.text, '12');
    });

    testWidgets('age boundaries show error text under the field immediately', (t) async {
      await _host(t, _Harness(onResult: (_) {}));
      await t.enterText(_field('age'), '9');
      await t.pump();
      expect(find.text('10 dan 100 gacha kiriting'), findsOneWidget);
      await t.enterText(_field('age'), '10');
      await t.pump();
      expect(find.text('10 dan 100 gacha kiriting'), findsNothing);
      await t.enterText(_field('age'), '100');
      await t.pump();
      expect(find.text('10 dan 100 gacha kiriting'), findsNothing);
      await t.enterText(_field('age'), '101');
      await t.pump();
      expect(find.text('10 dan 100 gacha kiriting'), findsOneWidget);
    });

    testWidgets('31st size and 31 char size are rejected, duplicates too', (t) async {
      await _host(t, _Harness(onResult: (_) {}));
      await t.enterText(_field('sizes'), [for (var i = 0; i < 31; i++) 'S$i'].join(','));
      await t.pump();
      expect(find.text("Eng ko'pi 30 ta bo'lishi mumkin"), findsOneWidget);
      await t.enterText(_field('sizes'), 'a' * 31);
      await t.pump();
      expect(find.textContaining("Har biri eng ko'pi 30 belgi"), findsOneWidget);
      await t.enterText(_field('sizes'), 'XL, XL');
      await t.pump();
      expect(find.text('Takrorlangan: "XL"'), findsOneWidget);
      await t.enterText(_field('sizes'), [for (var i = 0; i < 30; i++) 'S$i'].join(','));
      await t.pump();
      expect(find.textContaining('Takrorlangan'), findsNothing);
      expect(find.textContaining("Eng ko'pi 30 ta"), findsNothing);
    });

    testWidgets('save focuses the first invalid field', (t) async {
      bool? result;
      await _host(t, _Harness(onResult: (ok) => result = ok));
      await t.enterText(_field('name'), 'Ali');
      await t.enterText(_field('age'), '5');
      await t.enterText(_field('sizes'), 'XL,XL');
      await t.pump();
      await t.tap(_field('save'));
      await t.pump();
      expect(result, false);
      expect(_focused(t, 'age'), true);
      expect(_focused(t, 'sizes'), false);
    });

    testWidgets('save succeeds when all valid', (t) async {
      bool? result;
      await _host(t, _Harness(onResult: (ok) => result = ok));
      await t.enterText(_field('name'), 'Ali');
      await t.enterText(_field('age'), '25');
      await t.enterText(_field('sizes'), 'S, M, L');
      await t.pump();
      await t.tap(_field('save'));
      await t.pump();
      expect(result, true);
    });
  });

  group('chat composer limit', () {
    Future<TextEditingController> pumpComposer(WidgetTester t) async {
      final c = TextEditingController();
      await _host(
        t,
        TextField(
          key: const Key('chat'),
          controller: c,
          minLines: 1,
          maxLines: 4,
          maxLength: InputLimits.message,
          buildCounter: InputRules.counterAtEighty,
        ),
      );
      return c;
    }

    testWidgets('text beyond 2000 is cut and counter shows at 1600', (t) async {
      final c = await pumpComposer(t);
      await t.enterText(_field('chat'), 'a' * 1599);
      await t.pump();
      expect(find.text('1599/2000'), findsNothing);
      await t.enterText(_field('chat'), 'a' * 1600);
      await t.pump();
      expect(find.text('1600/2000'), findsOneWidget);
      await t.enterText(_field('chat'), 'a' * 2500);
      await t.pump();
      expect(c.text.length, 2000);
      expect(find.text('2000/2000'), findsOneWidget);
    });
  });

  group('LoginScreen', () {
    testWidgets('register name limited to 60 and empty submit focuses name', (t) async {
      await _host(t, const LoginScreen());
      await t.tap(find.text("Ro'yxatdan o'tish"));
      await t.pumpAndSettle();
      final name = find.byType(TextFormField).first;
      await t.enterText(name, 'b' * 80);
      await t.pump();
      expect(t.widget<TextFormField>(name).controller!.text.length, 60);
      await t.enterText(name, '');
      await t.pump();
      await t.ensureVisible(find.text('Akkaunt yaratish'));
      await t.tap(find.text('Akkaunt yaratish'));
      await t.pump();
      expect(find.text('Ismingizni kiriting'), findsOneWidget);
      expect(find.text("Raqamni to'liq kiriting: 90 123 45 67"), findsOneWidget);
      expect(find.text("Parol kamida 8 belgi bo'lsin"), findsOneWidget);
      final editable = find.descendant(of: name, matching: find.byType(EditableText));
      expect(t.widget<EditableText>(editable).focusNode.hasFocus, true);
    });

    testWidgets('phone accepts digits only and at most 9', (t) async {
      await _host(t, const LoginScreen());
      final phone = find.byType(TextFormField).first;
      await t.enterText(phone, '90a123-45 6789999');
      await t.pump();
      expect(t.widget<TextFormField>(phone).controller!.text, '901234567');
    });
  });
}
