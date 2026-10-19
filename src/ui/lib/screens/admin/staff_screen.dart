import 'package:flutter/material.dart';
import '../../core/input_rules.dart';
import '../../l10n/tr.dart';
import '../../models/hudud.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';
import 'clients_screen.dart';
import 'sales_report_screen.dart';
import 'finance_screen.dart';
import 'member_analytics_screen.dart';
import 'shop_analytics_screen.dart';
import 'trainer_stats_screen.dart';
import '../../services/api/api_error.dart';

/// "Xodimlar" — faqat bosh admin (zal egasi) uchun.
/// Zal qo'shadi, zalga trener biriktiradi, har trenerning shogirdlarini ko'radi.
class StaffScreen extends StatefulWidget {
  final AppUser owner;
  const StaffScreen({super.key, required this.owner});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  /// Tanlangan zal; null — hamma zallar
  String? _gymId;

  AppUser get owner => widget.owner;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Gym>>(
      stream: Db.gyms(),
      builder: (context, gymSnap) {
        if (gymSnap.hasError) return ErrorState(error: gymSnap.error);
        final gyms = gymSnap.data ?? const <Gym>[];
        // o'chirilgan zal tanlab qolgan bo'lsa — "Hammasi" ga qaytamiz
        final gymId = gyms.any((g) => g.id == _gymId) ? _gymId : null;

        return StreamBuilder<List<AppUser>>(
          stream: Db.staff(),
          builder: (context, staffSnap) {
            if (staffSnap.hasError) return ErrorState(error: staffSnap.error);
            return StreamBuilder<List<AppUser>>(
              stream: Db.clients(),
              builder: (context, clientSnap) {
                if (clientSnap.hasError) return ErrorState(error: clientSnap.error);
                if (!staffSnap.hasData || !clientSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allStaff = [...staffSnap.data!]..sort((a, b) => a.name.compareTo(b.name));
                final clients = clientSnap.data!;

                final owners = allStaff.where((u) => u.isOwner).toList();
                final barmens = allStaff.where((u) => u.isBarmen).toList();
                final allTrainers = allStaff.where((u) => u.isTrainer).toList();
                final trainers =
                    allTrainers.where((t) => gymId == null || t.gymId == gymId).toList();
                final noGym = allTrainers.where((t) => t.gymId == null).toList();

                final ids = trainers.map((t) => t.id).toSet();
                final gymClients = gymId == null
                    ? clients
                    : clients.where((c) => ids.contains(c.trainerId)).toList();
                final free = clients.where((c) => c.trainerId == null).toList();

                int countFor(String uid) => clients.where((c) => c.trainerId == uid).length;
                String gymName(String? id) =>
                    gyms.where((g) => g.id == id).map((g) => g.name).firstOrNull ?? tr('Zalsiz');

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.xxl),
                  children: [
                    // ---------- zallar ----------
                    SectionHeader(
                      gyms.isEmpty || gymId == null ? tr('Zallar') : gymName(gymId),
                      eyebrow: tr('Zal tanlang'),
                      trailing: TextButton.icon(
                        onPressed: () => _gymSheet(),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(tr('Zal')),
                      ),
                    ),
                    if (gyms.isEmpty)
                      BentoTile(
                        padding: const EdgeInsets.all(AppSpace.lg),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr('Hali zal qo\'shilmagan'),
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            tr('Zal qo\'shsangiz, har trenerni o\'z zaliga biriktirasiz va '
                                'zal bo\'yicha ajratib ko\'rasiz.'),
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                        ]),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          _GymChip(
                            label: tr('Hammasi'),
                            selected: gymId == null,
                            onTap: () => setState(() => _gymId = null),
                          ),
                          for (final g in gyms)
                            _GymChip(
                              label: g.name,
                              count: allTrainers.where((t) => t.gymId == g.id).length,
                              selected: gymId == g.id,
                              onTap: () => setState(() => _gymId = g.id),
                              onLongPress: () => _gymSheet(gym: g),
                            ),
                        ]),
                      ),
                    if (gymId != null) ...[
                      const SizedBox(height: AppSpace.sm),
                      Row(children: [
                        Expanded(
                          child: Text(
                            gyms.firstWhere((g) => g.id == gymId).fullAddress.isEmpty
                                ? tr('Manzil kiritilmagan')
                                : gyms.firstWhere((g) => g.id == gymId).fullAddress,
                            style: TextStyle(color: AppColors.textFaint, fontSize: 12.5),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _gymSheet(gym: gyms.firstWhere((g) => g.id == gymId)),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: Text(tr('Tahrirlash')),
                        ),
                      ]),
                    ],
                    const SizedBox(height: AppSpace.lg),

                    // ---------- ko'rsatkichlar ----------
                    Row(children: [
                      Expanded(
                        child: StatTile(
                          icon: Icons.badge_outlined,
                          label: tr('Trener'),
                          value: '${trainers.length}',
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: StatTile(
                          icon: Icons.groups_outlined,
                          label: tr('Shogird'),
                          value: '${gymClients.length}',
                          color: AppColors.water,
                        ),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: StatTile(
                          icon: Icons.person_off_outlined,
                          label: tr('Biriktirilmagan'),
                          value: '${free.length}',
                          color: free.isEmpty ? AppColors.textMuted : AppColors.warning,
                        ),
                      ),
                    ]),
                    const SizedBox(height: AppSpace.md),
                    BentoTile(
                      feature: true,
                      padding: const EdgeInsets.all(AppSpace.md),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => TrainerStatsScreen(owner: owner)),
                      ),
                      child: Row(children: [
                        IconBadge(Icons.leaderboard_outlined, color: AppColors.accent, size: 38),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(tr('Trenerlar reytingi'),
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              tr("Solishtirish, ball va kimga e'tibor kerak"),
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                            ),
                          ]),
                        ),
                        Icon(Icons.chevron_right, size: 20, color: AppColors.textFaint),
                      ]),
                    ),
                    const SizedBox(height: AppSpace.md),
                    BentoTile(
                      key: const Key('staff-member-analytics'),
                      padding: const EdgeInsets.all(AppSpace.md),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MemberAnalyticsScreen(isOwner: true)),
                      ),
                      child: Row(children: [
                        IconBadge(Icons.groups_outlined, color: AppColors.accent, size: 38),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(tr("A'zolar tahlili"),
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              tr("Ketish xavfi, qolish ulushi va trenerlar natijasi"),
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                            ),
                          ]),
                        ),
                        Icon(Icons.chevron_right, size: 20, color: AppColors.textFaint),
                      ]),
                    ),
                    const SizedBox(height: AppSpace.md),
                    BentoTile(
                      key: const Key('staff-shop-analytics'),
                      padding: const EdgeInsets.all(AppSpace.md),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ShopAnalyticsScreen()),
                      ),
                      child: Row(children: [
                        IconBadge(Icons.insights_outlined, color: AppColors.accent, size: 38),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(tr("Do'kon tahlili"),
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              tr("Eng ko'p sotilgan tovarlar va hafta kunlari bo'yicha savdo"),
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                            ),
                          ]),
                        ),
                        Icon(Icons.chevron_right, size: 20, color: AppColors.textFaint),
                      ]),
                    ),
                    const SizedBox(height: AppSpace.md),
                    BentoTile(
                      padding: const EdgeInsets.all(AppSpace.md),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SalesReportScreen(me: owner),
                        ),
                      ),
                      child: Row(children: [
                        IconBadge(Icons.payments_outlined, color: AppColors.success, size: 38),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(tr('Sotuv hisoboti'),
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              tr('Kim nechta sotdi, qaysi tovar, qancha pul'),
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                            ),
                          ]),
                        ),
                        Icon(Icons.chevron_right, size: 20, color: AppColors.textFaint),
                      ]),
                    ),
                    const SizedBox(height: AppSpace.md),
                    BentoTile(
                      padding: const EdgeInsets.all(AppSpace.md),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FinanceScreen()),
                      ),
                      child: Row(children: [
                        IconBadge(Icons.account_balance_wallet_outlined,
                            color: AppColors.accent, size: 38),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(tr('Oylik hisobot'),
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              tr("Abonement va do'kon tushumi, foyda — oy va zal bo'yicha"),
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                            ),
                          ]),
                        ),
                        Icon(Icons.chevron_right, size: 20, color: AppColors.textFaint),
                      ]),
                    ),
                    const SizedBox(height: AppSpace.xl),

                    // ---------- trenerlar ----------
                    SectionHeader(
                      tr('Trenerlar'),
                      eyebrow: gymId == null ? tr('Hamma zallar') : gymName(gymId),
                      trailing: TextButton.icon(
                        onPressed: () => _addTrainerMenu(gyms, gymId, clients),
                        icon: const Icon(Icons.person_add_alt, size: 18),
                        label: Text(tr('Qo\'shish')),
                      ),
                    ),
                    if (trainers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.sm, left: 4),
                        child: Text(
                          gymId == null
                              ? tr('Hali trener yo\'q')
                              : tr(
                                  'Bu zalda trener yo\'q — qo\'shing yoki boshqa zaldan ko\'chiring'),
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    for (final t in trainers)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.sm),
                        child: _StaffTile(
                          person: t,
                          clientCount: countFor(t.id),
                          subtitle: gymId == null ? gymName(t.gymId) : null,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TrainerDetail(trainer: t, owner: owner),
                            ),
                          ),
                          onActions: () => _staffActions(
                            context,
                            t,
                            countFor(t.id),
                            ownerCount: owners.length,
                            gyms: gyms,
                          ),
                        ),
                      ),

                    // ---------- zalsiz trenerlar ----------
                    if (gymId == null && noGym.isNotEmpty && gyms.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.sm),
                      BentoTile(
                        padding: const EdgeInsets.all(AppSpace.md),
                        child: Row(children: [
                          Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                          const SizedBox(width: AppSpace.sm),
                          Expanded(
                            child: Text(
                              trf(
                                  '{0} ta trener zalga biriktirilmagan — '
                                  'ustiga bosib "Zalga biriktirish" ni tanlang.',
                                  [noGym.length]),
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                            ),
                          ),
                        ]),
                      ),
                    ],

                    // ---------- barmenlar ----------
                    if (barmens.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.xl),
                      SectionHeader(
                        tr('Barmenlar'),
                        eyebrow: tr("Do'kon va sotuv"),
                        trailing: Pill(text: '${barmens.length}', color: AppColors.protein),
                      ),
                      for (final b in barmens)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.sm),
                          child: _StaffTile(
                            person: b,
                            clientCount: 0,
                            subtitle: tr('Barmen'),
                            onTap: () =>
                                _staffActions(context, b, 0, ownerCount: owners.length, gyms: gyms),
                            onActions: () =>
                                _staffActions(context, b, 0, ownerCount: owners.length, gyms: gyms),
                          ),
                        ),
                    ],

                    // ---------- bosh adminlar ----------
                    const SizedBox(height: AppSpace.xl),
                    SectionHeader(tr('Bosh adminlar'), eyebrow: tr('Zal egasi')),
                    for (final o in owners)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.sm),
                        child: _StaffTile(
                          person: o,
                          clientCount: countFor(o.id),
                          subtitle: o.id == owner.id ? tr('Siz') : null,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TrainerDetail(trainer: o, owner: owner),
                            ),
                          ),
                          onActions: o.id == owner.id
                              ? null
                              : () => _staffActions(
                                    context,
                                    o,
                                    countFor(o.id),
                                    ownerCount: owners.length,
                                    gyms: gyms,
                                  ),
                        ),
                      ),

                    // ---------- trenersiz shogirdlar ----------
                    if (free.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.xl),
                      SectionHeader(
                        tr('Trenersiz shogirdlar'),
                        eyebrow: tr('Biriktirish kerak'),
                        trailing: Pill(text: '${free.length}', color: AppColors.warning),
                      ),
                      for (final c in free)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.sm),
                          child: _ClientRow(
                            client: c,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ClientDetail(client: c, admin: owner),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // ---------------- zal qo'shish / tahrirlash ----------------
  Future<void> _gymSheet({Gym? gym}) async {
    final name = TextEditingController(text: gym?.name);
    final address = TextEditingController(text: gym?.address);
    // ro'yxatda yo'q tuman qo'lda yozilgan bo'lsa — shu maydonda turadi
    final otherDistrict = TextEditingController();
    final gymForm = GlobalKey<FormState>();

    var country = gym?.country.isNotEmpty == true ? gym!.country : countries.first;
    var region = regionNames.contains(gym?.region) ? gym!.region : null;
    String? district;
    if (region != null && gym!.district.isNotEmpty) {
      if (districtsOf(region).contains(gym.district)) {
        district = gym.district;
      } else {
        district = otherOption;
        otherDistrict.text = gym.district;
      }
    }

    final saved = await showSheet<bool>(
      context,
      StatefulBuilder(
        builder: (ctx, setS) => SingleChildScrollView(
          child: Form(
            key: gymForm,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpace.md),
                  Text(gym == null ? tr('Yangi zal') : tr('Zalni tahrirlash'),
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: AppSpace.xs),
                  Text(tr('Avval joyini tanlang, keyin nom bering'),
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  const SizedBox(height: AppSpace.lg),

                  // 1 — mamlakat
                  DropdownButtonFormField<String>(
                    initialValue: country,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: tr('Mamlakat')),
                    items: [
                      for (final c in countries) DropdownMenuItem(value: c, child: Text(tr(c))),
                    ],
                    onChanged: (v) => setS(() => country = v ?? countries.first),
                  ),
                  const SizedBox(height: AppSpace.md),

                  // 2 — viloyat
                  DropdownButtonFormField<String>(
                    initialValue: region,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr('Viloyat / shahar'),
                      hintText: tr('Tanlang'),
                    ),
                    items: [
                      for (final r in regionNames) DropdownMenuItem(value: r, child: Text(tr(r))),
                    ],
                    onChanged: (v) => setS(() {
                      region = v;
                      district = null;
                      otherDistrict.clear();
                    }),
                  ),
                  const SizedBox(height: AppSpace.md),

                  // 3 — tuman
                  DropdownButtonFormField<String>(
                    initialValue: district,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr('Tuman'),
                      hintText: region == null ? tr('Avval viloyatni tanlang') : tr('Tanlang'),
                    ),
                    items: region == null
                        ? const []
                        : [
                            for (final d in districtsOf(region!))
                              DropdownMenuItem(value: d, child: Text(tr(d))),
                          ],
                    onChanged: region == null ? null : (v) => setS(() => district = v),
                  ),
                  if (district == otherOption) ...[
                    const SizedBox(height: AppSpace.md),
                    TextFormField(
                      controller: otherDistrict,
                      maxLength: InputLimits.region,
                      buildCounter: InputRules.counterAtEighty,
                      validator: InputRules.required(InputLimits.region),
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: tr('Tuman nomi'),
                        hintText: tr("Ro'yxatda yo'q bo'lsa — o'zingiz yozing"),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.md),

                  // 4 — nomi va ko'chasi
                  TextFormField(
                    controller: name,
                    maxLength: InputLimits.gymName,
                    buildCounter: InputRules.counterAtEighty,
                    validator: InputRules.required(
                      InputLimits.gymName,
                      emptyMessage: tr('Zal nomini kiriting'),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: tr('Zal nomi'),
                      hintText: tr('Aura Fit zali'),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  TextFormField(
                    controller: address,
                    maxLength: InputLimits.address,
                    buildCounter: InputRules.counterAtEighty,
                    validator: InputRules.optional(InputLimits.address),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: tr("Ko'cha, uy (ixtiyoriy)"),
                      hintText: tr('Bunyodkor 12'),
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  FilledButton(
                    onPressed: () {
                      if (InputRules.validateAndFocus(gymForm)) Navigator.pop(ctx, true);
                    },
                    child: Text(tr('Saqlash')),
                  ),
                  if (gym != null) ...[
                    const SizedBox(height: AppSpace.sm),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                      onPressed: () => Navigator.pop(ctx, false),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(tr("Zalni o'chirish")),
                    ),
                  ],
                  const SizedBox(height: AppSpace.sm),
                ]),
          ),
        ),
      ),
    );
    if (!mounted) return;

    if (saved == true) {
      final d = district == otherOption ? otherDistrict.text.trim() : (district ?? '');
      final id = await Db.saveGym(Gym(
        id: gym?.id ?? '',
        name: name.text.trim(),
        country: country,
        region: region ?? '',
        district: d,
        address: address.text.trim(),
      ));
      if (mounted) {
        setState(() => _gymId = id);
        showSnack(context, gym == null ? tr("Zal qo'shildi") : tr('Saqlandi'));
      }
      return;
    }

    if (saved == false && gym != null) {
      final ok = await confirm(
        context,
        title: tr("Zal o'chirilsinmi?"),
        message: trf(
            '"{0}" o\'chiriladi. Undagi trenerlar zalsiz qoladi — '
            "ularni boshqa zalga biriktirasiz. Shogirdlarga ta'sir qilmaydi.",
            [gym.name]),
        ok: tr("O'chirish"),
        destructive: true,
      );
      if (!ok || !mounted) return;
      await Db.deleteGym(gym.id);
      if (mounted) {
        setState(() => _gymId = null);
        showSnack(context, tr("Zal o'chirildi"));
      }
    }
  }

  // ---------------- trener qo'shish ----------------
  Future<void> _addTrainerMenu(List<Gym> gyms, String? gymId, List<AppUser> clients) async {
    final choice = await showSheet<String>(
      context,
      Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpace.md),
            Text(tr('Trener qo\'shish'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpace.sm),
            Text(
              tr('Barmen faqat do\'kon bilan ishlaydi: tovar, buyurtma va qoldiq. '
                  'Shogirdlar, rejalar va chatni ko\'rmaydi.'),
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: AppSpace.lg),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, 'new'),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: Text(tr('Yangi trener akkaunti')),
            ),
            const SizedBox(height: AppSpace.sm),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'barmen'),
              icon: const Icon(Icons.local_bar_outlined, size: 18),
              label: Text(tr('Yangi barmen akkaunti')),
            ),
            const SizedBox(height: AppSpace.sm),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'promote'),
              icon: const Icon(Icons.switch_account_outlined, size: 18),
              label: Text(tr('Mavjud foydalanuvchini tayinlash')),
            ),
          ]),
    );
    if (choice == null || !mounted) return;
    if (choice == 'promote') {
      await _promoteSheet(context, clients);
      return;
    }
    await _createStaffSheet(gyms, gymId, role: choice == 'barmen' ? 'barmen' : 'admin');
  }

  /// Yangi xodim akkaunti (trener yoki barmen): ism, telefon, parol
  Future<void> _createStaffSheet(List<Gym> gyms, String? gymId, {String role = 'admin'}) async {
    final isBarmen = role == 'barmen';
    final name = TextEditingController();
    final phone = TextEditingController();
    final pass = TextEditingController(text: 'trener${DateTime.now().year}');
    var targetGym = gymId ?? (gyms.isNotEmpty ? gyms.first.id : null);
    var busy = false;
    String? error;
    final staffForm = GlobalKey<FormState>();

    final ok = await showSheet<bool>(
      context,
      StatefulBuilder(
        builder: (ctx, setS) => Form(
          key: staffForm,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpace.md),
                Text(isBarmen ? tr('Yangi barmen') : tr('Yangi trener'),
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: AppSpace.lg),
                TextFormField(
                  controller: name,
                  autofocus: true,
                  maxLength: InputLimits.name,
                  buildCounter: InputRules.counterAtEighty,
                  validator:
                      InputRules.required(InputLimits.name, emptyMessage: tr('Ismni kiriting')),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: tr('Ism'),
                    hintText: isBarmen ? tr('Anvar aka') : tr('Bekzod aka'),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: InputRules.digitsMax(InputLimits.phoneDigits),
                  validator: (v) => (v ?? '').length == InputLimits.phoneDigits
                      ? null
                      : tr("Raqamni to'liq kiriting: 90 123 45 67"),
                  decoration: InputDecoration(
                    labelText: tr('Telefon raqam'),
                    hintText: '90 123 45 67',
                    prefixText: '+998 ',
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                TextFormField(
                  controller: pass,
                  maxLength: InputLimits.passwordMax,
                  buildCounter: InputRules.counterAtEighty,
                  validator: (v) => InputRules.password(v?.trim(), strict: true),
                  decoration: InputDecoration(
                    labelText: tr('Parol'),
                    helperText: tr('Kamida 8 belgi — xodimga shu parolni aytasiz'),
                  ),
                ),
                if (gyms.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
                      for (final g in gyms)
                        ChoiceChip(
                          selected: targetGym == g.id,
                          onSelected: (_) => setS(() => targetGym = g.id),
                          label: Text(g.name),
                        ),
                    ]),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: AppSpace.md),
                  Text(error!, style: TextStyle(color: AppColors.danger, fontSize: 13)),
                ],
                const SizedBox(height: AppSpace.lg),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          if (!InputRules.validateAndFocus(staffForm)) return;
                          final n = name.text.trim();
                          final ph = normalizePhone(phone.text);
                          setS(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            await Db.createStaff(
                              name: n,
                              phone: ph,
                              password: pass.text.trim(),
                              role: role,
                              gymId: targetGym,
                            );
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            final msg = (e is ApiException && e.code == 'phone_taken')
                                ? tr('Bu raqam allaqachon ro\'yxatdan o\'tgan')
                                : trf('Bo\'lmadi: {0}', [apiErrorText(e)]);
                            setS(() {
                              busy = false;
                              error = msg;
                            });
                          }
                        },
                  child: Text(busy
                      ? tr('Yaratilmoqda…')
                      : (isBarmen ? tr('Barmen qo\'shish') : tr('Trener qo\'shish'))),
                ),
              ]),
        ),
      ),
    );

    if (ok == true && mounted) {
      await showSheet<void>(
        context,
        Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpace.md),
              Text(isBarmen ? tr('Barmen qo\'shildi') : tr('Trener qo\'shildi'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpace.sm),
              Text(
                tr('Shu ma\'lumotni xodimga bering — ilovaga shu bilan kiradi:'),
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: AppSpace.lg),
              BentoTile(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(trf('Telefon: {0}', [fmtPhone(normalizePhone(phone.text))]),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(trf('Parol: {0}', [pass.text.trim()]),
                      style: Theme.of(context).textTheme.titleMedium),
                ]),
              ),
              const SizedBox(height: AppSpace.lg),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr('Tushundim')),
              ),
            ]),
      );
    }
  }

  /// Trenerni boshqa zalga ko'chirish
  Future<void> _pickGym(AppUser trainer, List<Gym> gyms) async {
    final picked = await showSheet<String>(
      context,
      Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpace.md),
            Text(tr('Qaysi zalga?'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpace.lg),
            for (final g in gyms)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, g.id),
                  child: Text(g.name),
                ),
              ),
            if (trainer.gymId != null)
              TextButton(
                onPressed: () => Navigator.pop(context, ''),
                child: Text(tr('Zaldan chiqarish')),
              ),
          ]),
    );
    if (picked == null || !mounted) return;
    await Db.setUserGym(trainer.id, picked.isEmpty ? null : picked);
    if (mounted) {
      showSnack(context, picked.isEmpty ? tr('Zaldan chiqarildi') : tr('Zalga biriktirildi'));
    }
  }

  /// Oddiy foydalanuvchini trener qilish
  Future<void> _promoteSheet(BuildContext context, List<AppUser> clients) async {
    if (clients.isEmpty) {
      showSnack(context, tr("Hali ro'yxatdan o'tgan foydalanuvchi yo'q"));
      return;
    }
    final picked = await showSheet<AppUser>(
      context,
      _PickUserSheet(users: clients),
    );
    if (picked == null || !context.mounted) return;

    final ok = await confirm(
      context,
      title: tr('Trener qilinsinmi?'),
      message: trf(
          '{0} '
          "trener paneliga kira oladi: reja tuzadi, mahsulot qo'shadi, "
          'shogirdlar bilan yozishadi.',
          [picked.name.isEmpty ? fmtPhone(picked.phone) : picked.name]),
      ok: tr('Trener qilish'),
    );
    if (!ok) return;
    await Db.setRole(picked.id, 'admin');
    if (context.mounted) showSnack(context, tr('Trener tayinlandi'));
  }

  /// Xodim ustidagi amallar (bosh admin uchun)
  Future<void> _staffActions(
    BuildContext context,
    AppUser person,
    int count, {
    required int ownerCount,
    List<Gym> gyms = const [],
  }) async {
    final name = person.name.isEmpty ? fmtPhone(person.phone) : person.name;
    // Oxirgi bosh adminni tushirib bo'lmaydi — aks holda hech kim rol tayinlay olmaydi
    final lastOwner = person.isOwner && ownerCount <= 1;
    final action = await showSheet<String>(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpace.xs),
          Text(
            person.isOwner
                ? tr('Bosh admin')
                : (count == 0 ? tr("Shogirdi yo'q") : trf('{0} ta shogird biriktirilgan', [count])),
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: AppSpace.lg),
          if (!person.isOwner && !person.isBarmen) ...[
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'makeBarmen'),
              icon: const Icon(Icons.local_bar_outlined, size: 18),
              label: Text(tr('Barmen qilish')),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
          if (person.isBarmen) ...[
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'makeTrainer'),
              icon: const Icon(Icons.fitness_center_outlined, size: 18),
              label: Text(tr('Trener qilish')),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
          if (!person.isOwner && gyms.isNotEmpty) ...[
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'gym'),
              icon: const Icon(Icons.home_work_outlined, size: 18),
              label: Text(tr('Zalga biriktirish')),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
          if (!person.isOwner) ...[
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, 'makeOwner'),
              icon: const Icon(Icons.shield_outlined, size: 18),
              label: Text(tr('Bosh admin qilish')),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
          OutlinedButton.icon(
            onPressed: lastOwner ? null : () => Navigator.pop(context, 'demote'),
            icon: const Icon(Icons.person_remove_outlined, size: 18),
            label: Text(person.isOwner
                ? tr('Bosh adminlikdan olish')
                : (person.isBarmen ? tr('Barmenlikdan olish') : tr('Trenerlikdan olish'))),
          ),
          if (lastOwner)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.sm),
              child: Text(
                tr("Bu yagona bosh admin — tushirib bo'lmaydi. Avval boshqa birovni "
                    'bosh admin qiling.'),
                style: TextStyle(color: AppColors.textFaint, fontSize: 12),
              ),
            ),
          const SizedBox(height: AppSpace.sm),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
            ),
            onPressed: () => Navigator.pop(context, 'delete'),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(tr("Akkauntni o'chirish")),
          ),
        ],
      ),
    );
    if (action == null || !context.mounted) return;

    if (action == 'gym') {
      await _pickGym(person, gyms);
      return;
    }

    if (action == 'makeBarmen' || action == 'makeTrainer') {
      final toBarmen = action == 'makeBarmen';
      final ok = await confirm(
        context,
        title: toBarmen ? tr('Barmen qilinsinmi?') : tr('Trener qilinsinmi?'),
        message: toBarmen
            ? trf(
                '{0} faqat do\'kon bilan ishlaydi: tovar, buyurtma va qoldiq. '
                'Shogirdlar, rejalar va chatni ko\'rmaydi.'
                '{1}',
                [
                    name,
                    count > 0
                        ? trf('\n\nUnga biriktirilgan {0} ta shogird trenersiz qoladi.', [count])
                        : ''
                  ])
            : trf('{0} trener paneliga kiradi: reja tuzadi, shogird qabul qiladi.', [name]),
        ok: toBarmen ? tr('Barmen qilish') : tr('Trener qilish'),
      );
      if (!ok) return;
      await Db.setRole(person.id, toBarmen ? 'barmen' : 'admin');
      if (context.mounted) {
        showSnack(context, toBarmen ? tr('Barmen tayinlandi') : tr('Trener tayinlandi'));
      }
      return;
    }

    if (action == 'makeOwner') {
      final ok = await confirm(
        context,
        title: tr('Bosh admin qilinsinmi?'),
        message: trf(
            "{0} sizga teng huquq oladi: trener tayinlaydi, akkaunt o'chiradi, "
            "hamma trener va shogirdni ko'radi.\n\nUni faqat boshqa bosh admin "
            'tushira oladi.',
            [name]),
        ok: tr('Bosh admin qilish'),
      );
      if (!ok) return;
      await Db.setRole(person.id, 'owner');
      if (context.mounted) showSnack(context, tr('Bosh admin tayinlandi'));
      return;
    }

    if (action == 'demote') {
      // Bosh adminni tushirsak — u trener bo'ladi, trenerni tushirsak — oddiy foydalanuvchi
      final toRole = person.isOwner ? 'admin' : 'user';
      final ok = await confirm(
        context,
        title: person.isOwner ? tr('Bosh adminlikdan olinsinmi?') : tr('Trenerlikdan olinsinmi?'),
        message: person.isOwner
            ? trf(
                "{0} oddiy trener bo'lib qoladi: rol tayinlay olmaydi va akkaunt "
                "o'chira olmaydi. Shogirdlari o'zida qoladi.",
                [name])
            : (count == 0
                ? trf('{0} oddiy foydalanuvchiga aylanadi va trener paneliga kira olmaydi.', [name])
                : trf(
                    '{0} oddiy foydalanuvchiga aylanadi. Unga biriktirilgan {1} ta '
                    'shogird trenersiz qoladi — ularni boshqa trenerga biriktirishingiz kerak.',
                    [name, count])),
        ok: tr('Olish'),
        destructive: true,
      );
      if (!ok) return;
      await Db.setRole(person.id, toRole);
      if (context.mounted) {
        showSnack(
            context, person.isOwner ? tr('Bosh adminlikdan olindi') : tr('Trenerlikdan olindi'));
      }
      return;
    }

    final ok = await confirm(
      context,
      title: tr("Akkaunt o'chirilsinmi?"),
      message: trf(
          "{0} ilovaga kira olmaydi va ro'yxatlardan yo'qoladi. "
          "Bu amalni qaytarib bo'lmaydi.",
          [name]),
      ok: tr("O'chirish"),
      destructive: true,
    );
    if (!ok) return;
    await Db.deleteUser(person.id);
    if (context.mounted) showSnack(context, tr("Akkaunt o'chirildi"));
  }
}

/// Zal tugmachasi (yuqoridagi gorizontal ro'yxat).
/// Uzoq bosilsa — zalni tahrirlash.
class _GymChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _GymChip({
    required this.label,
    this.count,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: AppSpace.sm),
        child: GestureDetector(
          onLongPress: onLongPress,
          child: ChoiceChip(
            selected: selected,
            onSelected: (_) => onTap(),
            label: Text(count == null ? label : '$label · $count'),
          ),
        ),
      );
}

/// Bitta trener/bosh admin qatori
class _StaffTile extends StatelessWidget {
  final AppUser person;
  final int clientCount;

  /// Qo'shimcha yozuv (zal nomi yoki "Siz") — ism yonida chiqadi
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback? onActions;
  const _StaffTile({
    required this.person,
    required this.clientCount,
    this.subtitle,
    required this.onTap,
    this.onActions,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final name = person.name.isEmpty ? fmtPhone(person.phone) : person.name;
    return BentoTile(
      onTap: onTap,
      feature: person.isOwner,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(children: [
        UserAvatar(name: name),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Pill(
                text: subtitle ?? (person.isOwner ? tr('Bosh admin') : tr('Trener')),
                color: person.isOwner ? AppColors.accent : AppColors.textMuted,
              ),
            ]),
            const SizedBox(height: 2),
            Text(
              clientCount == 0
                  ? tr("Shogirdi yo'q")
                  : trf('{0} ta shogird  ·  {1}', [clientCount, fmtPhone(person.phone)]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontFeatures: tabular,
              ),
            ),
          ]),
        ),
        if (onActions != null)
          IconButton(
            tooltip: tr('Amallar'),
            onPressed: onActions,
            icon: const Icon(Icons.more_horiz, size: 20),
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.sm),
            child: Icon(Icons.chevron_right, size: 20, color: AppColors.textFaint),
          ),
      ]),
    );
  }
}

/// Trenerning shogirdlari ro'yxati
class TrainerDetail extends StatelessWidget {
  final AppUser trainer;
  final AppUser owner;
  const TrainerDetail({super.key, required this.trainer, required this.owner});

  @override
  Widget build(BuildContext context) {
    final name = trainer.name.isEmpty ? fmtPhone(trainer.phone) : trainer.name;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name),
            Text(
              trainer.isOwner ? tr('Bosh admin') : tr('Trener'),
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: Db.clients(),
        builder: (context, snap) {
          if (snap.hasError) return ErrorState(error: snap.error);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final mine = snap.data!.where((c) => c.trainerId == trainer.id).toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          if (mine.isEmpty) {
            return EmptyState(
              icon: Icons.groups_outlined,
              title: tr('Shogird biriktirilmagan'),
              subtitle: tr('Shogirdni "Mijozlar" bo\'limidan tanlab, '
                  'shu trenerga biriktirishingiz mumkin.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xxl),
            children: [
              SectionHeader(
                tr('Shogirdlar'),
                eyebrow: name,
                trailing: Pill(text: '${mine.length}', color: AppColors.accent),
              ),
              for (final c in mine)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: _ClientRow(
                    client: c,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClientDetail(client: c, admin: owner),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Shogird qatori (xodimlar ekranida ishlatiladi)
class _ClientRow extends StatelessWidget {
  final AppUser client;
  final VoidCallback onTap;
  const _ClientRow({required this.client, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final u = client;
    final name = u.name.isEmpty ? fmtPhone(u.phone) : u.name;
    return BentoTile(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(children: [
        UserAvatar(name: name, size: 38),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleMedium),
            const SizedBox(height: 2),
            Text(
              u.profileDone
                  ? trf('{0} kg · {1} kkal', [fmtNum(u.weight), u.targetKcal])
                  : tr("Anketa to'ldirilmagan"),
              style: t.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontFeatures: tabular,
              ),
            ),
          ]),
        ),
        if (u.planId == null)
          Pill(text: tr('Rejasiz'), color: AppColors.warning)
        else
          Pill(text: tr('Reja bor'), color: AppColors.success, icon: Icons.check_rounded),
      ]),
    );
  }
}

/// Trener qilish uchun foydalanuvchi tanlash varag'i
class _PickUserSheet extends StatefulWidget {
  final List<AppUser> users;
  const _PickUserSheet({required this.users});

  @override
  State<_PickUserSheet> createState() => _PickUserSheetState();
}

class _PickUserSheetState extends State<_PickUserSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final qDigits = q.replaceAll(RegExp(r'\D'), '');
    final list = widget.users
        .where((u) =>
            u.name.toLowerCase().contains(q) || (qDigits.isNotEmpty && u.phone.contains(qDigits)))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Text(tr('Kimni trener qilamiz?'), style: Theme.of(context).textTheme.titleLarge),
      ),
      const SizedBox(height: AppSpace.md),
      TextField(
        onChanged: (v) => setState(() => _q = v),
        decoration: InputDecoration(
          hintText: tr('Ism yoki telefon raqam'),
          prefixIcon: const Icon(Icons.search),
        ),
      ),
      const SizedBox(height: AppSpace.md),
      ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
        child: list.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child:
                    Text(tr('Hech narsa topilmadi'), style: TextStyle(color: AppColors.textMuted)),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpace.sm),
                itemBuilder: (_, i) {
                  final u = list[i];
                  final name = u.name.isEmpty ? fmtPhone(u.phone) : u.name;
                  return BentoTile(
                    onTap: () => Navigator.pop(context, u),
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Row(children: [
                      UserAvatar(name: name, size: 36),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(
                              fmtPhone(u.phone),
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12.5,
                                fontFeatures: tabular,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 20, color: AppColors.textFaint),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }
}
