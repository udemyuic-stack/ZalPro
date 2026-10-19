import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/core/input_rules.dart';

TextEditingValue _apply(TextInputFormatter f, String text) =>
    f.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text));

String _format(List<TextInputFormatter> fs, String text) {
  var v = TextEditingValue.empty;
  for (final f in fs) {
    v = f.formatEditUpdate(
        TextEditingValue.empty, TextEditingValue(text: v.text.isEmpty ? text : v.text));
  }
  return v.text;
}

void main() {
  group('client ranges lie inside server ranges', () {
    test('age', () {
      expect(InputLimits.ageMin, greaterThanOrEqualTo(1));
      expect(InputLimits.ageMax, lessThanOrEqualTo(InputLimits.serverAgeMax));
    });
    test('height', () {
      expect(InputLimits.heightMin, greaterThan(0));
      expect(InputLimits.heightMax, lessThanOrEqualTo(InputLimits.serverHeightMax));
    });
    test('weight', () {
      expect(InputLimits.weightMin, greaterThan(0));
      expect(InputLimits.weightMax, lessThanOrEqualTo(InputLimits.serverWeightMax));
    });
    test('server text limits', () {
      expect(InputLimits.name, 60);
      expect(InputLimits.message, 2000);
      expect(InputLimits.variant, 30);
      expect(InputLimits.variantCount, 30);
      expect(InputLimits.maxInt, 2147483647);
    });
  });

  group('intInRange boundaries', () {
    String? age(String v) => InputRules.intInRange(v, InputLimits.ageMin, InputLimits.ageMax);
    test('min and max accepted', () {
      expect(age('${InputLimits.ageMin}'), isNull);
      expect(age('${InputLimits.ageMax}'), isNull);
    });
    test('min-1 and max+1 rejected with range text', () {
      expect(age('${InputLimits.ageMin - 1}'), '10 dan 100 gacha kiriting');
      expect(age('${InputLimits.ageMax + 1}'), '10 dan 100 gacha kiriting');
    });
    test('empty required and optional', () {
      expect(age(''), isNotNull);
      expect(InputRules.intInRange('', 0, 5, required: false), isNull);
    });
    test('non numeric rejected', () {
      expect(age('1.5'), isNotNull);
      expect(age('abc'), isNotNull);
      expect(age('-5'), isNotNull);
    });
    test('money max', () {
      expect(InputRules.intInRange('2147483647', 0, InputLimits.maxInt), isNull);
      expect(InputRules.intInRange('2147483648', 0, InputLimits.maxInt), isNotNull);
      expect(InputRules.intInRange('0', 0, InputLimits.maxInt), isNull);
      expect(InputRules.intInRange('-1', 0, InputLimits.maxInt), isNotNull);
    });
  });

  group('decimalInRange boundaries', () {
    String? height(String v) =>
        InputRules.decimalInRange(v, InputLimits.heightMin, InputLimits.heightMax);
    String? weight(String v) =>
        InputRules.decimalInRange(v, InputLimits.weightMin, InputLimits.weightMax);
    test('height', () {
      expect(height('100'), isNull);
      expect(height('250'), isNull);
      expect(height('99.9'), isNotNull);
      expect(height('250.1'), isNotNull);
    });
    test('weight with comma', () {
      expect(weight('30'), isNull);
      expect(weight('300'), isNull);
      expect(weight('72,5'), isNull);
      expect(weight('29,9'), isNotNull);
      expect(weight('300,1'), isNotNull);
    });
    test('exclusive minimum', () {
      expect(InputRules.decimalInRange('0', 0, 10000, minExclusive: true), isNotNull);
      expect(InputRules.decimalInRange('0.1', 0, 10000, minExclusive: true), isNull);
      expect(InputRules.decimalInRange('10000', 0, 10000, minExclusive: true), isNull);
      expect(InputRules.decimalInRange('10000.1', 0, 10000, minExclusive: true), isNotNull);
    });
    test('garbage rejected', () {
      expect(weight('1.2.3'), isNotNull);
      expect(weight('.'), isNotNull);
    });
  });

  group('text length', () {
    test('requiredText boundaries', () {
      expect(InputRules.requiredText('a' * 60, 60), isNull);
      expect(InputRules.requiredText('a' * 61, 60), "Eng ko'pi 60 belgi");
      expect(InputRules.requiredText('   ', 60), isNotNull);
      expect(InputRules.requiredText(null, 60), isNotNull);
    });
    test('optionalText boundaries', () {
      expect(InputRules.optionalText('', 5), isNull);
      expect(InputRules.optionalText('a' * 5, 5), isNull);
      expect(InputRules.optionalText('a' * 6, 5), isNotNull);
    });
    test('chat message 2000', () {
      expect(InputRules.requiredText('a' * InputLimits.message, InputLimits.message), isNull);
      expect(
          InputRules.requiredText('a' * (InputLimits.message + 1), InputLimits.message), isNotNull);
    });
    test('code points not utf16 units', () {
      expect(InputRules.requiredText('😀' * 30, 30), isNull);
      expect(InputRules.requiredText('😀' * 31, 30), isNotNull);
    });
    test('password', () {
      expect(InputRules.password('1234567', strict: true), isNotNull);
      expect(InputRules.password('12345678', strict: true), isNull);
      expect(InputRules.password('a' * 128, strict: true), isNull);
      expect(InputRules.password('a' * 129, strict: true), isNotNull);
      expect(InputRules.password('', strict: false), isNotNull);
      expect(InputRules.password('x', strict: false), isNull);
    });
  });

  group('variants (sizes and colors)', () {
    test('30 items accepted, 31st rejected', () {
      final ok = [for (var i = 0; i < 30; i++) 'S$i'];
      expect(InputRules.variantsError(ok), isNull);
      expect(InputRules.variantsError([...ok, 'S30']), isNotNull);
    });
    test('30 chars accepted, 31 chars rejected', () {
      expect(InputRules.variantsError(['a' * 30]), isNull);
      expect(InputRules.variantsError(['a' * 31]), isNotNull);
    });
    test('duplicates rejected', () {
      expect(InputRules.variantsError(['XL', 'XXL', 'XL']), 'Takrorlangan: "XL"');
    });
    test('variantsText splits on commas and trims', () {
      expect(InputRules.splitVariants(' XL , XXL,, 3XL '), ['XL', 'XXL', '3XL']);
      expect(InputRules.variantsText('XL, XL'), isNotNull);
      expect(InputRules.variantsText('${'a' * 31}, b'), isNotNull);
      expect(InputRules.variantsText(''), isNull);
    });
    test('31 comma separated entries rejected via text', () {
      final text = [for (var i = 0; i < 31; i++) 'S$i'].join(',');
      expect(InputRules.variantsText(text), isNotNull);
      expect(InputRules.variantsText([for (var i = 0; i < 30; i++) 'S$i'].join(',')), isNull);
    });
  });

  group('formatters', () {
    test('digitsOnly removes letters spaces and minus', () {
      expect(_format(InputRules.digitsOnly, '1a2 3-4'), '1234');
    });
    test('digitsMax limits length', () {
      final f = InputRules.digitsMax(9);
      final v = f[1].formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '1234567890'),
      );
      expect(v.text, '123456789');
    });
    test('decimalOnly keeps one separator and no sign', () {
      final f = InputRules.decimalOnly(maxDecimals: 2).single;
      expect(_apply(f, '12.5').text, '12.5');
      expect(_apply(f, '12,5').text, '12,5');
      expect(_apply(f, '1.2.3').text, '1.23');
      expect(_apply(f, '-5').text, '5');
      expect(_apply(f, '1e5').text, '15');
      expect(_apply(f, 'abc').text, '');
      expect(_apply(f, '1.234').text, '1.23');
      expect(_apply(f, ' 7 ').text, '7');
    });
    test('decimalOnly with zero decimals drops separators', () {
      final f = InputRules.decimalOnly(maxDecimals: 0).single;
      expect(_apply(f, '1.5').text, '15');
    });
  });

  group('counter', () {
    Future<Widget?> counter(WidgetTester t, int len, int max) async {
      Widget? result;
      await t.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          result = InputRules.counterAtEighty(
            context,
            currentLength: len,
            isFocused: true,
            maxLength: max,
          );
          return const SizedBox();
        }),
      ));
      return result;
    }

    testWidgets('hidden below 80 percent', (t) async {
      expect(await counter(t, 79, 100), isNull);
    });
    testWidgets('visible at 80 percent and above', (t) async {
      expect(await counter(t, 80, 100), isNotNull);
      expect(await counter(t, 100, 100), isNotNull);
    });
    testWidgets('chat 1600 of 2000', (t) async {
      expect(await counter(t, 1599, 2000), isNull);
      expect(await counter(t, 1600, 2000), isNotNull);
    });
  });
}
