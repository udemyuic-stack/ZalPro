import 'package:flutter/material.dart';
import '../../core/input_rules.dart';
import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../models/shop.dart';
import '../../services/api/api_error.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/lazy_stack.dart';
import '../../widgets/product_image.dart';
import '../../widgets/product_photos.dart';
import '../../widgets/ui.dart';

/// Trener (va bosh admin) uchun do'kon: buyurtmalar va tovarlar.
/// Trener faqat O'Z shogirdlarining buyurtmalarini ko'radi, bosh admin — hammasini.
class ShopAdminScreen extends StatefulWidget {
  final AppUser admin;
  const ShopAdminScreen({super.key, required this.admin});

  @override
  State<ShopAdminScreen> createState() => _ShopAdminScreenState();
}

class _ShopAdminScreenState extends State<ShopAdminScreen> {
  // bosh admin — hamma buyurtma; barmen — o'z zali; trener — faqat o'z shogirdlariniki
  late final _orders = Db.ordersFor(widget.admin);
  late final _products = Db.products();
  int _tab = 0;

  Future<void> _setStatus(ShopOrder o, String status) async {
    if (status == orderGiven) {
      final ok = await confirm(
        context,
        title: tr('Berildi deb belgilash'),
        message: trf(
          '{0}: "{1}" × {2} berildimi? Omborxonadan ayiriladi, qaytarib bo\'lmaydi.',
          [o.clientName, o.productName, o.qty],
        ),
        ok: tr('Berildi'),
      );
      if (!ok || !mounted) return;
    }
    if (status == orderCanceled) {
      final ok = await confirm(
        context,
        title: tr('Buyurtmani bekor qilish'),
        message: trf('{0}: "{1}" × {2} bekor qilinsinmi?', [o.clientName, o.productName, o.qty]),
        ok: tr('Bekor qilish'),
        destructive: true,
      );
      if (!ok) return;
    }
    try {
      await Db.setOrderStatus(o, status, widget.admin.id);
      if (mounted) {
        showSnack(
            context, status == orderGiven ? tr('Berildi deb belgilandi') : tr('Bekor qilindi'));
      }
    } catch (e) {
      if (mounted) showSnack(context, trf("Bo'lmadi: {0}", [apiErrorText(e)]));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(
              onPressed: () => editProduct(context),
              icon: const Icon(Icons.add),
              label: Text(tr('Tovar')),
            )
          : null,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.sm),
          child: AppSegmented<int>(
            segments: [
              AppSegment(value: 0, label: tr('Buyurtmalar')),
              AppSegment(value: 1, label: tr('Tovarlar')),
            ],
            selected: _tab,
            onChanged: (v) => setState(() => _tab = v),
          ),
        ),
        Expanded(
          child: LazyIndexedStack(
            index: _tab,
            children: [
              _OrdersTab(stream: _orders, onStatus: _setStatus),
              _ProductsTab(stream: _products),
            ],
          ),
        ),
      ]),
    );
  }
}

class _OrdersTab extends StatelessWidget {
  final Stream<List<ShopOrder>> stream;
  final Future<void> Function(ShopOrder, String) onStatus;
  const _OrdersTab({required this.stream, required this.onStatus});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return StreamBuilder<List<ShopOrder>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final orders = snap.data!;
        if (orders.isEmpty) {
          return EmptyState(
            icon: Icons.receipt_long_outlined,
            title: tr("Buyurtma yo'q"),
            subtitle:
                tr("Shogird do'kondan tovar so'rasa, shu yerda chiqadi va chatga xabar keladi."),
          );
        }
        final waiting = orders.where((o) => o.isNew).toList();
        final done = orders.where((o) => !o.isNew).toList();
        final month = SalesReport.of(orders, days: 30);

        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.xxl),
          children: [
            BentoTile(
              feature: true,
              child: Row(children: [
                IconBadge(Icons.payments_outlined, color: AppColors.success),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(trf('30 kunda: {0}', [month.money]), style: t.titleMedium),
                    Text(trf('{0} ta buyurtma berildi', [month.count]),
                        style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: AppSpace.md),
            SectionHeader(tr('Kutilmoqda'),
                trailing: Pill(text: '${waiting.length}', color: AppColors.warning)),
            if (waiting.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm, left: 4),
                child:
                    Text(tr('Yangi buyurtma yo\'q'), style: TextStyle(color: AppColors.textMuted)),
              ),
            for (final o in waiting)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: OrderTile(order: o, onStatus: onStatus),
              ),
            if (done.isNotEmpty) ...[
              const SizedBox(height: AppSpace.lg),
              SectionHeader(tr('Tarix')),
              for (final o in done.take(30))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: OrderTile(order: o, onStatus: onStatus),
                ),
            ],
          ],
        );
      },
    );
  }
}

class OrderTile extends StatelessWidget {
  final ShopOrder order;
  final Future<void> Function(ShopOrder, String) onStatus;
  const OrderTile({super.key, required this.order, required this.onStatus});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final o = order;
    final who = o.clientName.isEmpty ? fmtPhone(o.clientPhone) : o.clientName;
    return BentoTile(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          ProductImage(category: o.category, name: o.productName, size: 42),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${o.title} × ${o.qty}', style: t.titleSmall),
              Text(
                who,
                style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (o.createdAt != null)
                Text(
                  uzDate(o.createdAt!),
                  style: t.bodySmall?.copyWith(color: AppColors.textFaint),
                ),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(o.totalText, style: t.titleSmall),
            if (!o.isNew)
              Pill(
                text: o.statusLabel,
                color: o.isGiven ? AppColors.success : AppColors.textFaint,
              ),
          ]),
        ]),
        if (o.isNew) ...[
          const SizedBox(height: AppSpace.sm),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, kTouchTarget)),
                onPressed: () => onStatus(o, orderGiven),
                icon: const Icon(Icons.check, size: 18),
                label: Text(tr('Berildi')),
              ),
            ),
            const SizedBox(width: AppSpace.xl),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, kTouchTarget),
                foregroundColor: AppColors.danger,
              ),
              onPressed: () => onStatus(o, orderCanceled),
              child: Text(tr('Bekor')),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _ProductsTab extends StatelessWidget {
  final Stream<List<Product>> stream;
  const _ProductsTab({required this.stream});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return StreamBuilder<List<Product>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final all = snap.data!;
        if (all.isEmpty) {
          return EmptyState(
            icon: Icons.storefront_outlined,
            title: tr("Do'kon bo'sh"),
            subtitle: tr('Forma, suv idishlari, anjomlar va dobavkalar shu yerga kiritiladi. '
                "Shogird narxini ko'radi va buyurtma beradi, to'lov zalda naqd."),
            action: FilledButton.icon(
              onPressed: () => editProduct(context),
              icon: const Icon(Icons.add),
              label: Text(tr("Birinchi tovarni qo'shish")),
            ),
          );
        }
        // Qatorlar dangasa quriladi (faqat ko'ringani) - 150 ga yaqin rasmli tovar bor
        Widget tile(Product p) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: _ProductAdminTile(key: ValueKey(p.id), product: p),
            );
        final rows = <Widget Function()>[
          for (final c in shopCategories) ...[
            // Dobavkalar guruhining boshi — bitta umumiy sarlavha
            if (c == supplementCategories.first &&
                all.any((p) => supplementCategories.contains(p.category)))
              () => SectionHeader(
                    tr('Dobavkalar'),
                    trailing: Pill(
                      text: '${all.where((p) => supplementCategories.contains(p.category)).length}',
                      color: shopColor('Boshqa'),
                    ),
                  ),
            if (all.any((p) => p.category == c)) ...[
              () => SubHeader(
                    tr(c),
                    count: all.where((p) => p.category == c).length,
                    color: shopColor(c),
                  ),
              for (final p in all.where((p) => p.category == c)) () => tile(p),
            ],
          ],
          // Bo'limi noto'g'ri yozilgan eski yozuvlar ko'rinmay qolmasin
          for (final p in all.where((p) => !shopCategories.contains(p.category))) () => tile(p),
          () => const SizedBox(height: AppSpace.md),
          () => Text(
                tr("Qoldiq: tovar berilganda avtomatik kamayadi. Tugasa shogird buyurtma bera olmaydi."),
                style: t.bodySmall?.copyWith(color: AppColors.textFaint),
              ),
        ];
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, 96),
          itemCount: rows.length,
          itemBuilder: (_, i) => rows[i](),
        );
      },
    );
  }
}

class _ProductAdminTile extends StatelessWidget {
  final Product product;
  const _ProductAdminTile({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = product;
    return BentoTile(
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: () => editProduct(context, p),
      child: Row(children: [
        ProductImage(category: p.category, name: p.name, url: p.image, size: 48),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.displayName, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              Pill(text: p.priceText, color: AppColors.accent),
              Pill(
                text: p.totalStock > 0 ? trf('Qoldiq: {0}', [p.totalStock]) : tr('Tugagan'),
                color: p.totalStock > 0 ? AppColors.textMuted : AppColors.danger,
              ),
              if (p.sizes.isNotEmpty) Pill(text: p.sizes.join(' · '), color: AppColors.water),
              if (p.colors.isNotEmpty) Pill(text: p.colors.join(' · '), color: AppColors.protein),
              if (p.margin > 0)
                Pill(text: trf('Foyda: {0}', [fmtSum(p.margin)]), color: AppColors.success),
              if (p.gallery.length > 1)
                Pill(text: trf('{0} rasm', [p.gallery.length]), color: AppColors.textMuted),
              if (!p.active) Pill(text: tr('Sotuvda emas'), color: AppColors.warning),
            ]),
          ]),
        ),
        const Icon(Icons.chevron_right),
      ]),
    );
  }
}

/// Tovar qo'shish/tahrirlash varag'i. [p] null bo'lsa — yangi tovar.
Future<void> editProduct(BuildContext context, [Product? p]) async {
  final name = TextEditingController(text: p?.name);
  final note = TextEditingController(text: p?.note);
  final nameRu = TextEditingController(text: p?.nameRu);
  final nameEn = TextEditingController(text: p?.nameEn);
  final noteRu = TextEditingController(text: p?.noteRu);
  final noteEn = TextEditingController(text: p?.noteEn);
  final price = TextEditingController(text: p == null || p.price == 0 ? '' : '${p.price}');
  final stock = TextEditingController(text: '${p?.stock ?? 1}');
  final costPrice =
      TextEditingController(text: p == null || p.costPrice == 0 ? '' : '${p.costPrice}');
  var cover = p?.image ?? '';
  final sizes = TextEditingController(text: p?.sizes.join(', '));
  final colors = TextEditingController(text: p?.colors.join(', '));
  final sizeStockControllers = <String, TextEditingController>{};
  TextEditingController sizeStockCtrl(String sz) => sizeStockControllers.putIfAbsent(
      sz, () => TextEditingController(text: '${p?.sizeStock[sz] ?? 0}'));
  var category = p?.category ?? shopCategories.first;
  var currency = p?.currency ?? uzs;
  var active = p?.active ?? true;
  int n(TextEditingController c) => InputRules.parseInt(c.text) ?? 0;
  final productForm = GlobalKey<FormState>();

  final saved = await showSheet<bool>(
    context,
    StatefulBuilder(
      builder: (ctx, setS) => SingleChildScrollView(
        child: Form(
          key: productForm,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: AppSpace.md),
            Row(children: [
              ProductImage(
                category: category,
                name: name.text,
                url: cover,
                size: 52,
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(p == null ? tr("Yangi tovar") : tr('Tovarni tahrirlash'),
                    style: Theme.of(ctx).textTheme.titleLarge),
              ),
            ]),
            const SizedBox(height: AppSpace.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(spacing: AppSpace.sm, children: [
                for (final c in shopCategories)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: kTouchTarget),
                    child: ChoiceChip(
                      selected: category == c,
                      onSelected: (_) => setS(() => category = c),
                      avatar: Icon(shopIcon(c), size: 16),
                      label: Text(c),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: name,
              autofocus: p == null,
              maxLength: InputLimits.productName,
              buildCounter: InputRules.counterAtEighty,
              validator: InputRules.required(InputLimits.productName),
              textCapitalization: TextCapitalization.sentences,
              // nom yozilganda yuqoridagi rasm ham yangilanadi (protein, gainer ...)
              onChanged: (_) => setS(() {}),
              decoration: InputDecoration(
                  labelText: tr('Nomi'), hintText: tr('Protein izolyat 900 g (shokolad)')),
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: note,
              maxLines: 2,
              maxLength: InputLimits.productNote,
              buildCounter: InputRules.counterAtEighty,
              validator: InputRules.optional(InputLimits.productNote),
              decoration: InputDecoration(
                labelText: tr('Izoh (ixtiyoriy)'),
                hintText: tr("O'lchami, ta'mi, ishlab chiqaruvchi"),
              ),
            ),
            // Ruscha / inglizcha nom va izoh — ixtiyoriy; bo'sh bo'lsa o'zbekchasi ko'rinadi
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: AppSpace.sm),
              title: Text(tr('Tarjima (ixtiyoriy)')),
              subtitle: Text(tr("Bo'sh qolsa, rus va ingliz tilida ham o'zbekcha nom chiqadi")),
              children: [
                TextFormField(
                    controller: nameRu,
                    maxLength: InputLimits.productName,
                    buildCounter: InputRules.counterAtEighty,
                    validator: InputRules.optional(InputLimits.productName),
                    decoration: InputDecoration(labelText: tr('Nomi — ruscha'))),
                const SizedBox(height: AppSpace.sm),
                TextFormField(
                    controller: noteRu,
                    maxLines: 2,
                    maxLength: InputLimits.productNote,
                    buildCounter: InputRules.counterAtEighty,
                    validator: InputRules.optional(InputLimits.productNote),
                    decoration: InputDecoration(labelText: tr('Izoh — ruscha'))),
                const SizedBox(height: AppSpace.sm),
                TextFormField(
                    controller: nameEn,
                    maxLength: InputLimits.productName,
                    buildCounter: InputRules.counterAtEighty,
                    validator: InputRules.optional(InputLimits.productName),
                    decoration: InputDecoration(labelText: tr('Nomi — inglizcha'))),
                const SizedBox(height: AppSpace.sm),
                TextFormField(
                    controller: noteEn,
                    maxLines: 2,
                    maxLength: InputLimits.productNote,
                    buildCounter: InputRules.counterAtEighty,
                    validator: InputRules.optional(InputLimits.productNote),
                    decoration: InputDecoration(labelText: tr('Izoh — inglizcha'))),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            Column(children: [
              TextFormField(
                controller: price,
                keyboardType: TextInputType.number,
                inputFormatters: InputRules.digitsMax(10),
                validator: InputRules.intRange(0, InputLimits.maxInt),
                onChanged: (_) => setS(() {}),
                decoration: InputDecoration(
                  labelText: tr('Narxi'),
                  suffixText: currencyLabel(currency),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              TextFormField(
                controller: costPrice,
                keyboardType: TextInputType.number,
                inputFormatters: InputRules.digitsMax(10),
                validator: InputRules.intRange(0, InputLimits.maxInt, required: false),
                onChanged: (_) => setS(() {}),
                decoration: InputDecoration(labelText: tr('Tan narxi (ixtiyoriy)')),
              ),
            ]),
            if (n(costPrice) > 0) ...[
              const SizedBox(height: AppSpace.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  trf('Foyda: {0} {1}', [fmtSum(n(price) - n(costPrice)), currencyLabel(currency)]),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                ),
              ),
            ],
            const SizedBox(height: AppSpace.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(spacing: AppSpace.sm, children: [
                for (final c in currencies)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: kTouchTarget),
                    child: ChoiceChip(
                      selected: currency == c,
                      onSelected: (_) => setS(() => currency = c),
                      label: Text(c == usd ? tr('Dollar (\$)') : tr("So'm")),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: AppSpace.md),
            ProductPhotos(product: p, onCover: (url) => setS(() => cover = url)),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: sizes,
              validator: InputRules.variantsText,
              onChanged: (_) => setS(() {}),
              decoration: InputDecoration(
                labelText: tr("O'lchamlar (ixtiyoriy)"),
                hintText: 'XL, XXL, 3XL, 4XL',
                helperText: tr("Vergul bilan. Yozilsa — shogird buyurtmada o'lchamni tanlaydi"),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: colors,
              validator: InputRules.variantsText,
              decoration: InputDecoration(
                labelText: tr('Ranglar (ixtiyoriy)'),
                hintText: tr('sariq, kulrang, yashil'),
                helperText: tr('Vergul bilan. Yozilsa — shogird buyurtmada rangni tanlaydi'),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            if (InputRules.splitVariants(sizes.text).isEmpty)
              TextFormField(
                controller: stock,
                keyboardType: TextInputType.number,
                inputFormatters: InputRules.digitsMax(10),
                validator: InputRules.intRange(0, InputLimits.maxInt, required: false),
                decoration: InputDecoration(labelText: tr('Qoldiq'), suffixText: 'dona'),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr("Qoldiq (o'lcham bo'yicha)"),
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                  const SizedBox(height: AppSpace.xs),
                  Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
                    for (final sz in InputRules.splitVariants(sizes.text))
                      SizedBox(
                        width: 90,
                        child: TextFormField(
                          controller: sizeStockCtrl(sz),
                          keyboardType: TextInputType.number,
                          inputFormatters: InputRules.digitsMax(10),
                          validator: InputRules.intRange(0, InputLimits.maxInt, required: false),
                          decoration: InputDecoration(labelText: sz),
                        ),
                      ),
                  ]),
                ]),
              ),
            const SizedBox(height: AppSpace.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: active,
              onChanged: (v) => setS(() => active = v),
              title: Text(tr('Sotuvda')),
              subtitle: Text(
                active ? tr("Shogirdlar ko'radi") : tr("Shogirdlarga ko'rinmaydi"),
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (InputRules.validateAndFocus(productForm)) Navigator.pop(ctx, true);
                },
                child: Text(tr('Saqlash')),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('Bekor')),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            if (p != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () => Navigator.pop(ctx, false),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(tr("O'chirish")),
                ),
              ),
            const SizedBox(height: AppSpace.sm),
          ]),
        ),
      ),
    ),
  );

  if (saved == true) {
    if (name.text.trim().isEmpty) return;
    final sizeList = InputRules.splitVariants(sizes.text).toList();
    await Db.saveProduct(Product(
      id: p?.id ?? '',
      category: category,
      name: name.text.trim(),
      note: note.text.trim(),
      nameRu: nameRu.text.trim(),
      nameEn: nameEn.text.trim(),
      noteRu: noteRu.text.trim(),
      noteEn: noteEn.text.trim(),
      sizes: sizeList,
      colors: InputRules.splitVariants(colors.text),
      price: n(price),
      currency: currency,
      stock: n(stock),
      sizeStock: {for (final sz in sizeList) sz: n(sizeStockCtrl(sz))},
      costPrice: n(costPrice),
      active: active,
    ));
  } else if (saved == false && p != null && context.mounted) {
    final ok = await confirm(
      context,
      title: tr("Tovarni o'chirish"),
      message: trf('"{0}" do\'kondan o\'chirilsinmi?', [p.name]),
      ok: tr("O'chirish"),
      destructive: true,
    );
    if (ok) await Db.deleteProduct(p.id);
  }
}
