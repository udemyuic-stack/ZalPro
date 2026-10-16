import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../models/shop.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/product_image.dart';
import '../../widgets/ui.dart';

/// Sotuv hisoboti — zal egasi uchun: kim nechta sotdi, qancha pul, qaysi tovar.
/// Barmen ham shu ekranni ko'radi, lekin faqat o'z sotuvini (ownerView: false).
class SalesReportScreen extends StatefulWidget {
  final AppUser me;

  /// true — hamma sotuvchi kesimida (zal egasi); false — faqat o'zi (barmen)
  final bool ownerView;
  const SalesReportScreen({super.key, required this.me, this.ownerView = true});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  static const _periods = [('Bugun', 1), ('7 kun', 7), ('30 kun', 30), ('Hammasi', 0)];
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Sotuv hisoboti'))),
      body: StreamBuilder<List<ShopOrder>>(
        stream: Db.ordersFor(widget.me),
        builder: (context, snap) {
          if (snap.hasError) return ErrorState(error: snap.error);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final all = snap.data!;
          final orders =
              widget.ownerView ? all : all.where((o) => o.givenBy == widget.me.id).toList();

          final total = SalesReport.of(orders, days: _days);
          final sellers = SalesReport.bySeller(orders, days: _days);
          final products = SalesReport.byProduct(orders, days: _days);
          final sold = SalesReport.sold(orders, days: _days);

          return StreamBuilder<List<AppUser>>(
            stream: Db.staff(),
            builder: (context, staffSnap) {
              final names = {
                for (final s in staffSnap.data ?? const <AppUser>[])
                  s.id: s.name.isEmpty ? fmtPhone(s.phone) : s.name,
              };

              return ListView(
                padding:
                    const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xxl),
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final (label, days) in _periods)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpace.sm),
                          child: ChoiceChip(
                            selected: _days == days,
                            onSelected: (_) => setState(() => _days = days),
                            label: Text(tr(label)),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(height: AppSpace.md),

                  // ---------- jami ----------
                  BentoTile(
                    feature: true,
                    padding: const EdgeInsets.all(AppSpace.lg),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Eyebrow(widget.ownerView ? tr('Jami tushum') : tr('Men sotdim')),
                      const SizedBox(height: AppSpace.xs),
                      Text(total.money, style: t.headlineMedium?.copyWith(color: AppColors.accent)),
                      const SizedBox(height: 2),
                      Text(trf('{0} ta buyurtma berildi', [total.count]),
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ]),
                  ),

                  // ---------- sotuvchilar ----------
                  if (widget.ownerView) ...[
                    const SizedBox(height: AppSpace.xl),
                    SectionHeader(tr('Kim sotdi'), eyebrow: tr('Hisobot')),
                    if (sellers.isEmpty)
                      Text(tr('Bu davrda sotuv bo‘lmagan'),
                          style: TextStyle(color: AppColors.textMuted)),
                    for (final e
                        in (sellers.entries.toList()
                          ..sort((a, b) => b.value.sum.compareTo(a.value.sum))))
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.sm),
                        child: BentoTile(
                          padding: const EdgeInsets.all(AppSpace.md),
                          child: Row(children: [
                            UserAvatar(name: names[e.key] ?? tr('Noma’lum'), size: 38),
                            const SizedBox(width: AppSpace.md),
                            Expanded(
                              child:
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(
                                  e.key.isEmpty
                                      ? tr('Kim bergani yozilmagan')
                                      : (names[e.key] ?? tr('Xodim')),
                                  style: t.titleSmall,
                                ),
                                Text(trf('{0} ta buyurtma', [e.value.count]),
                                    style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                              ]),
                            ),
                            Text(e.value.money,
                                style: t.titleSmall?.copyWith(color: AppColors.accent)),
                          ]),
                        ),
                      ),
                  ],

                  // ---------- tovarlar ----------
                  const SizedBox(height: AppSpace.xl),
                  SectionHeader(tr('Qaysi tovar'), eyebrow: tr('Sotilgani')),
                  if (products.isEmpty)
                    Text(tr('Bu davrda sotuv bo‘lmagan'),
                        style: TextStyle(color: AppColors.textMuted)),
                  for (final e
                      in (products.entries.toList()
                        ..sort((a, b) => b.value.sum.compareTo(a.value.sum))))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.sm),
                      child: BentoTile(
                        padding: const EdgeInsets.all(AppSpace.md),
                        child: Row(children: [
                          ProductImage(category: '', name: e.key, size: 38),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(e.key,
                                  style: t.titleSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(trf('{0} dona', [e.value.count]),
                                  style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                            ]),
                          ),
                          Text(e.value.money,
                              style: t.titleSmall?.copyWith(color: AppColors.accent)),
                        ]),
                      ),
                    ),

                  // ---------- ro'yxat ----------
                  const SizedBox(height: AppSpace.xl),
                  SectionHeader(tr('Har bir sotuv'), eyebrow: trf('{0} ta', [sold.length])),
                  for (final o in sold)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.xs),
                      child: Row(children: [
                        Expanded(
                          child: Text('${o.title} × ${o.qty}',
                              style: t.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Text(
                          SalesReport.soldAt(o) == null ? '' : uzDate(SalesReport.soldAt(o)!),
                          style: TextStyle(color: AppColors.textFaint, fontSize: 11.5),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Text(o.totalText, style: t.bodySmall?.copyWith(fontFeatures: tabular)),
                      ]),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
