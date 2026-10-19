import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../models/shop.dart';
import '../../services/api/api_error.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/food_image.dart';
import '../../widgets/image_viewer.dart';
import '../../widgets/product_image.dart';
import '../../widgets/ui.dart';

/// Shogird uchun do'kon: forma, suv idishlari, anjomlar va dobavkalar.
/// Buyurtma berilganda trenerga chatga xabar tushadi, to'lov zalda naqd.
class ShopScreen extends StatefulWidget {
  final AppUser user;
  const ShopScreen({super.key, required this.user});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late final _products = Db.products();
  late final _orders = Db.myOrders(widget.user.id);

  /// null — hamma bo'limlar
  /// Asosiy bo'lim (`Forma` / `Anjomlar` / `Dobavkalar`), null — hammasi
  String? _group;

  /// Dobavkalar ichidagi kichik bo'lim (`Protein` ...), null — hammasi
  String? _category;

  Future<void> _order(Product p) async {
    var qty = 1;
    String? size = p.sizes.length == 1 ? p.sizes.first : null;
    String? color = p.colors.length == 1 ? p.colors.first : null;
    final ok = await showSheet<bool>(
      context,
      StatefulBuilder(
        builder: (ctx, setS) {
          final t = Theme.of(ctx).textTheme;
          final avail = p.stockFor(size);
          final max = avail < 20 ? avail : 20;
          if (qty > max && max > 0) qty = max;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: AppSpace.md),
            if (p.gallery.length > 1) ...[
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: p.gallery.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => showImageViewer(ctx, p.gallery, initial: i),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: netImage(
                        p.gallery[i],
                        width: 150,
                        height: 150,
                        cacheWidth: (150 * MediaQuery.devicePixelRatioOf(ctx)).round(),
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.md),
            ],
            Row(children: [
              GestureDetector(
                onTap: p.gallery.isEmpty ? null : () => showImageViewer(ctx, p.gallery),
                child: ProductImage(category: p.category, name: p.name, url: p.image, size: 56),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.displayName, style: t.titleMedium),
                  Text(p.priceText, style: t.bodyMedium?.copyWith(color: AppColors.text)),
                ]),
              ),
            ]),
            if (p.sizes.isNotEmpty) ...[
              const SizedBox(height: AppSpace.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(tr("O'lchamni tanlang"),
                    style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
              ),
              const SizedBox(height: AppSpace.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
                  for (final sz in p.sizes)
                    ChoiceChip(
                      selected: size == sz,
                      onSelected: (_) => setS(() => size = sz),
                      label: Text(sz),
                    ),
                ]),
              ),
            ],
            if (p.colors.isNotEmpty) ...[
              const SizedBox(height: AppSpace.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(tr('Rangni tanlang'),
                    style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
              ),
              const SizedBox(height: AppSpace.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
                  for (final c in p.colors)
                    ChoiceChip(
                      selected: color == c,
                      onSelected: (_) => setS(() => color = c),
                      label: Text(tr(c)),
                    ),
                ]),
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              StepButton(
                tonal: true,
                icon: Icons.remove,
                label: tr('Kamaytirish'),
                onPressed: qty > 1 ? () => setS(() => qty--) : null,
              ),
              SizedBox(
                width: 72,
                child: Text('$qty', textAlign: TextAlign.center, style: t.headlineSmall),
              ),
              StepButton(
                tonal: true,
                icon: Icons.add,
                label: tr('Oshirish'),
                onPressed: qty < max ? () => setS(() => qty++) : null,
              ),
            ]),
            const SizedBox(height: AppSpace.md),
            Text(trf('Jami: {0}', [fmtMoney(p.price * qty, p.currency)]), style: t.titleLarge),
            const SizedBox(height: AppSpace.sm),
            Text(
              tr("To'lov zalda, naqd. Trener buyurtmani ko'radi va tayyorlab qo'yadi."),
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpace.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (p.sizes.isNotEmpty && size == null) ||
                        (p.colors.isNotEmpty && color == null) ||
                        avail <= 0
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: Text(p.sizes.isNotEmpty && size == null
                    ? tr("Avval o'lchamni tanlang")
                    : p.colors.isNotEmpty && color == null
                        ? tr('Avval rangni tanlang')
                        : avail <= 0
                            ? tr('Tugagan')
                            : tr('Buyurtma berish')),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr('Bekor qilish')),
              ),
            ),
          ]);
        },
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await Db.createOrder(widget.user, p, qty, size: size ?? '', color: color ?? '');
      if (mounted) showSnack(context, tr('Buyurtma yuborildi — trener xabardor bo\'ldi'));
    } catch (e) {
      if (mounted) showSnack(context, trf("Bo'lmadi: {0}", [apiErrorText(e)]));
    }
  }

  Future<void> _cancel(ShopOrder o) async {
    final ok = await confirm(
      context,
      title: tr('Buyurtmani bekor qilish'),
      message: trf('"{0}" buyurtmasi bekor qilinsinmi?', [o.productName]),
      ok: tr('Bekor qilish'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await Db.cancelOrder(o.id);
    } catch (e) {
      if (mounted) showSnack(context, trf("Bo'lmadi: {0}", [apiErrorText(e)]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return StreamBuilder<List<Product>>(
      stream: _products,
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final all = snap.data!.where((p) => p.active && p.price > 0).toList();
        final groups =
            shopGroups.where((g) => all.any((p) => shopGroupOf(p.category) == g)).toList();
        final group = groups.contains(_group) ? _group! : (groups.isEmpty ? '' : groups.first);
        final subs = group == 'Dobavkalar'
            ? supplementCategories.where((c) => all.any((p) => p.category == c)).toList()
            : const <String>[];
        final sub = subs.contains(_category) ? _category! : (subs.isEmpty ? '' : subs.first);
        final list = all
            .where((p) => shopGroupOf(p.category) == group)
            .where((p) => subs.isEmpty || p.category == sub)
            .toList();

        return StreamBuilder<List<ShopOrder>>(
          stream: _orders,
          builder: (context, oSnap) {
            if (oSnap.hasError) return ErrorState(error: oSnap.error);
            final orders = oSnap.data ?? const <ShopOrder>[];
            final waiting = orders.where((o) => o.isNew).toList();

            return Scaffold(
              appBar: AppBar(title: Text(tr("Do'kon"))),
              body: CustomScrollView(slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, 0),
                  sliver: SliverList.list(children: [
                    if (waiting.isNotEmpty) ...[
                      SectionHeader(tr('Mening buyurtmalarim'),
                          trailing: Pill(text: '${waiting.length}', color: AppColors.warning)),
                      for (final o in waiting)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.sm),
                          child: BentoTile(
                            child: Row(children: [
                              ProductImage(category: o.category, name: o.productName, size: 44),
                              const SizedBox(width: AppSpace.md),
                              Expanded(
                                child:
                                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${o.title} × ${o.qty}', style: t.titleSmall),
                                  Text(
                                    '${o.totalText} • ${o.statusLabel}',
                                    style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                                  ),
                                ]),
                              ),
                              TextButton(onPressed: () => _cancel(o), child: Text(tr('Bekor'))),
                            ]),
                          ),
                        ),
                      const SizedBox(height: AppSpace.md),
                    ],
                    if (all.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.xxl),
                        child: EmptyState(
                          icon: Icons.storefront_outlined,
                          title: tr("Do'kon hozircha bo'sh"),
                          subtitle: tr('Trener tovarlarni kiritgach, shu yerda ko\'rinadi.'),
                        ),
                      )
                    else ...[
                      EdgeFade(
                        child: Row(children: [
                          for (final g in groups)
                            _CatChip(
                              label: g,
                              icon: shopIcon(g == 'Dobavkalar' ? 'Boshqa' : g),
                              selected: group == g,
                              onTap: () => setState(() {
                                _group = g;
                                _category = null;
                              }),
                            ),
                        ]),
                      ),
                      if (subs.isNotEmpty) ...[
                        const SizedBox(height: AppSpace.sm),
                        EdgeFade(
                          child: Row(children: [
                            for (final c in subs)
                              _CatChip(
                                label: c,
                                icon: shopIcon(c),
                                selected: sub == c,
                                onTap: () => setState(() => _category = c),
                              ),
                          ]),
                        ),
                      ],
                      const SizedBox(height: AppSpace.md),
                      Text(
                        tr("To'lov zalda, naqd — ilovada karta so'ralmaydi."),
                        style: t.bodySmall?.copyWith(color: AppColors.textFaint),
                      ),
                      const SizedBox(height: AppSpace.md),
                    ],
                  ]),
                ),
                if (all.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                    sliver: SliverList.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.sm),
                        child: _ProductTile(
                          key: ValueKey(list[i].id),
                          product: list[i],
                          onOrder: () => _order(list[i]),
                        ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.xxl),
                  sliver: SliverList.list(children: [
                    if (orders.any((o) => !o.isNew)) ...[
                      const SizedBox(height: AppSpace.lg),
                      SectionHeader(tr('Oldingi buyurtmalar')),
                      for (final o in orders.where((o) => !o.isNew).take(10))
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.xs),
                          child: Row(children: [
                            Expanded(
                              child: Text('${o.title} × ${o.qty}',
                                  style: t.bodyMedium, overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Pill(
                              text: o.statusLabel,
                              color: o.isGiven ? AppColors.success : AppColors.textFaint,
                            ),
                          ]),
                        ),
                    ],
                  ]),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

@visibleForTesting
class EdgeFade extends StatelessWidget {
  final Widget child;
  const EdgeFade({required this.child});

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => const LinearGradient(
          colors: [Colors.black, Colors.black, Colors.transparent],
          stops: [0, 0.92, 1],
        ).createShader(r),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: child),
      );
}

class _CatChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip({required this.label, this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: AppSpace.sm),
        child: ChoiceChip(
          selected: selected,
          onSelected: (_) => onTap(),
          avatar: icon == null
              ? null
              : Icon(icon, size: 16, color: selected ? AppColors.text : AppColors.accentText),
          label: Text(tr(label)),
        ),
      );
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onOrder;
  const _ProductTile({super.key, required this.product, required this.onOrder});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = product;
    return BentoTile(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: p.gallery.isEmpty ? null : () => showImageViewer(context, p.gallery),
          child: ProductImage(category: p.category, name: p.name, url: p.image, size: 60),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.displayName, style: t.titleSmall),
            if (p.displayNote.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(p.displayNote,
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            const SizedBox(height: AppSpace.sm),
            if (p.sizes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(trf("O'lchamlar: {0}", [p.sizes.join(' · ')]),
                    style: t.bodySmall?.copyWith(color: AppColors.water)),
              ),
            Row(children: [
              Text(p.priceText, style: t.titleSmall?.copyWith(color: AppColors.text)),
              const SizedBox(width: AppSpace.sm),
              if (p.totalStock <= 0)
                Pill(text: tr('Hozir yo\'q'), color: AppColors.danger)
              else if (p.totalStock <= 3)
                Pill(text: trf('Qoldi: {0}', [p.totalStock]), color: AppColors.warning),
            ]),
          ]),
        ),
        const SizedBox(width: AppSpace.sm),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, kTouchTarget)),
          onPressed: p.totalStock > 0 ? onOrder : null,
          child: Text(tr('Olaman')),
        ),
      ]),
    );
  }
}
