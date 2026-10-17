import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/shop.dart';
import '../../models/shop_analytics.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';

typedef ShopAnalyticsLoader = Future<ShopAnalytics> Function(DateTime from, DateTime to);

const _periods = [7, 30, 90];

class ShopAnalyticsScreen extends StatefulWidget {
  final ShopAnalyticsLoader? loader;
  const ShopAnalyticsScreen({super.key, this.loader});

  @override
  State<ShopAnalyticsScreen> createState() => _ShopAnalyticsScreenState();
}

class _ShopAnalyticsScreenState extends State<ShopAnalyticsScreen> {
  var _days = 30;
  late Future<ShopAnalytics> _future = _load();

  Future<ShopAnalytics> _load() {
    final now = DateTime.now();
    final to = DateTime(now.year, now.month, now.day);
    final from = to.subtract(Duration(days: _days - 1));
    return (widget.loader ?? Db.shopAnalytics)(from, to);
  }

  void _setDays(int d) {
    if (d == _days) return;
    setState(() {
      _days = d;
      _future = _load();
    });
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr("Do'kon tahlili"))),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
            child: SizedBox(
              height: kTouchTarget,
              child: Row(children: [
                for (final d in _periods)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: d == _periods.last ? 0 : AppSpace.sm),
                      child: ChoiceChip(
                        key: Key('period-$d'),
                        showCheckmark: false,
                        label: SizedBox(
                          width: double.infinity,
                          child: Text(
                            trf('{0} kun', [d]),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        selected: _days == d,
                        onSelected: (_) => _setDays(d),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          Expanded(
            child: FutureBuilder<ShopAnalytics>(
              key: ValueKey(_future),
              future: _future,
              builder: (context, snap) {
                if (snap.hasError) return ErrorState(error: snap.error, onRetry: _retry);
                final data = snap.data;
                if (data == null) return const Center(child: CircularProgressIndicator());
                if (data.isEmpty) {
                  return EmptyState(
                    icon: Icons.storefront_outlined,
                    title: tr("Bu davrda sotuv yo'q"),
                    subtitle: tr('Berilgan buyurtmalar shu yerda ko\'rinadi'),
                  );
                }
                return _Body(data: data);
              },
            ),
          ),
        ]),
      );
}

class _Body extends StatelessWidget {
  final ShopAnalytics data;
  const _Body({required this.data});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xxl),
        children: [
          for (final c in data.currencies) _CurrencySection(data: data, currency: c),
        ],
      );
}

class _CurrencySection extends StatelessWidget {
  final ShopAnalytics data;
  final String currency;
  const _CurrencySection({required this.data, required this.currency});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final totals = data.totals[currency] ?? const ShopTotals();
    final top = data.topFor(currency);
    return Column(
      key: Key('section-$currency'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(currency == usd ? tr('Dollar (\$)') : tr("So'm")),
        _Stat(
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.accent,
          label: tr('Tushum'),
          value: fmtMoney(totals.revenue, currency),
          feature: true,
        ),
        const SizedBox(height: AppSpace.sm),
        _Stat(
          icon: Icons.trending_up,
          color: AppColors.success,
          label: tr('Foyda'),
          value: fmtMoney(totals.profit, currency),
        ),
        const SizedBox(height: AppSpace.sm),
        _Stat(
          icon: Icons.receipt_long_outlined,
          color: AppColors.protein,
          label: tr('Buyurtmalar'),
          value: '${totals.orders}',
        ),
        if (totals.noCostOrders > 0) ...[
          const SizedBox(height: AppSpace.sm),
          Row(
            key: Key('no-cost-$currency'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: AppColors.textMuted),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  trf("Tannarxi yo'q: {0} ta buyurtma", [totals.noCostOrders]),
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpace.lg),
        SectionHeader(tr("Eng ko'p sotilgan")),
        for (final p in top) _ProductRow(product: p),
        const SizedBox(height: AppSpace.lg),
        SectionHeader(tr("Hafta kunlari bo'yicha")),
        _WeekdayBars(rows: data.weekdaysFor(currency), currency: currency),
        const SizedBox(height: AppSpace.xl),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool feature;
  const _Stat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.feature = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return BentoTile(
      feature: feature,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(children: [
        IconBadge(icon, color: color, size: 40),
        const SizedBox(width: AppSpace.md),
        Expanded(child: Text(label, style: t.bodyMedium?.copyWith(color: AppColors.textMuted))),
        const SizedBox(width: AppSpace.sm),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(value, style: t.titleLarge),
          ),
        ),
      ]),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final TopProduct product;
  const _ProductRow({required this.product});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: BentoTile(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.name, style: t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                trf('{0} dona · tushum {1}', [
                  product.units,
                  fmtMoney(product.revenue, product.currency),
                ]),
                style: t.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ]),
          ),
          const SizedBox(width: AppSpace.sm),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                fmtMoney(product.profit, product.currency),
                style: t.titleSmall?.copyWith(color: AppColors.success),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _WeekdayBars extends StatelessWidget {
  final List<WeekdaySales> rows;
  final String currency;
  const _WeekdayBars({required this.rows, required this.currency});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final labels = [tr('Du'), tr('Se'), tr('Ch'), tr('Pa'), tr('Ju'), tr('Sh'), tr('Ya')];
    final peak = rows.fold<int>(0, (m, r) => r.revenue > m ? r.revenue : m);
    return BentoTile(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(
                width: 28,
                child: Text(labels[r.weekday % 7],
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final w = peak == 0 ? 0.0 : box.maxWidth * r.revenue / peak;
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        key: Key('bar-$currency-${r.weekday}'),
                        width: r.revenue > 0 ? w.clamp(4.0, box.maxWidth) : 0,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              SizedBox(
                width: 104,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(fmtMoney(r.revenue, currency), style: t.bodySmall),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}
