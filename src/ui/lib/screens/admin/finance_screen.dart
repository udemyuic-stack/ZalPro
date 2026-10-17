import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/finance.dart';
import '../../models/models.dart';
import '../../models/shop.dart';
import '../../models/subscription.dart';
import '../../services/db.dart';
import '../../services/settings.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';
import 'member_analytics_screen.dart';
import 'shop_analytics_screen.dart';

const _oylar = [
  'Yanvar',
  'Fevral',
  'Mart',
  'Aprel',
  'May',
  'Iyun',
  'Iyul',
  'Avgust',
  'Sentyabr',
  'Oktyabr',
  'Noyabr',
  'Dekabr',
];

/// Oylik moliyaviy hisobot — faqat bosh admin: abonement va do'kon tushumi, do'kon foydasi,
/// zal bo'yicha ajratib.
class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  var _month = DateTime(DateTime.now().year, DateTime.now().month);

  /// null — hamma zallar, '' — zalsiz (treneri yo'q yoki trener zalsiz)
  String? _gym;

  /// Trener ulushi, foiz
  var _pct = AppSettings.trainerSharePct;

  void _setPct(int v) {
    setState(() => _pct = v.clamp(0, 100));
    AppSettings.setTrainerSharePct(_pct);
  }

  late final _subs = Db.allSubscriptions();
  late final _orders = Db.allOrders();
  late final _products = Db.products();
  late final _clients = Db.clients();
  late final _staff = Db.staff();
  late final _gyms = Db.gyms();

  void _shift(int d) => setState(() => _month = DateTime(_month.year, _month.month + d));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Oylik hisobot'))),
      body: StreamBuilder<List<(String, Subscription)>>(
        stream: _subs,
        builder: (context, sSnap) => StreamBuilder<List<ShopOrder>>(
          stream: _orders,
          builder: (context, oSnap) => StreamBuilder<List<Product>>(
            stream: _products,
            builder: (context, pSnap) => StreamBuilder<List<AppUser>>(
              stream: _clients,
              builder: (context, cSnap) => StreamBuilder<List<AppUser>>(
                stream: _staff,
                builder: (context, stSnap) => StreamBuilder<List<Gym>>(
                  stream: _gyms,
                  builder: (context, gSnap) {
                    final err = sSnap.error ??
                        oSnap.error ??
                        pSnap.error ??
                        cSnap.error ??
                        stSnap.error ??
                        gSnap.error;
                    if (err != null) return ErrorState(error: err);
                    if (!sSnap.hasData || !oSnap.hasData || !pSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final gyms = gSnap.data ?? const <Gym>[];
                    // shogird -> treneri -> zali
                    final trainerGym = {
                      for (final s in stSnap.data ?? const <AppUser>[]) s.id: s.gymId ?? ''
                    };
                    final clientGym = {
                      for (final c in cSnap.data ?? const <AppUser>[])
                        c.id: trainerGym[c.trainerId] ?? ''
                    };
                    final gymSubs = sSnap.data!
                        .where((e) => _gym == null || (clientGym[e.$1] ?? '') == _gym)
                        .toList();
                    final subs = gymSubs.map((e) => e.$2).toList();
                    // trenerlar kesimi: tanlangan zalning shogirdlari
                    final staff = stSnap.data ?? const <AppUser>[];
                    final byTrainer = MonthlyReport.byTrainer(
                      _month,
                      subs: gymSubs,
                      clientTrainer: {
                        for (final c in cSnap.data ?? const <AppUser>[])
                          if (_gym == null || (clientGym[c.id] ?? '') == _gym)
                            c.id: c.trainerId ?? '',
                      },
                    );
                    final trainerIds = byTrainer.keys.toList()
                      ..sort((a, b) => (byTrainer[b]!.sums.values.fold(0, (x, y) => x + y))
                          .compareTo(byTrainer[a]!.sums.values.fold(0, (x, y) => x + y)));
                    String trainerName(String id) => id.isEmpty
                        ? tr('Trenersiz')
                        : (staff.where((s) => s.id == id).firstOrNull?.name ??
                            tr("O'chirilgan trener"));
                    final orders =
                        oSnap.data!.where((o) => _gym == null || o.gymId == _gym).toList();
                    final r = MonthlyReport.build(
                      _month,
                      subs: subs,
                      orders: orders,
                      products: {for (final p in pSnap.data!) p.id: p},
                    );

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xxl),
                      children: [
                        Row(children: [
                          IconButton(
                            onPressed: () => _shift(-1),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Expanded(
                            child: Text('${tr(_oylar[_month.month - 1])} ${_month.year}',
                                textAlign: TextAlign.center, style: t.titleLarge),
                          ),
                          IconButton(
                            onPressed: isCurrent ? null : () => _shift(1),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ]),
                        if (gyms.isNotEmpty) ...[
                          const SizedBox(height: AppSpace.sm),
                          Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
                            ChoiceChip(
                              label: Text(tr('Hamma zallar')),
                              selected: _gym == null,
                              onSelected: (_) => setState(() => _gym = null),
                            ),
                            for (final g in gyms)
                              ChoiceChip(
                                label: Text(g.name),
                                selected: _gym == g.id,
                                onSelected: (_) => setState(() => _gym = g.id),
                              ),
                            ChoiceChip(
                              label: Text(tr('Zalsiz')),
                              selected: _gym == '',
                              onSelected: (_) => setState(() => _gym = ''),
                            ),
                          ]),
                        ],
                        const SizedBox(height: AppSpace.lg),
                        _Card(
                          icon: Icons.account_balance_wallet_outlined,
                          color: AppColors.accent,
                          title: tr('Jami tushum'),
                          value: MonthlyReport.money(r.income),
                          feature: true,
                        ),
                        const SizedBox(height: AppSpace.md),
                        _Card(
                          icon: Icons.event_repeat_outlined,
                          color: AppColors.water,
                          title: tr('Abonement'),
                          value: MonthlyReport.money(r.subsSums),
                          subtitle: trf('{0} ta abonement sotildi', [r.subsCount]),
                        ),
                        const SizedBox(height: AppSpace.md),
                        _Card(
                          icon: Icons.storefront_outlined,
                          color: AppColors.protein,
                          title: tr("Do'kon tushumi"),
                          value: MonthlyReport.money(r.shopSums),
                          subtitle: trf('{0} ta buyurtma berildi', [r.ordersCount]),
                        ),
                        const SizedBox(height: AppSpace.md),
                        _Card(
                          icon: Icons.trending_up,
                          color: AppColors.success,
                          title: tr("Do'kon foydasi"),
                          value: MonthlyReport.money(r.profit),
                          subtitle: r.noCostOrders == 0
                              ? tr('Sotilgan narx − tan narx')
                              : trf(
                                  '{0} ta buyurtmada tan narx yo\'q — '
                                  'foydaga qo\'shilmadi',
                                  [r.noCostOrders]),
                        ),
                        const SizedBox(height: AppSpace.md),
                        BentoTile(
                          key: const Key('member-analytics-entry'),
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
                              child:
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(tr("A'zolar tahlili"), style: t.titleMedium),
                                const SizedBox(height: 2),
                                Text(
                                  tr("Ketish xavfi, qolish ulushi va trenerlar natijasi"),
                                  style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                                ),
                              ]),
                            ),
                            Icon(Icons.chevron_right, size: 20, color: AppColors.textFaint),
                          ]),
                        ),
                        const SizedBox(height: AppSpace.md),
                        BentoTile(
                          key: const Key('shop-analytics-entry'),
                          padding: const EdgeInsets.all(AppSpace.md),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ShopAnalyticsScreen()),
                          ),
                          child: Row(children: [
                            IconBadge(Icons.insights_outlined, color: AppColors.accent, size: 38),
                            const SizedBox(width: AppSpace.md),
                            Expanded(
                              child:
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(tr("Do'kon tahlili"), style: t.titleMedium),
                                const SizedBox(height: 2),
                                Text(
                                  tr("Eng ko'p sotilgan tovarlar va hafta kunlari bo'yicha savdo"),
                                  style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                                ),
                              ]),
                            ),
                            Icon(Icons.chevron_right, size: 20, color: AppColors.textFaint),
                          ]),
                        ),
                        const SizedBox(height: AppSpace.xl),
                        SectionHeader(
                          tr('Trenerlar haqi'),
                          eyebrow: tr('Abonement tushumidan ulush'),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              onPressed: _pct > 0 ? () => _setPct(_pct - 5) : null,
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text('$_pct%', style: t.titleMedium),
                            IconButton(
                              onPressed: _pct < 100 ? () => _setPct(_pct + 5) : null,
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ]),
                        ),
                        if (trainerIds.isEmpty)
                          Text(tr("Shogird yo'q"),
                              style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
                        for (final id in trainerIds)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpace.sm),
                            child: BentoTile(
                              padding: const EdgeInsets.all(AppSpace.md),
                              child: Row(children: [
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(trainerName(id), style: t.titleSmall),
                                        const SizedBox(height: 2),
                                        Text(
                                          trf(
                                              '{0} shogird · '
                                              '{1} abonement · '
                                              '{2}',
                                              [
                                                byTrainer[id]!.clients,
                                                byTrainer[id]!.subsCount,
                                                MonthlyReport.money(byTrainer[id]!.sums)
                                              ]),
                                          style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                                        ),
                                      ]),
                                ),
                                const SizedBox(width: AppSpace.sm),
                                Pill(
                                  text: MonthlyReport.money(byTrainer[id]!.share(_pct)),
                                  color: AppColors.success,
                                ),
                              ]),
                            ),
                          ),
                        const SizedBox(height: AppSpace.lg),
                        Text(
                          tr("Abonement to'langan sanasi bo'yicha, do'kon — buyurtma berilgan "
                              "sanasi bo'yicha hisoblanadi. Foyda tovarning hozirgi tan narxidan. "
                              "Trener haqi — shogirdlari to'lagan abonementning tanlangan foizi; "
                              'foiz shu qurilmada eslab qolinadi.'),
                          style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, value;
  final String? subtitle;
  final bool feature;
  const _Card({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    this.subtitle,
    this.feature = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return BentoTile(
      feature: feature,
      child: Row(children: [
        IconBadge(icon, color: color, size: 40),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 2),
            Text(value, style: t.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            ],
          ]),
        ),
      ]),
    );
  }
}
