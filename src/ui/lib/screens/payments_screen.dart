import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../models/models.dart';
import '../models/shop.dart';
import '../models/subscription.dart';
import '../services/db.dart';
import '../theme.dart';
import '../widgets/subscription_card.dart';
import '../widgets/ui.dart';

/// Zal mijozlarining to'lovlari — hamma trener va barmen ko'radi (faqat o'qish):
/// kim, kunlikmi oylikmi, qancha, qachon to'lagan, qachongacha amal qiladi.
/// Bosh admin — hamma zallar. Abonement bu yerdan qo'shilmaydi.
class PaymentsScreen extends StatefulWidget {
  final AppUser me;
  const PaymentsScreen({super.key, required this.me});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late final _stream = Db.memberships(widget.me);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final me = widget.me;
    if (!me.isOwner && (me.gymId ?? '').isEmpty) {
      return EmptyState(
        icon: Icons.payments_outlined,
        title: tr('Zal biriktirilmagan'),
        subtitle:
            tr("To'lovlar zal bo'yicha ko'rinadi. Bosh admin sizni zalga biriktirishi kerak."),
      );
    }
    return StreamBuilder<List<Membership>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        // tugashi yaqini (va o'tgani) tepada
        final far = DateTime(9999);
        final list = [...snap.data!]
          ..sort((a, b) => (a.expiresAt ?? far).compareTo(b.expiresAt ?? far));
        if (list.isEmpty) {
          return EmptyState(icon: Icons.payments_outlined, title: tr("Hali to'lov yo'q"));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.xl),
          children: [
            for (final m in list)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: BentoTile(
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      UserAvatar(name: m.name),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Text(m.name.isEmpty ? tr('Ismsiz') : m.name,
                            style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      subscriptionPill(m.expiresAt),
                    ]),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      [m.kindLabel, if (m.price > 0) fmtMoney(m.price, m.currency)].join(' · '),
                      style: t.bodyMedium,
                    ),
                    Text(
                      m.days > 0
                          ? trf("To'langan: {0} · amal qiladi: {1}",
                              [fmtDay(m.paidDate), fmtDay(m.expiresAt)])
                          : trf("To'langan: {0} · keyingi to'lov: {1}",
                              [fmtDay(m.paidDate), fmtDay(m.expiresAt)]),
                      style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                  ]),
                ),
              ),
          ],
        );
      },
    );
  }
}
