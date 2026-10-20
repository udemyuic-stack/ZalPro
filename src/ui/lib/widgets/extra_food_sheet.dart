import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../models/models.dart';
import '../services/db.dart';
import '../theme.dart';
import 'food_image.dart';
import 'ui.dart';
import '../services/api/api_error.dart';

/// "+ Yedim" oynasi: mahsulotlar bazasidan taom tanlanadi, miqdori (gramm) yoziladi —
/// kaloriya va oqsil darhol ko'rinadi. Tanlangan [ExtraFood] qaytadi (bekor qilinsa null).
Future<ExtraFood?> showExtraFoodSheet(BuildContext context) =>
    showSheet<ExtraFood>(context, const _ExtraFoodPicker());

class _ExtraFoodPicker extends StatefulWidget {
  const _ExtraFoodPicker();

  @override
  State<_ExtraFoodPicker> createState() => _ExtraFoodPickerState();
}

class _ExtraFoodPickerState extends State<_ExtraFoodPicker> {
  static const _quick = [50, 100, 150, 200, 300];

  late final _foods = Db.foods();
  final _search = TextEditingController();
  final _grams = TextEditingController(text: '100');
  Food? _food;

  @override
  void dispose() {
    _search.dispose();
    _grams.dispose();
    super.dispose();
  }

  double get _g => double.tryParse(_grams.text.replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final food = _food;
    final height = MediaQuery.of(context).size.height;

    // 2-qadam: miqdor
    if (food != null) {
      final ok = _g > 0 && _g <= 3000;
      final e = ExtraFood.of(food, ok ? _g : 0);
      return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              FoodImage(name: food.name, url: food.imageUrl, size: 48),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr(food.name), style: t.titleMedium),
                  Text(trf('100 g da {0} kkal', [food.kcal.round()]),
                      style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                ]),
              ),
              TextButton(
                  onPressed: () => setState(() => _food = null), child: Text(tr('Boshqasini tanlash'))),
            ]),
            const SizedBox(height: AppSpace.lg),
            Text(tr('Qancha yedingiz?'), style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpace.sm),
            Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
              for (final q in _quick)
                ChoiceChip(
                  selected: _g == q,
                  onSelected: (_) => setState(() => _grams.text = '$q'),
                  label: Text(trf('{0} g', [q])),
                ),
            ]),
            const SizedBox(height: AppSpace.md),
            TextField(
              controller: _grams,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: tr('Miqdori'), suffixText: tr('g')),
            ),
            const SizedBox(height: AppSpace.lg),
            BentoTile(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _Num(
                    value: ok ? '${e.kcal.round()}' : '—',
                    unit: tr('kkal'),
                    color: AppColors.accent),
                _Num(
                    value: ok ? fmtNum(e.protein) : '—',
                    unit: tr('g oqsil'),
                    color: AppColors.protein),
              ]),
            ),
            const SizedBox(height: AppSpace.lg),
            FilledButton(
              onPressed: ok ? () => Navigator.pop(context, e) : null,
              child: Text(tr("Qo'shish")),
            ),
            const SizedBox(height: AppSpace.sm),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('Bekor')),
            ),
          ]);
    }

    // 1-qadam: mahsulot tanlash
    return SizedBox(
      height: height * 0.7,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('Rejadan tashqari nima yedingiz?'), style: t.titleLarge),
        const SizedBox(height: AppSpace.md),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: tr('Mahsulot qidirish'),
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Expanded(
          child: StreamBuilder<List<Food>>(
            stream: _foods,
            builder: (context, snap) {
              if (snap.hasError) return ErrorState(error: snap.error);
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final q = _search.text.trim().toLowerCase();
              // qidiruv o'zbekcha nomda ham, tarjimasida ham
              final list = snap.data!
                  .where((f) => f.kcal > 0)
                  .where((f) =>
                      q.isEmpty ||
                      f.name.toLowerCase().contains(q) ||
                      tr(f.name).toLowerCase().contains(q))
                  .toList();
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.lg),
                    child: Text(
                      tr("Topilmadi. Bazada yo'q taomni treneringiz qo'shib beradi — chatda yozing."),
                      textAlign: TextAlign.center,
                      style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                );
              }
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final f = list[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: FoodImage(name: f.name, url: f.imageUrl, size: 40),
                    title: Text(tr(f.name), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(trf('100 g da {0} kkal', [f.kcal.round()])),
                    onTap: () => setState(() => _food = f),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _Num extends StatelessWidget {
  final String value, unit;
  final Color color;
  const _Num({required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: t.headlineSmall?.copyWith(color: color)),
      Text(unit, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
    ]);
  }
}

/// Rejadan tashqari yeyilganlar ro'yxati (bugun). Shogirdda — "+ Yedim" tugmasi va o'chirish
/// bilan; trenerda ([readOnly]) — faqat ko'rish, bo'sh bo'lsa umuman chiqmaydi.
class ExtrasToday extends StatelessWidget {
  final String uid;
  final String day;
  final bool readOnly;
  const ExtrasToday({super.key, required this.uid, required this.day, this.readOnly = false});

  Future<void> _add(BuildContext context) async {
    final e = await showExtraFoodSheet(context);
    if (e == null) return;
    try {
      await Db.addExtra(uid, day, e);
    } catch (err) {
      if (context.mounted) showSnack(context, trf('Amalga oshmadi: {0}', [apiErrorText(err)]));
    }
  }

  Future<void> _remove(BuildContext context, ExtraFood e) async {
    final ok = await confirm(
      context,
      title: tr("Ro'yxatdan olib tashlash"),
      message: trf('"{0}" olib tashlansinmi?', [tr(e.name)]),
      ok: tr('Olib tashlash'),
      destructive: true,
    );
    if (ok) await Db.removeExtra(uid, day, e);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return StreamBuilder<List<ExtraFood>>(
      stream: Db.extras(uid, day),
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error, compact: true);
        final list = snap.data ?? const <ExtraFood>[];
        if (readOnly && list.isEmpty) return const SizedBox.shrink();
        final total = ExtraFood.totalKcal(list).round();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(
            tr('Rejadan tashqari'),
            eyebrow: list.isEmpty ? tr('Bugun') : trf('Bugun · {0} kkal', [total]),
            trailing: readOnly
                ? null
                : TextButton.icon(
                    onPressed: () => _add(context),
                    icon: const Icon(Icons.add),
                    label: Text(tr('Yedim')),
                  ),
          ),
          if (list.isEmpty)
            Text(
              tr("Rejada yo'q narsa yesangiz, shu yerga qo'shing — kunlik hisob to'g'ri chiqadi."),
              style: t.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          for (final e in list)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: BentoTile(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
                child: Row(children: [
                  FoodImage(name: e.name, size: 36),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr(e.name),
                          style: t.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        trf('{0} g  ·  {1} kkal  ·  {2} g oqsil',
                            [fmtNum(e.grams), e.kcal.round(), fmtNum(e.protein)]),
                        style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                      ),
                    ]),
                  ),
                  if (!readOnly)
                    IconButton(
                      tooltip: tr('Olib tashlash'),
                      onPressed: () => _remove(context, e),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                ]),
              ),
            ),
          // trener kartasida keyingi blokdan ajralib tursin
          if (readOnly) const SizedBox(height: AppSpace.sm),
        ]);
      },
    );
  }
}
