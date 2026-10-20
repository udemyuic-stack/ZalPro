import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/input_rules.dart';
import '../l10n/tr.dart';
import '../models/shop.dart';
import '../theme.dart';
import 'product_image.dart';

const sizePresets = ['XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL'];

const colorPresets = {
  'qora': Color(0xFF111111),
  'oq': Color(0xFFF5F5F5),
  'qizil': Color(0xFFD32F2F),
  "ko'k": Color(0xFF1976D2),
  'kulrang': Color(0xFF9E9E9E),
  'zaytun': Color(0xFF708238),
  'sariq': Color(0xFFFBC02D),
  'yashil': Color(0xFF388E3C),
};

int? marginPercent(int price, int cost) {
  if (price <= 0) return null;
  return ((price - cost) * 100 / price).round();
}

String _capital(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class CategoryGrid extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;
  const CategoryGrid({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const gap = AppSpace.sm;
    return LayoutBuilder(builder: (context, box) {
      final w = (box.maxWidth - gap * 3) / 4;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final c in categories)
          SizedBox(
            width: w,
            height: 68,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: Key('category-$c'),
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => onSelected(c),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    color: selected == c ? AppColors.accent.withValues(alpha: 0.12) : null,
                    border: Border.all(
                      color: selected == c ? AppColors.accent : AppColors.hairlineStrong,
                      width: selected == c ? 1.5 : 1,
                    ),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(
                      shopIcon(c),
                      size: 22,
                      color: selected == c ? AppColors.accent : AppColors.textMuted,
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          c,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}

class QtyStepper extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;
  const QtyStepper({super.key, required this.controller, required this.onChanged});

  void _step(int d) {
    final v = ((InputRules.parseInt(controller.text) ?? 0) + d).clamp(0, InputLimits.maxInt);
    controller.text = '$v';
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    ButtonStyle style() => OutlinedButton.styleFrom(
          minimumSize: const Size(kTouchTarget, kTouchTarget),
          padding: EdgeInsets.zero,
        );
    return Row(children: [
      OutlinedButton(
        key: const Key('stock-minus'),
        style: style(),
        onPressed: () => _step(-1),
        child: const Icon(Icons.remove),
      ),
      const SizedBox(width: AppSpace.sm),
      Expanded(
        child: TextFormField(
          key: const Key('stock-field'),
          controller: controller,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            ...InputRules.digitsMax(10),
            FilteringTextInputFormatter.digitsOnly,
          ],
          validator: InputRules.intRange(0, InputLimits.maxInt, required: false),
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(labelText: tr('Ombor zaxirasi'), suffixText: 'dona'),
        ),
      ),
      const SizedBox(width: AppSpace.sm),
      OutlinedButton(
        key: const Key('stock-plus'),
        style: style(),
        onPressed: () => _step(1),
        child: const Icon(Icons.add),
      ),
    ]);
  }
}

class ChipPicker extends StatefulWidget {
  final TextEditingController controller;
  final List<String> presets;
  final Color? Function(String value)? dotOf;
  final String addLabel;
  final VoidCallback onChanged;
  final bool upper;
  const ChipPicker({
    super.key,
    required this.controller,
    required this.presets,
    required this.addLabel,
    required this.onChanged,
    this.dotOf,
    this.upper = false,
  });

  @override
  State<ChipPicker> createState() => _ChipPickerState();
}

class _ChipPickerState extends State<ChipPicker> {
  final _extra = TextEditingController();

  @override
  void dispose() {
    _extra.dispose();
    super.dispose();
  }

  List<String> get _selected => InputRules.splitVariants(widget.controller.text);

  void _write(List<String> v) {
    widget.controller.text = v.join(', ');
    widget.onChanged();
    setState(() {});
  }

  void _toggle(String value) {
    final cur = _selected;
    _write(cur.contains(value) ? (cur..remove(value)) : [...cur, value]);
  }

  void _addExtra() {
    final cur = _selected;
    final add = InputRules.splitVariants(_extra.text).where((e) => !cur.contains(e));
    _extra.clear();
    if (add.isNotEmpty) _write([...cur, ...add]);
  }

  @override
  Widget build(BuildContext context) {
    final cur = _selected;
    final all = [...widget.presets, ...cur.where((e) => !widget.presets.contains(e))];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
        for (final v in all)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kTouchTarget),
            child: FilterChip(
              key: Key('chip-$v'),
              selected: cur.contains(v),
              showCheckmark: false,
              avatar: widget.dotOf?.call(v) == null
                  ? null
                  : Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: widget.dotOf!(v),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.hairlineStrong),
                      ),
                    ),
              onSelected: (_) => _toggle(v),
              label: Text(widget.upper ? v : _capital(v)),
            ),
          ),
      ]),
      const SizedBox(height: AppSpace.sm),
      TextField(
        controller: _extra,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _addExtra(),
        decoration: InputDecoration(
          hintText: widget.addLabel,
          suffixIcon: IconButton(
            tooltip: tr("Qo'shish"),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: _addExtra,
            icon: const Icon(Icons.add),
          ),
        ),
      ),
    ]);
  }
}

class ProfitBanner extends StatelessWidget {
  final int price;
  final int cost;
  final String currency;
  const ProfitBanner({super.key, required this.price, required this.cost, required this.currency});

  @override
  Widget build(BuildContext context) {
    final margin = marginPercent(price, cost);
    if (cost <= 0 || margin == null) return const SizedBox.shrink();
    final profit = price - cost;
    final good = profit >= 0;
    final color = good ? AppColors.success : AppColors.danger;
    return Container(
      key: const Key('profit-banner'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpace.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(good ? Icons.trending_up : Icons.trending_down, color: color, size: 18),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(
            trf('Kutilayotgan sof foyda: {0}{1} {2} ({3}% marja)', [
              good ? '+' : '',
              fmtSum(profit),
              currencyLabel(currency),
              margin,
            ]),
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}
