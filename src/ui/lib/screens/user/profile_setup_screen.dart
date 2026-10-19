import 'package:flutter/material.dart';
import '../../core/input_rules.dart';
import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';
import '../../services/api/api_error.dart';
import '../../services/api/poll_stream.dart';

class ProfileSetupScreen extends StatefulWidget {
  final AppUser user;
  final bool editing;
  final Stream<List<TrainerInfo>> Function()? trainerSource;
  const ProfileSetupScreen({
    super.key,
    required this.user,
    this.editing = false,
    this.trainerSource,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _form = GlobalKey<FormState>();
  late String _gender = widget.user.gender;
  late String _goal = widget.user.goal;
  late String _metabolism = widget.user.metabolism;
  late String? _trainerId = widget.user.trainerId;

  /// Trener faqat bir marta tanlanadi; keyin almashtirish — bosh admin orqali
  bool get _canChooseTrainer => widget.user.trainerId == null;
  List<TrainerInfo> _trainers = const [];
  late final _trainerStream = SharedStream(widget.trainerSource ?? Db.trainerDirectory).stream;
  late final _profileStream = widget.user.trainerId == null
      ? null
      : SharedStream(() => Db.trainerProfile(widget.user.trainerId!)).stream;
  late final _age = TextEditingController(text: widget.user.age > 0 ? '${widget.user.age}' : '');
  late final _height =
      TextEditingController(text: widget.user.height > 0 ? fmtNum(widget.user.height) : '');
  late final _weight =
      TextEditingController(text: widget.user.weight > 0 ? fmtNum(widget.user.weight) : '');
  bool _busy = false;
  String? _trainerError;

  static const _stackedBelow = 420.0;

  /// Vazn bir marta kiritilgach anketada o'zgarmaydi — faqat Progress'da haftada 1 marta
  bool get _weightLocked => widget.user.weight > 0;

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  static double? _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.'));

  /// Kiritilayotgan ma'lumotlar bo'yicha jonli hisob
  AppUser? get _preview {
    final a = _num(_age), h = _num(_height), w = _num(_weight);
    if (a == null ||
        h == null ||
        w == null ||
        !a.isFinite ||
        !h.isFinite ||
        !w.isFinite ||
        a < InputLimits.ageMin ||
        a > InputLimits.ageMax ||
        h < InputLimits.heightMin ||
        h > InputLimits.heightMax ||
        w < InputLimits.weightMin ||
        w > InputLimits.weightMax) {
      return null;
    }
    return widget.user.copyWith(
        trainerId: _trainerId,
        gender: _gender,
        goal: _goal,
        metabolism: _metabolism,
        age: a.round(),
        height: h,
        weight: w);
  }

  Future<void> _save() async {
    final formOk = InputRules.validateAndFocus(_form);
    if (!formOk) return;
    if (_goal.isEmpty) {
      showSnack(context, tr('Maqsadingizni tanlang: ozish yoki massa nabor'));
      return;
    }
    if (_canChooseTrainer && _trainers.isNotEmpty && _trainerId == null) {
      setState(() => _trainerError = tr('Treneringizni tanlang'));
      return;
    }
    if (_metabolism.isEmpty) {
      showSnack(context, tr('Moddalar almashinuvini tanlang: sekin yoki tez'));
      return;
    }
    final updated = _preview;
    if (updated == null) return;
    if (updated.goal == 'lose' && !updated.canLose) {
      showSnack(context, tr("BMI 18,5 dan past — ozish tavsiya etilmaydi. Massa naborni tanlang."));
      return;
    }
    setState(() => _busy = true);
    try {
      await Db.updateUser(updated, before: widget.user);
      if (widget.user.weight == 0) await Db.addWeight(updated.id, updated.weight);
      if (widget.editing && mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, trf("Saqlab bo'lmadi: {0}", [apiErrorText(e)]));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = Theme.of(context).colorScheme;
    final preview = _preview;
    // Vazn kam bo'lsa (BMI < 18,5) ozishni tanlab bo'lmaydi
    final loseBlocked = preview != null && !preview.canLose;
    return Scaffold(
      appBar: AppBar(title: Text(widget.editing ? tr("Ma'lumotlarni tahrirlash") : tr('Anketa'))),
      body: Form(
        key: _form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            if (!widget.editing) ...[
              Text(tr('Keling, tanishamiz 👋'), style: t.headlineSmall),
              const SizedBox(height: 6),
              Text(tr("Bu ma'lumotlar asosida kunlik kaloriya normangiz hisoblanadi."),
                  style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant)),
              const SizedBox(height: 20),
            ],
            SectionHeader(tr('Maqsad')),
            Row(children: [
              Expanded(
                child: _ChoiceCard(
                  icon: Icons.trending_down,
                  label: tr('Ozish'),
                  selected: _goal == 'lose',
                  onTap: loseBlocked ? null : () => setState(() => _goal = 'lose'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ChoiceCard(
                  icon: Icons.trending_up,
                  label: tr('Massa nabor'),
                  selected: _goal == 'gain',
                  onTap: () => setState(() => _goal = 'gain'),
                ),
              ),
            ]),
            if (loseBlocked)
              Padding(
                key: const ValueKey('lose-blocked'),
                padding: const EdgeInsets.only(top: AppSpace.sm, left: 4),
                child: Text(
                  trf('BMI {0} — vazningiz kam, ozish tavsiya etilmaydi.',
                      [preview.bmi.toStringAsFixed(1)]),
                  style: t.bodySmall?.copyWith(color: AppColors.warning),
                ),
              ),
            const SizedBox(height: 20),
            SectionHeader(tr('Treneringiz')),
            if (_canChooseTrainer)
              StreamBuilder<List<TrainerInfo>>(
                key: const ValueKey('trainer-directory'),
                stream: _trainerStream,
                builder: (context, snap) {
                  _trainers = snap.data ?? const [];
                  if (snap.hasError) return ErrorState(error: snap.error);
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpace.md),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (_trainers.isEmpty) {
                    return Text(
                      tr("Hozircha shogird qabul qilayotgan trener yo'q — trener keyin biriktiriladi."),
                      style: t.bodySmall?.copyWith(color: s.onSurfaceVariant),
                    );
                  }
                  return Column(children: [
                    for (final tr in _trainers)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.sm),
                        child: _TrainerOption(
                          trainer: tr,
                          selected: _trainerId == tr.id,
                          onTap: () => setState(() {
                            _trainerId = tr.id;
                            _trainerError = null;
                          }),
                        ),
                      ),
                    if (_trainerError != null)
                      Padding(
                        key: const ValueKey('trainer-error'),
                        padding: const EdgeInsets.only(left: 4, bottom: AppSpace.sm),
                        child: Text(_trainerError!, style: t.bodySmall?.copyWith(color: s.error)),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        tr("Tanlagan treneringiz rejangizni tuzadi va siz bilan yozishadi. "
                            "Keyin Profil bo'limida almashtirishingiz mumkin."),
                        style: t.bodySmall?.copyWith(color: s.onSurfaceVariant),
                      ),
                    ),
                  ]);
                },
              )
            else
              StreamBuilder<TrainerInfo?>(
                key: const ValueKey('trainer-profile'),
                stream: _profileStream,
                builder: (context, snap) => Text(
                  snap.data?.name ?? tr('Trener biriktirilgan'),
                  style: t.titleMedium,
                ),
              ),
            const SizedBox(height: 20),
            SectionHeader(tr('Jins')),
            Row(children: [
              Expanded(
                child: _ChoiceCard(
                  icon: Icons.male,
                  label: tr('Erkak'),
                  selected: _gender == 'male',
                  onTap: () => setState(() => _gender = 'male'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ChoiceCard(
                  icon: Icons.female,
                  label: tr('Ayol'),
                  selected: _gender == 'female',
                  onTap: () => setState(() => _gender = 'female'),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            SectionHeader(tr("Tana o'lchamlari")),
            _bodyFields(),
            if (_weightLocked)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.sm, left: 4),
                child: Text(
                  tr("Vazn bu yerda o'zgarmaydi — Progress bo'limida haftada 1 marta kiritiladi."),
                  style: t.bodySmall?.copyWith(color: s.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 20),
            SectionHeader(tr('Moddalar almashinuvi (metabolizm)')),
            Row(children: [
              Expanded(
                child: _ChoiceCard(
                  icon: Icons.hourglass_bottom,
                  label: tr('Sekin'),
                  selected: _metabolism == 'slow',
                  onTap: () => setState(() => _metabolism = 'slow'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ChoiceCard(
                  icon: Icons.bolt_outlined,
                  label: tr('Tez'),
                  selected: _metabolism == 'fast',
                  onTap: () => setState(() => _metabolism = 'fast'),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.sm, left: 4),
              child: Text(
                tr("Tez — ovqat tez hazm bo'lib, tez-tez qorin ochadi. Sekin — ovqat sekin hazm "
                    "bo'ladi, kuniga 2 mahal yeb ham yuraverasiz. Bilmasangiz — «Sekin»ni tanlang."),
                style: t.bodySmall?.copyWith(color: s.onSurfaceVariant, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            if (preview != null) ...[
              const SizedBox(height: 8),
              Card(
                color: s.primaryContainer.withValues(alpha: 0.5),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    IconBadge(Icons.local_fire_department, color: s.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(trf('Kunlik norma · {0}', [preview.kcalFormula]), style: t.bodySmall),
                        Text(trf('{0} kkal', [preview.targetKcal]), style: t.titleLarge),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(tr('BMI'), style: t.bodySmall),
                      Text(preview.bmi.toStringAsFixed(1), style: t.titleLarge),
                    ]),
                  ]),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Card(
              color: AppColors.warning.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.health_and_safety_outlined, color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr("Homilador bo'lsangiz, 18 yoshgacha bo'lsangiz yoki diabet, yurak, "
                          "oshqozon kasalliklari bo'lsa, diyetani boshlashdan oldin shifokor bilan "
                          "maslahatlashing."),
                      style: t.bodySmall?.copyWith(height: 1.4),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Text(tr('Saqlash')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bodyFields() {
    final fields = [
      _numField(_age, tr('Yosh'), 'yosh', InputRules.intRange(InputLimits.ageMin, InputLimits.ageMax),
          decimal: false),
      _numField(_height, tr("Bo'y"), 'sm',
          InputRules.decimalRange(InputLimits.heightMin, InputLimits.heightMax),
          decimal: true),
      _numField(_weight, tr('Vazn'), 'kg',
          InputRules.decimalRange(InputLimits.weightMin, InputLimits.weightMax),
          decimal: true, locked: _weightLocked),
    ];
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < _stackedBelow) {
        return Column(children: [
          for (final f in fields)
            Padding(padding: const EdgeInsets.only(bottom: AppSpace.md), child: f),
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpace.md),
          Expanded(child: fields[i]),
        ],
      ]);
    });
  }

  Widget _numField(
    TextEditingController c,
    String label,
    String suffix,
    FormFieldValidator<String> validator, {
    bool decimal = false,
    bool locked = false,
  }) =>
      TextFormField(
        controller: c,
        readOnly: locked,
        enabled: !locked,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: decimal ? InputRules.decimalOnly(maxDecimals: 1) : InputRules.digitsMax(3),
        textAlign: TextAlign.center,
        validator: validator,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          suffixText: tr(suffix),
          errorMaxLines: 3,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
      );
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap; // null — o'chiq (masalan, vazn kam bo'lsa ozish)
  const _ChoiceCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Material(
        color: selected ? s.primaryContainer : Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: selected ? s.primary : s.outlineVariant.withValues(alpha: 0.6),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(children: [
              Icon(icon, size: 36, color: selected ? s.primary : s.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? s.onPrimaryContainer : s.onSurface,
                  )),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Anketadagi trener varianti: ism va trener o'zi yozgan qisqa ma'lumot
class _TrainerOption extends StatelessWidget {
  final TrainerInfo trainer;
  final bool selected;
  final VoidCallback onTap;
  const _TrainerOption({required this.trainer, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Material(
      color: selected ? s.primaryContainer : Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: selected ? s.primary : s.outlineVariant.withValues(alpha: 0.6),
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(children: [
            UserAvatar(name: trainer.name, size: 42),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(trainer.name, style: t.titleMedium),
                if (trainer.bio.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(trainer.bio, style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
                ],
              ]),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? s.primary : s.onSurfaceVariant,
            ),
          ]),
        ),
      ),
    );
  }
}
