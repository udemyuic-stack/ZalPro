import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/gym.dart' show weekdayNames, weekdayShort;
import '../../models/models.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/food_image.dart';
import '../../widgets/plan_photo.dart';
import '../../widgets/ui.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  void _open(BuildContext context, [Plan? p]) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => PlanEditor(initial: p)));

  /// Qaysi shablondan boshlashni pastdan chiquvchi varaqda tanlash
  Future<void> _pickTemplate(BuildContext context) async {
    final t = Theme.of(context).textTheme;
    final groups = <String, List<Plan>>{};
    for (final p in planTemplates()) {
      groups.putIfAbsent(p.category, () => []).add(p);
    }
    final plan = await showSheet<Plan>(
      context,
      ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: ListView(shrinkWrap: true, children: [
          Text(tr('Shablonni tanlang'), style: t.titleLarge),
          for (final g in groups.entries) ...[
            const SizedBox(height: AppSpace.lg),
            Eyebrow(g.key),
            const SizedBox(height: AppSpace.sm),
            for (final p in g.value)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.restaurant_menu),
                  title: Text(p.title.substring(g.key.length).replaceFirst(' • ', '')),
                  subtitle: Text(p.meals.isEmpty && !p.isWeekly
                      ? tr("Faqat maslahatlar — mahallarni o'zingiz qo'shasiz")
                      : trf(
                          '{0}{1} mahal • '
                          "{2} kkal{3} • "
                          '{4} g oqsil',
                          [
                              p.isWeekly ? tr("Haftalik (7 kun) • ") : "",
                              p.mealsPerDay,
                              p.kcal.round(),
                              p.isWeekly ? tr(' (o‘rtacha)') : '',
                              p.protein.round()
                            ])),
                  onTap: () => Navigator.pop(context, p),
                ),
              ),
          ],
        ]),
      ),
    );
    if (plan != null && context.mounted) _open(context, plan);
  }

  Future<void> _delete(BuildContext context, Plan p) async {
    final ok = await confirm(
      context,
      title: tr("Rejani o'chirish"),
      message: trf(
          '"{0}" butunlay o\'chiriladi. Unga biriktirilgan mijozlar rejasiz qoladi.', [p.title]),
      ok: tr("O'chirish"),
      destructive: true,
    );
    if (!ok) return;
    await Db.deletePlan(p.id);
    if (context.mounted) showSnack(context, tr("Reja o'chirildi"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context),
        icon: const Icon(Icons.add),
        label: Text(tr('Yangi reja')),
      ),
      body: StreamBuilder<List<Plan>>(
        stream: Db.plans(),
        builder: (context, snap) {
          // Xatoni ko'rsatamiz — aks holda ekran cheksiz "yuklanmoqda" bo'lib turadi
          if (snap.hasError) return ErrorState(error: snap.error);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final plans = snap.data!;
          if (plans.isEmpty) {
            return EmptyState(
              icon: Icons.menu_book_outlined,
              title: tr("Hali reja yo'q"),
              subtitle: tr('Aura Fit zal shablonidan boshlang yoki yangi reja tuzing.'),
              action: FilledButton.icon(
                onPressed: () => _pickTemplate(context),
                icon: const Icon(Icons.auto_awesome),
                label: Text(tr('Shablondan boshlash')),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              SectionHeader(
                trf('{0} ta reja', [plans.length]),
                trailing: TextButton.icon(
                  onPressed: () => _pickTemplate(context),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(tr('Shablon')),
                ),
              ),
              for (final p in plans)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PlanCard(
                    plan: p,
                    onOpen: () => _open(context, p),
                    onCopy: () => _open(
                      context,
                      Plan(
                        title: trf('{0} (nusxa)', [p.title]),
                        note: p.note,
                        meals: p.meals,
                        week: p.week,
                        photos: p.photos,
                        forbidden: p.forbidden,
                      ),
                    ),
                    onDelete: () => _delete(context, p),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Plan plan;
  final VoidCallback onOpen, onCopy, onDelete;
  const _PlanCard({
    required this.plan,
    required this.onOpen,
    required this.onCopy,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconBadge(Icons.restaurant_menu, color: s.primary, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(plan.title), style: t.titleMedium),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (plan.isWeekly)
                    Pill(
                      text: tr('Haftalik · 7 kun'),
                      color: AppColors.accent,
                      icon: Icons.calendar_view_week_outlined,
                    ),
                  Pill(
                    text: trf('{0} mahal', [plan.mealsPerDay]),
                    color: s.primary,
                    icon: Icons.schedule,
                  ),
                  Pill(
                    text: trf('{0} kkal', [plan.kcal.round()]),
                    color: AppColors.warning,
                    icon: Icons.local_fire_department_outlined,
                  ),
                  Pill(
                    text: trf('{0} g oqsil', [plan.protein.round()]),
                    color: AppColors.protein,
                    icon: Icons.egg_alt_outlined,
                  ),
                ]),
              ]),
            ),
            PopupMenuButton<String>(
              tooltip: tr('Amallar'),
              onSelected: (v) => v == 'copy' ? onCopy() : onDelete(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'copy',
                  child: ListTile(
                    leading: const Icon(Icons.copy_outlined),
                    title: Text(tr('Nusxa olish')),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: Text(tr("O'chirish")),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class PlanEditor extends StatefulWidget {
  final Plan? initial;
  const PlanEditor({super.key, this.initial});
  @override
  State<PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<PlanEditor> {
  /// Kategoriya (Ozish / Massa nabor) — reja faqat shu maqsaddagi shogirdlarga beriladi.
  /// Sarlavhada "Kategoriya • nomi" ko'rinishida saqlanadi (Plan.category).
  late String _category =
      planCategories.contains(widget.initial?.category) ? widget.initial!.category : '';
  late final _title = TextEditingController(
    text: _category.isEmpty
        ? widget.initial?.title
        : widget.initial!.title.substring(_category.length).replaceFirst(RegExp(r'^\s*•\s*'), ''),
  );
  late final _note = TextEditingController(text: widget.initial?.note);
  late final _forbidden = TextEditingController(text: widget.initial?.forbidden.join(', '));
  late final List<Meal> _meals = List.of(widget.initial?.meals ?? []);

  /// Hafta kunlari menyusi (1 — dushanba ... 7 — yakshanba). Bo'sh — reja har kuni bir xil.
  late final Map<int, List<Meal>> _week = {
    for (final e in (widget.initial?.week ?? const <int, List<Meal>>{}).entries)
      e.key: List.of(e.value),
  };

  /// Kun rasmlari (trener bergan ratsion rasmi) — tahrirda saqlanib qoladi
  late final Map<int, String> _photos = {...?widget.initial?.photos};

  /// Haftalik rejada — hozir tahrirlanayotgan kun
  int _day = DateTime.now().weekday;
  bool _saving = false;

  bool get _weekly => _week.isNotEmpty;

  /// O'zgartirishlar shu ro'yxatga tushadi: haftalik bo'lsa tanlangan kun, aks holda asosiy menyu
  List<Meal> get _current => _weekly ? (_week[_day] ??= []) : _meals;

  bool get _isNew => (widget.initial?.id ?? '').isEmpty;
  double get _kcal => _current.fold(0, (s, m) => s + m.kcal);
  double get _protein => _current.fold(0, (s, m) => s + m.protein);

  /// Haftalikka o'tkazish: hozirgi menyu 7 kunga nusxalanadi.
  /// O'chirilganda — tanlangan kun menyusi asosiy menyu bo'lib qoladi.
  Future<void> _setWeekly(bool on) async {
    if (on) {
      setState(() {
        for (var d = 1; d <= 7; d++) {
          _week[d] = [for (final m in _meals) Meal(time: m.time, title: m.title, items: m.items)];
        }
        _day = DateTime.now().weekday;
      });
      return;
    }
    final ok = await confirm(
      context,
      title: tr('Haftalik menyuni bekor qilish'),
      message: trf(
          '{0} menyusi qoladi va har kuni shu ko\'rsatiladi. '
          'Boshqa kunlarning menyusi o\'chadi.',
          [tr(weekdayNames[_day] ?? '')]),
      ok: tr('Bekor qilish'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() {
      final keep = List.of(_current);
      _week.clear();
      _meals
        ..clear()
        ..addAll(keep);
    });
  }

  /// Shu kun menyusini qolgan 6 kunga nusxalash
  Future<void> _copyDayToAll() async {
    final ok = await confirm(
      context,
      title: tr('Boshqa kunlarga nusxalash'),
      message: trf(
          '{0} menyusi qolgan 6 kunga ko\'chiriladi '
          'va ularning hozirgi menyusi o\'chadi.',
          [tr(weekdayNames[_day] ?? '')]),
      ok: tr('Nusxalash'),
    );
    if (!ok || !mounted) return;
    setState(() {
      final src = _current;
      for (var d = 1; d <= 7; d++) {
        if (d == _day) continue;
        _week[d] = [for (final m in src) Meal(time: m.time, title: m.title, items: m.items)];
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _forbidden.dispose();
    super.dispose();
  }

  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _editMealHeader([int? index]) async {
    final m = index != null ? _current[index] : null;
    var time = m?.time ?? '07:00';
    final title = TextEditingController(text: m?.title ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(m == null ? tr("Mahal qo'shish") : tr('Mahalni tahrirlash')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: tr('Nomi'), hintText: tr('Nonushta')),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final p = time.split(':');
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay(
                      hour: int.tryParse(p.first) ?? 7,
                      minute: p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0,
                    ),
                    builder: (c, child) => MediaQuery(
                      data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
                      child: child!,
                    ),
                  );
                  if (picked != null) setD(() => time = _hhmm(picked));
                },
                icon: const Icon(Icons.schedule),
                label: Text(trf('Vaqt: {0}', [time])),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Bekor'))),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() {
      final meal = Meal(time: time, title: title.text.trim(), items: m?.items ?? []);
      final list = _current;
      if (index == null) {
        list.add(meal);
      } else {
        list[index] = meal;
      }
      list.sort((a, b) => a.time.compareTo(b.time));
    });
  }

  Future<void> _removeMeal(int index) async {
    final ok = await confirm(
      context,
      title: tr("Mahalni o'chirish"),
      message: trf('"{0}" va undagi mahsulotlar olib tashlanadi.', [_current[index].title]),
      ok: tr("O'chirish"),
      destructive: true,
    );
    if (ok && mounted) setState(() => _current.removeAt(index));
  }

  Future<void> _addItem(int mealIndex) async {
    final foods = await Db.foods().first;
    if (!mounted) return;
    if (foods.isEmpty) {
      showSnack(context, tr("Avval 'Mahsulotlar' bo'limida mahsulot qo'shing"));
      return;
    }
    Food? selected = foods.first;
    final grams = TextEditingController(text: '100');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(tr("Mahsulot qo'shish")),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<Food>(
              initialValue: selected,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('Mahsulot')),
              items: foods
                  .map((f) => DropdownMenuItem(
                        value: f,
                        child: Row(children: [
                          FoodImage(name: f.name, url: f.image, size: 32),
                          const SizedBox(width: AppSpace.md),
                          Expanded(child: Text(tr(f.name), overflow: TextOverflow.ellipsis)),
                        ]),
                      ))
                  .toList(),
              onChanged: (v) => setD(() => selected = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: grams,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr('Miqdori'), suffixText: 'g'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Bekor'))),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr("Qo'shish")),
            ),
          ],
        ),
      ),
    );
    final g = double.tryParse(grams.text.replaceAll(',', '.'));
    if (ok != true || selected == null || g == null || g <= 0) return;
    setState(() {
      final list = _current;
      final m = list[mealIndex];
      list[mealIndex] = Meal(
        time: m.time,
        title: m.title,
        items: [...m.items, MealItem.fromFood(selected!, g)],
      );
    });
  }

  void _removeItem(int mealIndex, int itemIndex) {
    setState(() {
      final list = _current;
      final m = list[mealIndex];
      final items = List.of(m.items)..removeAt(itemIndex);
      list[mealIndex] = Meal(time: m.time, title: m.title, items: items);
    });
  }

  Future<void> _save() async {
    if (_category.isEmpty) {
      showSnack(context, tr('Kategoriyani tanlang: Ozish yoki Massa nabor'));
      return;
    }
    if (_title.text.trim().isEmpty) {
      showSnack(context, tr('Reja nomini kiriting'));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await Db.savePlan(Plan(
        id: widget.initial?.id ?? '',
        title: '$_category • ${_title.text.trim()}',
        note: _note.text.trim(),
        // haftalik rejada asosiy menyu — dushanba nusxasi (eski ilova versiyalari uchun)
        meals: _weekly ? List.of(_week[1] ?? _current) : _meals,
        week: _week,
        photos: _photos,
        forbidden:
            _forbidden.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      ));
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(tr('Reja saqlandi'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? tr('Yangi reja') : tr('Rejani tahrirlash')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check, size: 18),
              label: Text(tr('Saqlash')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editMealHeader(),
        icon: const Icon(Icons.add),
        label: Text(tr("Mahal qo'shish")),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          Row(children: [
            Expanded(
              child: StatTile(
                icon: Icons.local_fire_department_outlined,
                label: _weekly
                    ? trf('{0} · kaloriya', [tr(weekdayShort[_day] ?? '')])
                    : tr('Jami kaloriya'),
                value: trf('{0} kkal', [_kcal.round()]),
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: StatTile(
                icon: Icons.egg_alt_outlined,
                label: tr('Oqsil'),
                value: trf('{0} g', [_protein.round()]),
                color: AppColors.protein,
              ),
            ),
          ]),
          if (_kcal > 0 && _kcal < 1200) ...[
            const SizedBox(height: AppSpace.md),
            Card(
              color: s.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: s.onErrorContainer),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Text(
                      tr("Reja 1200 kkal dan kam. Ko'pchilik uchun bu xavfli darajada past."),
                      style: TextStyle(color: s.onErrorContainer),
                    ),
                  ),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Eyebrow(tr('Kategoriya')),
          const SizedBox(height: AppSpace.sm),
          Wrap(spacing: AppSpace.sm, children: [
            for (final c in planCategories)
              ChoiceChip(
                label: Text(tr(c)),
                selected: _category == c,
                onSelected: (_) => setState(() => _category = c),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: tr('Reja nomi'),
              prefixIcon: const Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _forbidden,
            decoration: InputDecoration(
              labelText: tr('Mumkin emas (vergul bilan)'),
              hintText: tr('Non, shirinlik, ...'),
              prefixIcon: const Icon(Icons.block),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: tr('Izoh / maslahat'),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _weekly,
            onChanged: _setWeekly,
            title: Text(tr('Har kunga alohida menyu')),
            subtitle: Text(
              _weekly
                  ? tr("Hafta kunlari bo'yicha 7 xil menyu — shogirdda o'sha kunniki chiqadi")
                  : tr('Hozir reja har kuni bir xil'),
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          if (_weekly) ...[
            const SizedBox(height: AppSpace.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (var d = 1; d <= 7; d++)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpace.sm),
                    child: ChoiceChip(
                      selected: _day == d,
                      onSelected: (_) => setState(() => _day = d),
                      label: Text(tr(weekdayShort[d]!)),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: AppSpace.sm),
            Row(children: [
              Expanded(
                child: Text(
                  trf('{0} menyusi', [tr(weekdayNames[_day] ?? '')]),
                  style: t.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: _copyDayToAll,
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: Text(tr('Hamma kunga')),
              ),
            ]),
            // Shu kunning rasmi — shogirdga ham shu ko'rinadi
            if (_photos[_day] case final photo? when photo.isNotEmpty) ...[
              const SizedBox(height: AppSpace.sm),
              PlanPhoto(
                path: photo,
                height: 170,
                caption: tr("Shogird shu rasmni ko'radi"),
              ),
              const SizedBox(height: AppSpace.sm),
            ],
          ],
          SectionHeader(trf('Ovqatlanish mahallari ({0})', [_current.length])),
          if (_current.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr("Hali mahal yo'q. Pastdagi \"Mahal qo'shish\" tugmasini bosing."),
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant),
                ),
              ),
            ),
          for (var i = 0; i < _current.length; i++)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: _mealCard(i, _current[i])),
        ],
      ),
    );
  }

  Widget _mealCard(int mi, Meal m) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: s.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(m.time,
                  style: t.titleSmall
                      ?.copyWith(color: s.onPrimaryContainer, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.title.isEmpty ? tr('Nomsiz') : m.title, style: t.titleMedium),
                Text(trf('{0} kkal • {1} g oqsil', [m.kcal.round(), m.protein.round()]),
                    style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
              ]),
            ),
            IconButton(
              tooltip: tr('Tahrirlash'),
              onPressed: () => _editMealHeader(mi),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: tr("O'chirish"),
              onPressed: () => _removeMeal(mi),
              icon: const Icon(Icons.delete_outline),
            ),
          ]),
          if (m.items.isNotEmpty) const Divider(height: 20),
          for (var ii = 0; ii < m.items.length; ii++)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(children: [
                FoodImage(name: m.items[ii].name, url: m.items[ii].image, size: 36),
                const SizedBox(width: AppSpace.md),
                Expanded(child: Text(tr(m.items[ii].name), style: t.bodyMedium)),
                Text(trf('{0} g', [m.items[ii].grams.round()]),
                    style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                SizedBox(
                  width: 64,
                  child: Text(trf('{0} kkal', [m.items[ii].kcal.round()]),
                      textAlign: TextAlign.right,
                      style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
                ),
                IconButton(
                  tooltip: tr('Olib tashlash'),
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _removeItem(mi, ii),
                ),
              ]),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addItem(mi),
              icon: const Icon(Icons.add),
              label: Text(tr("Mahsulot qo'shish")),
            ),
          ),
        ]),
      ),
    );
  }
}

MealItem _i(String name, double g, double kcal100, double p100) =>
    MealItem(name: name, grams: g, kcal: kcal100 * g / 100, protein: p100 * g / 100);

/// "Shablon" tugmasida tanlanadigan tayyor rejalar.
/// Varaqda kategoriya bo'yicha guruhlanadi (Plan.category: Ozish, Massa nabor).
List<Plan> planTemplates() => [
      diamondTemplate(),
      ozish60to75Template(),
      massaNabor1Template(),
      massaNabor2Template(),
      massaNabor3Template(),
    ];

/// Massa nabor 3-versiya — trenerning kaloriya va massa bo'yicha maslahatlari
/// (ikki rasm matni to'liq). Rasmlarda ovqat jadvali yo'q — mahallarni trener qo'shadi.
Plan massaNabor3Template() => Plan(
      title: "Massa nabor • 3-versiya (maslahatlar)",
      note: "KALORIYALARNI HISOBLASHNI O'RGANAMIZ\n\n"
          "Eslab qoling: kaloriya 1 kg vaznga nisbatan olinadi va shu grammni o'z "
          "vazningizga ko'paytirasiz. Ya'ni 70 kg bo'lsangiz, quyida berilgan raqamlarga "
          "ko'paytirib, kunlik kaloriyani chiqarib olasiz:\n"
          "• Ayollar uchun, moddalar almashinuvi sekin bo'lsa — 31\n"
          "• Ayollar uchun, moddalar almashinuvi tez bo'lsa — 33\n"
          "• Erkaklar uchun, moddalar almashinuvi sekin bo'lsa — 33\n"
          "• Erkaklar uchun, moddalar almashinuvi tez bo'lsa — 35\n"
          "(Masalan: erkak, 70 kg, metabolizmi sekin — 70 × 33 = 2310 kkal.)\n\n"
          "Endi moddalar almashinuvi haqida gapirsak — «Alisher, bu nima?» degan savol "
          "keldi, to'g'rimi? Moddalar almashinuvi hamma insonda bo'ladi, u ruschada "
          "«metabolizm». Ya'ni siz ovqatlandingiz — organizm tezda hazm qilib, yana talab "
          "qiladi; yoki teskarisi — juda sekin hazm bo'lib, kuniga 2 mahalgina ovqat "
          "yeydigan bo'lib qolasiz. Shunga qarab metabolizm tez yoki sekinligini ajratsangiz "
          "bo'ladi!\n\n"
          "Metabolizmni tezlatish uchun to'g'ri ovqatlanish va kichkina porsiyada har 2 soatda "
          "ovqatlanib turish kerak — organizm kodlanadi, xuddi mashinaga proshivka "
          "qilingandek, va tezlashadi!\n\n"
          "«Tezlashish bizga nimaga kerak?» deysiz, to'g'rimi? Lekin metabolizm tez bo'lsa, "
          "organizmingiz ortiqcha yog'larni o'zi ishlatadi va yoqadi, tanangiz relyef "
          "ko'rinishda bo'ladi. Kim xohlamaydi deysiz bunaqa tanani?\n\n"
          "KALORIYANI QANDAY ANIQLAYMIZ?\n\n"
          "Misol uchun, bitta gamburgerning kaloriyasi bilan guruch va tovuqning kaloriyasini "
          "solishtiramiz — taxminan internetdan yozib aniqlasangiz bo'ladi. Misol: "
          "gamburgerda 100 g da 374 kkal bor. Guruch va tovuqda 250 kkal bor. Endi farqini "
          "ko'radigan bo'lsak: guruch va tovuqda juda kerakli sekin singuvchi uglevodlar va "
          "oqsillar bor, gamburgerda esa tez singuvchi uglevodlar va xolesterin. O'zingiz "
          "ko'rishingiz mumkin — pastdagi jadvalda.\n\n"
          "MUSKUL MASSASI YIG'ISH (NABOR) UCHUN\n\n"
          "Hamma massa oladiganlarga tegishli bo'lgan maslahat: agar siz muskul massasini "
          "olmoqchi bo'lsangiz, kunlik ratsionda uglevod va kaloriyani ko'paytirish kerak. "
          "Bu degani — xohlaganingizcha ovqat yemaysiz, balki to'g'ri ratsion tuzamiz. "
          "Misol uchun: siz yog'li semirishni xohlaysizmi yoki chiroyli mushak qomatinimi? "
          "Albatta mushak qomati, lekin bu darajaga erishish uchun ozgina o'zingizni "
          "qiynashingizga to'g'ri keladi!\n\n"
          "Uglevodlarni iste'mol qilganingizda sekin singuvchi uglevodlarni tanlab oling. "
          "Bu mahsulotlar: guruch, grechka, 2-sort makaron, ovsyanka va gerkules bo'tqalari. "
          "Bu mahsulotlarning hammasi do'konda bor!\n\n"
          "Kokteyl ko'rinishidagi uglevodlar — asosan gainerlar, ya'ni sport qo'shimchalari; "
          "uy sharoitida ham tayyorlasangiz bo'ladi. Ko'pincha bu mahsulotlarni "
          "mashg'ulotdan oldin va keyin tezda iste'mol qilganingiz ma'qul. Sababi: boshqa "
          "payt iste'mol qilsangiz, uglevodlari tez singuvchi bo'lgani uchun ortiqcha yog' "
          "berishi mumkin. Tez singuvchi uglevodlar muskul tolalari ochiq bo'lgan paytda "
          "keraklicha energiya beradi!\n\n"
          "Yog'lar massa naborda kerak bo'ladi, lekin keragidan yuqori darajada emas. Agar "
          "kerakli yog'larni iste'mol qilmasangiz, gormonlaringizdan testosteronni oshira "
          "olmaysiz. Testosteron — muskulning o'sishi, tiklanishi, umuman olganda erkakni "
          "erkak qiladigan gormon hisoblanadi!\n\n"
          "SEKIN SINGUVCHI UGLEVODLAR INDEKSI (100 g da)\n"
          "• Guruch — 78,9 g uglevod — 349 kkal\n"
          "• Grechka — 69,2 g uglevod — 349 kkal\n"
          "• Ovsyanka yormasi — 67,8 g uglevod — 349 kkal\n"
          "• No'xat mahsulotlari — 60,2 g uglevod\n"
          "• Makaron (2 va 3-sort undan) — 52–62 g uglevod — 368 kkal\n\n"
          "MAHALLAR HAQIDA\n"
          "Quyidagi mahallar yuqoridagi maslahatlar asosida tuzilgan (porsiyalar taxminiy): "
          "har 2–3 soatda kichik porsiya, sekin singuvchi uglevodlar, gainer mashg'ulotdan "
          "oldin va keyin, yog' me'yorida.",
      meals: [
        Meal(time: '07:00', title: 'Nonushta', items: [
          _i("Ovsyanka yoki gerkules bo'tqasi (quruq vazni)", 80, 349, 12.5),
          _i('Qaynatilgan tuxum (2 dona)', 100, 155, 13),
          _i("Yong'oq", 20, 654, 15),
        ]),
        Meal(time: '09:30', title: '2-nonushta', items: [
          _i('Tvorog', 150, 121, 17),
          _i('Banan', 120, 87.5, 1.1),
        ]),
        Meal(time: '12:00', title: 'Tushlik', items: [
          _i('Guruch (quruq vazni)', 100, 349, 7),
          _i("Tovuq ko'kragi", 150, 165, 31),
          _i("Salat (o'simlik yog'i bilan)", 150, 20, 1),
          _i("O'simlik yog'i", 10, 884, 0),
        ]),
        Meal(time: '15:00', title: "Mashg'ulotdan oldin", items: [
          _i('Gainer (1 porsiya)', 60, 380, 20),
          _i('Banan', 120, 87.5, 1.1),
        ]),
        Meal(time: '17:30', title: "Mashg'ulotdan keyin", items: [
          _i('Gainer yoki protein kokteyl (1 porsiya)', 60, 380, 20),
        ]),
        Meal(time: '20:00', title: 'Kechki ovqat', items: [
          _i('Grechka yoki 2-sort makaron (quruq vazni)', 80, 349, 12.6),
          _i("Mol go'shti", 150, 190, 27),
          _i('Yangi salat', 150, 20, 1),
        ]),
      ],
    );

/// Massa nabor 1-versiya — trener matnidagi grammlar bilan (4 mahal)
Plan massaNabor1Template() => Plan(
      title: 'Massa nabor • 1-versiya (grammli)',
      note: "Maqsad: mushak massasini oshirish va ortiqcha yog' to'planishining oldini olish. "
          "Kunlik norma 2700–2900 kkal; rejadagi mahsulotlar ~2540 kkal beradi — "
          "kerak bo'lsa porsiyalarni biroz kattalashtiring.\n"
          "Oqsil, uglevod va yog'lar muvozanatlangan.\n"
          "21:00 dagi tamaddi — sport zal kuni uchun.",
      meals: [
        Meal(time: '07:30', title: 'Nonushta', items: [
          _i('Qaynatilgan tuxum (2 dona)', 100, 140, 12.6),
          _i('Suli yormasi (ovsyanka)', 100, 350, 12.5),
          _i('Banan (1 dona)', 120, 87.5, 1.1),
          _i('Sut (250 ml)', 250, 50, 3.2),
          _i('Bodom', 30, 600, 21),
        ]),
        Meal(time: '13:00', title: 'Tushlik', items: [
          _i('Qaynatilgan grechka', 150, 110, 3.6),
          _i("Qaynatilgan tovuq go'shti", 150, 165, 31),
          _i('Brokkoli yoki gulkaram', 150, 33, 2.8),
          _i("Yong'oq", 30, 650, 15),
        ]),
        Meal(time: '18:00', title: 'Kechki ovqat', items: [
          _i("Qaynatilgan mol go'shti", 150, 250, 26),
          _i("Qaynatilgan no'xat", 150, 120, 8.3),
          _i('Banan yoki boshqa meva', 120, 87.5, 1.1),
        ]),
        Meal(time: '21:00', title: 'Tamaddi (sport zal kuni)', items: [
          _i("Yong'oq", 30, 650, 15),
          _i('Sut (250 ml)', 250, 50, 3.2),
        ]),
      ],
    );

/// Massa nabor 2-versiya — tanlovli ro'yxat (6 mahal). Trener matnida gramm yo'q,
/// porsiyalar taxminiy qo'yilgan — trener tahrirlaydi.
Plan massaNabor2Template() => Plan(
      title: 'Massa nabor • 2-versiya (tanlovli)',
      note: "Har mahalda ro'yxatdagi mahsulotlardan birini tanlab almashtirsa bo'ladi.\n"
          'Shokolad — shakari kam bo\'lsin.\n'
          "Kechki go'shtni kungaboqar yog'ida pishirsa ham bo'ladi.\n"
          'Yotishdan oldin: meva va qaynagan (iliq) suvga yarimta limon siqib ichiladi.\n'
          "Nonushtada suli bo'tqasi o'rniga guruch / grechka / makaron / manniy bo'tqasi ham "
          "bo'ladi. 2-nonushta va poldnikda protein kokteyl yoki kefir/yogurt — birini tanlang.\n"
          "Porsiyalar taxminiy (~2700 kkal, ~200 g oqsil) — mijozga qarab o'zgartiring.",
      meals: [
        Meal(time: '07:30', title: 'Nonushta', items: [
          _i("Suli bo'tqasi (yoki guruch / grechka / makaron / manniy, quruq)", 80, 370, 13),
          _i('Tvorog (150–200 g)', 150, 160, 17),
          _i('Tuxum oqi (4 dona)', 132, 52, 11),
          _i('Pishloq (sir)', 30, 350, 25),
        ]),
        Meal(time: '10:30', title: '2-nonushta', items: [
          _i('Meva: banan / olma / kivi yoki boshqa', 200, 70, 0.8),
          _i('Protein kokteyl (1 porsiya)', 30, 370, 88),
          _i('Shokolad (shakari kam)', 20, 550, 7),
        ]),
        Meal(time: '13:00', title: 'Tushlik', items: [
          _i("Tovuq ko'kragi (grill) / bifshteks / mol go'shti / baliq", 150, 165, 31),
          _i("Qaynatilgan: guruch / grechka / kartoshka / makaron / perlovka / no'xat", 300, 120,
              3.5),
        ]),
        Meal(time: '16:00', title: 'Poldnik', items: [
          _i('Kefir yoki yogurt', 250, 55, 3),
          _i('Meva yoki banan', 150, 70, 0.8),
          _i('Yangi salat', 150, 20, 1),
        ]),
        Meal(time: '19:00', title: 'Kechki ovqat', items: [
          _i('Qaynatilgan: guruch / grechka / makaron', 250, 120, 3.5),
          _i("Baliq yoki mol go'shti", 150, 200, 26),
          _i('Yangi salat', 200, 20, 1),
        ]),
        Meal(time: '22:00', title: 'Yotishdan oldin', items: [
          _i('Meva', 150, 70, 0.8),
          _i('Iliq suv + yarimta limon', 250, 3, 0),
        ]),
      ],
    );

/// Ozish 2-versiya — 60, 65 va 75 kg li mijozlar uchun (Aura Fit zal, taxminiy kaloriyalar)
Plan ozish60to75Template() => Plan(
      title: 'Ozish • 60 / 65 / 75 kg (2-versiya)',
      note: "Ozish uchun — 75 kg, 65 kg va 60 kg li insonlar uchun. Aura Fit zal.\n\n"
          "Nonushta: ovsyanka bo'tqasi 50 g va tuxum omleti — piyoz bilan aralashtirib, "
          "soya yog'ida qovurilsa bo'ladi. 2 dona tuxum, 1 tasining sarig'ini olib tashlaymiz.\n\n"
          "10:30 — keyingi nonushta: 50 g yong'oq va meva (olma) yoki 1 porsiya protein.\n\n"
          "12:30 — tushlik: 50 g grechka yoki guruch, yonida kotlet yoki go'sht yoki "
          "qaynatilgan 4 ta tuxum oqi. Go'shtlarning grammi — 150 g norma.\n\n"
          "16:00 — poldnik: 1 porsiya protein. Agar mashg'ulot bo'lsa — faqat 50 g grechkaning "
          "o'zini qaynatib, ustiga qatiq, ya'ni kefir qo'shib aralashtirib yeysiz.\n\n"
          "Mashg'ulotdan keyin yana 1 porsiya protein. Qo'rqmang, zarari yo'q — protein "
          "oddiy oqsil qo'shimchasi.\n\n"
          "19:00 — kechki ovqat: salat (ko'katlar, pomidor, bodring, bolgar qalampiri) va "
          "baliq 150 g, yoki go'sht dimlangan holda.\n\n"
          "Bundan tashqari, sport qo'shimchalaridan vitamin komplekslar va protein "
          "olishingiz shart.",
      forbidden: [
        'Shakar',
        'Shirinliklar',
        'Non',
        'Hamirli ovqatlar',
        'Mayonezli salat',
        'Sharbatlar',
        'Tez singuvchi uglevodlar',
      ],
      meals: [
        Meal(time: '07:00', title: 'Nonushta', items: [
          _i('Suli yormasi (ovsyanka)', 50, 370, 13),
          _i("Tuxum omleti: 2 dona, 1 tasining sarig'i olib tashlanadi", 83, 113, 12),
          _i('Piyoz (omletga aralashtiriladi)', 30, 40, 1.1),
          _i("Soya yog'i (qovurish uchun)", 5, 884, 0),
        ]),
        Meal(time: '10:30', title: '2-nonushta', items: [
          _i("Yong'oq (yoki hammasi o'rniga 1 porsiya protein)", 50, 654, 15),
          _i('Meva — olma', 100, 52, 0.3),
        ]),
        Meal(time: '12:30', title: 'Tushlik', items: [
          _i('Grechka yoki guruch', 50, 345, 10),
          _i("Kotlet yoki go'sht — 150 g norma (yoki 4 ta qaynatilgan tuxum oqi)", 150, 190, 27),
        ]),
        Meal(time: '16:00', title: 'Poldnik', items: [
          _i("Protein, 1 porsiya (mashg'ulot bo'lsa: 50 g grechka + kefir)", 30, 370, 88),
        ]),
        Meal(time: '17:30', title: "Mashg'ulotdan keyin", items: [
          _i('Protein (1 porsiya)', 30, 370, 88),
        ]),
        Meal(time: '19:00', title: 'Kechki ovqat', items: [
          _i("Salat: ko'katlar, pomidor, bodring, bolgar qalampiri", 200, 20, 1),
          _i("Baliq 150 g (yoki dimlangan go'sht)", 150, 130, 25),
        ]),
      ],
    );

/// Diamond zal rejasi asosidagi shablon (taxminiy kaloriyalar)
Plan diamondTemplate() => Plan(
      title: 'Ozish • 80-90 kg (asosiy)',
      note: "Ayol yoki erkak — farqi yo'q, faqat to'g'ri ovqatlanish bilan ozasiz. "
          "Ovqatlanmaslik yoki kuniga 1 mahal ovqatlanish ozdirmaydi: organizm o'zini "
          "\"blokirovka\" qiladi va vazn ketmaydi. Kuniga 5 mahal ovqatlaning.\n"
          "Ko'proq oqsil va salat; tez singuvchi uglevodlar kerak emas. "
          "Kechqurun uglevodlarni iloji boricha olib tashlang.\n"
          "Kardio: 40 daqiqa velotrenajyor yoki yugurish yo'lakchasi, "
          "mashqdan keyin darhol protein kokteyli.\n"
          "Erkaklar va baland bo'yli mijozlar uchun porsiyalarni kattalashtiring.",
      forbidden: [
        'Shakar',
        'Shirinliklar',
        'Non',
        'Hamirli ovqatlar',
        'Mayonezli salat',
        'Shirin mevalar',
        'Sharbatlar',
        'Tez singuvchi uglevodlar',
      ],
      meals: [
        Meal(time: '07:00', title: 'Nonushta', items: [
          _i('Suli yormasi (suvda, shakarsiz)', 50, 370, 13),
          _i("Yong'oq", 10, 654, 15),
          _i('Olma yoki qulupnay (yoki ozgina mayiz)', 100, 52, 0.3),
          _i('Tuxum oqi (2 dona)', 66, 52, 11),
        ]),
        Meal(time: '10:30', title: '2-nonushta', items: [
          _i('Protein izolyat (yoki 100 g tvorog)', 30, 370, 88),
        ]),
        Meal(time: '13:00', title: 'Tushlik', items: [
          _i('Grechka (quruq vazni)', 50, 340, 13),
          _i("Go'sht (yog'siz, qaynatilgan yoki soya yog'ida dimlangan)", 100, 190, 27),
          _i('Pomidor, bodring, ko\'kat', 200, 18, 0.9),
        ]),
        Meal(time: '15:00', title: 'Poldnik', items: [
          _i("Yong'oq", 50, 654, 15),
        ]),
        Meal(time: '18:00', title: 'Kechki ovqat', items: [
          _i("Baliq / tovuq / mol go'shti (yoki 100 g fosol / noxat)", 150, 130, 25),
          _i('Pomidor, bodring, ko\'kat', 200, 18, 0.9),
          _i('Olma', 100, 52, 0.3),
        ]),
      ],
    );
