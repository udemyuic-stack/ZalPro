import 'package:flutter/material.dart';
import '../../core/input_rules.dart';
import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/food_image.dart';
import '../../widgets/food_photo_editor.dart';
import '../../widgets/ui.dart';

class FoodsScreen extends StatefulWidget {
  const FoodsScreen({super.key});

  static Future<void> edit(BuildContext context, [Food? f]) async {
    final name = TextEditingController(text: f?.name);
    final kcal = TextEditingController(text: f == null ? '' : fmtNum(f.kcal));
    final p = TextEditingController(text: f == null ? '' : fmtNum(f.protein));
    final fat = TextEditingController(text: f == null ? '' : fmtNum(f.fat));
    final c = TextEditingController(text: f == null ? '' : fmtNum(f.carbs));
    double n(TextEditingController t) => double.tryParse(t.text.replaceAll(',', '.')) ?? 0;

    final form = GlobalKey<FormState>();

    Widget field(TextEditingController ctl, String label, String suffix, int max) => TextFormField(
          controller: ctl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: InputRules.decimalOnly(),
          validator: InputRules.decimalRange(0, max, required: false),
          decoration: InputDecoration(labelText: label, suffixText: tr(suffix)),
        );

    final ok = await showSheet<bool>(
      context,
      Builder(
        builder: (ctx) => Form(
          key: form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(shrinkWrap: true, children: [
            Text(
              f == null ? tr("Mahsulot qo'shish") : tr('Mahsulotni tahrirlash'),
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpace.lg),
            TextFormField(
              controller: name,
              autofocus: f == null,
              maxLength: InputLimits.foodName,
              buildCounter: InputRules.counterAtEighty,
              validator: InputRules.required(InputLimits.foodName),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: tr('Nomi')),
            ),
            const SizedBox(height: 12),
            FoodPhotoEditor(food: f, name: name),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child:
                  Text(tr('100 gramm uchun:'), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: AppSpace.md),
            field(kcal, tr('Kaloriya'), 'kkal', InputLimits.kcalMax),
            const SizedBox(height: AppSpace.md),
            Row(children: [
              Expanded(child: field(p, tr('Oqsil'), 'g', InputLimits.macroMax)),
              const SizedBox(width: 8),
              Expanded(child: field(fat, tr("Yog'"), 'g', InputLimits.macroMax)),
              const SizedBox(width: 8),
              Expanded(child: field(c, tr('Uglevod'), 'g', InputLimits.macroMax)),
            ]),
            const SizedBox(height: AppSpace.xl),
            FilledButton(
              onPressed: () {
                if (InputRules.validateAndFocus(form)) Navigator.pop(ctx, true);
              },
              child: Text(tr('Saqlash')),
            ),
            const SizedBox(height: AppSpace.sm),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('Bekor')),
            ),
          ]),
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await Db.saveFood(Food(
        id: f?.id ?? '',
        name: name.text.trim(),
        kcal: n(kcal),
        protein: n(p),
        fat: n(fat),
        carbs: n(c),
      ));
    }
  }

  @override
  State<FoodsScreen> createState() => _FoodsScreenState();
}

class _FoodsScreenState extends State<FoodsScreen> {
  late final _stream = Db.foods();
  String _query = '';
  bool _seeding = false;

  Future<void> _seed() async {
    setState(() => _seeding = true);
    try {
      for (final f in defaultFoods) {
        await Db.saveFood(f);
      }
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  Future<void> _delete(Food f) async {
    final ok = await confirm(
      context,
      title: tr("Mahsulotni o'chirish"),
      message: trf('"{0}" bazadan o\'chirilsinmi? Mavjud rejalarga ta\'sir qilmaydi.', [f.name]),
      ok: tr("O'chirish"),
      destructive: true,
    );
    if (ok) await Db.deleteFood(f.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => FoodsScreen.edit(context),
        icon: const Icon(Icons.add),
        label: Text(tr('Mahsulot')),
      ),
      body: StreamBuilder<List<Food>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return ErrorState(error: snap.error);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final foods = snap.data!;
          if (foods.isEmpty) {
            return EmptyState(
              icon: Icons.restaurant_outlined,
              title: tr("Mahsulotlar bazasi bo'sh"),
              subtitle: trf(
                  "{0} ta asosiy mahsulotni (100 g uchun KBJU) "
                  "bir bosishda qo'shing.",
                  [defaultFoods.length]),
              action: FilledButton.icon(
                onPressed: _seeding ? null : _seed,
                icon: const Icon(Icons.download_outlined),
                label: Text(tr("Standart mahsulotlarni qo'shish")),
              ),
            );
          }
          final q = _query.trim().toLowerCase();
          final list = foods.where((f) => f.name.toLowerCase().contains(q)).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: tr('Mahsulot qidirish'),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 0, 6),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      trf("{0} ta mahsulot • O — oqsil, Y — yog', U — uglevod (100 g uchun)",
                          [list.length]),
                      style: t.bodySmall?.copyWith(color: s.onSurfaceVariant),
                    ),
                  ),
                  TextButton(
                    onPressed: () => showImageCredits(context),
                    child: Text(tr('Rasm manbalari')),
                  ),
                ]),
              ),
              for (final f in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FoodTile(
                    food: f,
                    onTap: () => FoodsScreen.edit(context, f),
                    onDelete: () => _delete(f),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FoodTile extends StatelessWidget {
  final Food food;
  final VoidCallback onTap, onDelete;
  const _FoodTile({required this.food, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = Theme.of(context).colorScheme;
    final f = food;
    return Card(
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        leading: FoodImage(name: f.name, url: f.imageUrl, size: 52),
        title: Text(tr(f.name), style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(spacing: 6, runSpacing: 4, children: [
            Pill(text: 'O ${fmtNum(f.protein)}', color: AppColors.protein),
            Pill(text: 'Y ${fmtNum(f.fat)}', color: AppColors.warning),
            Pill(text: 'U ${fmtNum(f.carbs)}', color: AppColors.water),
            // 0 kkal kiritilgan mahsulot rejaga qo'shilsa hisob noto'g'ri chiqadi
            if (f.kcal <= 0) Pill(text: tr('Kaloriya kiritilmagan'), color: AppColors.danger),
          ]),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${f.kcal.round()}', style: t.titleMedium),
            Text(tr('kkal'), style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
          ]),
          IconButton(
            tooltip: tr("O'chirish"),
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ]),
      ),
    );
  }
}

/// Taxminiy qiymatlar (100 g). Trener o'zgartirishi mumkin.
final defaultFoods = [
  Food(name: "Suli yormasi (ovsyanka), quruq", kcal: 370, protein: 13, fat: 7, carbs: 60),
  Food(name: 'Grechka, quruq', kcal: 340, protein: 13, fat: 3.4, carbs: 68),
  Food(name: 'Tuxum oqi', kcal: 52, protein: 11, fat: 0.2, carbs: 0.7),
  Food(name: 'Tuxum, butun', kcal: 155, protein: 13, fat: 11, carbs: 1.1),
  Food(name: 'Tvorog 5%', kcal: 121, protein: 17, fat: 5, carbs: 1.8),
  Food(name: 'Protein izolyat (kukun)', kcal: 370, protein: 88, fat: 1, carbs: 2),
  Food(name: 'Tovuq filesi', kcal: 165, protein: 31, fat: 3.6, carbs: 0),
  Food(name: "Mol go'shti, yog'siz", kcal: 190, protein: 27, fat: 9, carbs: 0),
  Food(name: 'Baliq filesi (oq baliq)', kcal: 100, protein: 20, fat: 2, carbs: 0),
  Food(name: "Loviya (fosol), qaynatilgan", kcal: 127, protein: 9, fat: 0.5, carbs: 23),
  Food(name: 'Noxat, qaynatilgan', kcal: 164, protein: 9, fat: 2.6, carbs: 27),
  Food(name: "Yong'oq", kcal: 654, protein: 15, fat: 65, carbs: 14),
  Food(name: 'Mayiz', kcal: 299, protein: 3, fat: 0.5, carbs: 79),
  Food(name: 'Olma', kcal: 52, protein: 0.3, fat: 0.2, carbs: 14),
  Food(name: 'Qulupnay', kcal: 32, protein: 0.7, fat: 0.3, carbs: 7.7),
  Food(name: 'Pomidor', kcal: 18, protein: 0.9, fat: 0.2, carbs: 3.9),
  Food(name: 'Bodring', kcal: 15, protein: 0.7, fat: 0.1, carbs: 3.6),
  Food(name: "Ko'kat", kcal: 30, protein: 2.5, fat: 0.5, carbs: 5),
  Food(name: "Soya yog'i", kcal: 884, protein: 0, fat: 100, carbs: 0),
];
