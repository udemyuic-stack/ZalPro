import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/tr.dart';

class InputLimits {
  static const name = 60;
  static const phoneDigits = 9;
  static const passwordMin = 8;
  static const passwordMax = 128;
  static const foodName = 80;
  static const planTitle = 120;
  static const mealTitle = 60;
  static const mealTime = 10;
  static const mealItemName = 80;
  static const productName = 120;
  static const productNote = 500;
  static const variant = 30;
  static const variantCount = 30;
  static const gymName = 60;
  static const address = 200;
  static const region = 60;
  static const message = 2000;
  static const planNote = 5000;
  static const forbiddenItem = 80;
  static const forbiddenCount = 50;
  static const mealsPerDay = 20;
  static const itemsPerMeal = 50;
  static const maxInt = 2147483647;
  static const maxMonths = 24;
  static const maxDays = 31;

  static const serverAgeMax = 120;
  static const serverHeightMax = 300;
  static const serverWeightMax = 500;

  static const ageMin = 10;
  static const ageMax = 100;
  static const heightMin = 100;
  static const heightMax = 250;
  static const weightMin = 30;
  static const weightMax = 300;

  static const kcalMax = 1000;
  static const macroMax = 100;
  static const gramsMax = 10000;
  static const itemKcalMax = 10000;
}

class _DecimalFormatter extends TextInputFormatter {
  final int maxDecimals;
  const _DecimalFormatter(this.maxDecimals);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final buf = StringBuffer();
    var seenSeparator = false;
    var decimals = 0;
    for (final r in newValue.text.runes) {
      final ch = String.fromCharCode(r);
      if (r >= 0x30 && r <= 0x39) {
        if (seenSeparator) {
          if (decimals >= maxDecimals) continue;
          decimals++;
        }
        buf.write(ch);
      } else if ((ch == '.' || ch == ',') && !seenSeparator && maxDecimals > 0) {
        seenSeparator = true;
        buf.write(ch);
      }
    }
    final text = buf.toString();
    if (text == newValue.text) return newValue;
    final offset = newValue.selection.baseOffset.clamp(0, text.length);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: offset));
  }
}

class InputRules {
  static final List<TextInputFormatter> digitsOnly = [FilteringTextInputFormatter.digitsOnly];

  static List<TextInputFormatter> decimalOnly({int maxDecimals = 2}) => [
        _DecimalFormatter(maxDecimals),
      ];

  static List<TextInputFormatter> digitsMax(int maxLength) => [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLength),
      ];

  static Widget? counterAtEighty(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) {
    if (maxLength == null || currentLength * 5 < maxLength * 4) return null;
    final atLimit = currentLength >= maxLength;
    return Text(
      '$currentLength/$maxLength',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: atLimit ? Theme.of(context).colorScheme.error : null,
          ),
    );
  }

  static int length(String s) => s.runes.length;

  static double? parseDecimal(String? raw) =>
      double.tryParse((raw ?? '').trim().replaceAll(',', '.'));

  static int? parseInt(String? raw) => int.tryParse((raw ?? '').trim());

  static String? requiredText(String? v, int max, {String? emptyMessage}) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return emptyMessage ?? tr('Kiriting');
    return length(text) > max ? trf("Eng ko'pi {0} belgi", [max]) : null;
  }

  static String? optionalText(String? v, int max) {
    return length((v ?? '').trim()) > max ? trf("Eng ko'pi {0} belgi", [max]) : null;
  }

  static String? password(String? v, {required bool strict}) {
    final value = v ?? '';
    if (!strict) return value.isEmpty ? tr('Parolni kiriting') : null;
    if (value.length < InputLimits.passwordMin) return tr("Parol kamida 8 belgi bo'lsin");
    if (value.length > InputLimits.passwordMax) {
      return trf("Eng ko'pi {0} belgi", [InputLimits.passwordMax]);
    }
    return null;
  }

  static String? intInRange(String? v, int min, int max, {bool required = true}) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return required ? tr('Kiriting') : null;
    final n = int.tryParse(text);
    if (n == null) return tr('Butun son kiriting');
    if (n < min || n > max) return trf('{0} dan {1} gacha kiriting', [min, max]);
    return null;
  }

  static String? decimalInRange(
    String? v,
    num min,
    num max, {
    bool required = true,
    bool minExclusive = false,
  }) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return required ? tr('Kiriting') : null;
    final n = parseDecimal(text);
    if (n == null || n.isNaN || n.isInfinite) return tr("To'g'ri son kiriting");
    final belowMin = minExclusive ? n <= min : n < min;
    if (belowMin || n > max) {
      return minExclusive
          ? trf('{0} dan katta, {1} gacha kiriting', [min, max])
          : trf('{0} dan {1} gacha kiriting', [min, max]);
    }
    return null;
  }

  static String? Function(String?) intRange(int min, int max, {bool required = true}) =>
      (v) => intInRange(v, min, max, required: required);

  static String? Function(String?) decimalRange(
    num min,
    num max, {
    bool required = true,
    bool minExclusive = false,
  }) =>
      (v) => decimalInRange(v, min, max, required: required, minExclusive: minExclusive);

  static String? Function(String?) required(int max, {String? emptyMessage}) =>
      (v) => requiredText(v, max, emptyMessage: emptyMessage);

  static String? Function(String?) optional(int max) => (v) => optionalText(v, max);

  static List<String> splitVariants(String raw) =>
      raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  static String? listError(
    List<String> items, {
    required int maxCount,
    required int maxItem,
    bool unique = true,
  }) {
    if (items.length > maxCount) return trf("Eng ko'pi {0} ta bo'lishi mumkin", [maxCount]);
    final seen = <String>{};
    for (final item in items) {
      if (length(item) > maxItem) {
        return trf('Har biri eng ko\'pi {0} belgi: "{1}"', [maxItem, item]);
      }
      if (unique && !seen.add(item)) return trf('Takrorlangan: "{0}"', [item]);
    }
    return null;
  }

  static String? variantsError(List<String> items) => listError(
        items,
        maxCount: InputLimits.variantCount,
        maxItem: InputLimits.variant,
      );

  static String? variantsText(String? raw) => variantsError(splitVariants(raw ?? ''));

  static bool focusFirstError(BuildContext formContext) {
    EditableTextState? target;
    BuildContext? failing;
    void visit(Element e) {
      if (target != null) return;
      if (e is StatefulElement && e.state is FormFieldState) {
        final st = e.state as FormFieldState;
        if (st.hasError) {
          failing = e;
          void find(Element c) {
            if (target != null) return;
            if (c is StatefulElement && c.state is EditableTextState) {
              target = c.state as EditableTextState;
              return;
            }
            c.visitChildren(find);
          }

          e.visitChildren(find);
          if (target != null) return;
        }
      }
      e.visitChildren(visit);
    }

    (formContext as Element).visitChildren(visit);
    final node = target?.widget.focusNode;
    if (node != null) {
      node.requestFocus();
      return true;
    }
    final ctx = failing;
    if (ctx != null && ctx.mounted) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 150));
    }
    return false;
  }

  static bool validateAndFocus(GlobalKey<FormState> key) {
    final form = key.currentState;
    if (form == null) return false;
    if (form.validate()) return true;
    final ctx = key.currentContext;
    if (ctx != null) focusFirstError(ctx);
    return false;
  }
}
