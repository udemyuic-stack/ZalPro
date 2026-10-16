import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../models/shop.dart';
import '../models/subscription.dart';
import '../services/db.dart';
import '../theme.dart';
import 'ui.dart';

/// Abonement holati: "12 kun qoldi" / "Bugun tugaydi" / "Muddati o'tdi" / "Abonement yo'q"
Pill subscriptionPill(DateTime? exp) {
  if (exp == null) return Pill(text: tr("Abonement yo'q"), color: AppColors.textMuted);
  if (Subscription.isExpired(exp)) return Pill(text: tr("Muddati o'tdi"), color: AppColors.danger);
  final left = Subscription.daysLeft(exp);
  return Pill(
    text: left == 0 ? tr('Bugun tugaydi') : trf('{0} kun qoldi', [left]),
    color: Subscription.isExpiringSoon(exp) ? AppColors.warning : AppColors.success,
  );
}

/// Mijozning o'z abonementi (Profil ekrani): oxirgi to'lov va oldingi to'lovlar.
/// Faqat ko'rsatadi — abonementni trener yoki bosh admin qo'shadi.
class MySubscriptionCard extends StatelessWidget {
  final String uid;
  const MySubscriptionCard({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = t.bodySmall?.copyWith(color: AppColors.textMuted);
    return StreamBuilder<List<Subscription>>(
      stream: Db.subscriptions(uid),
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error, compact: true);
        final list = snap.data ?? const <Subscription>[];
        if (list.isEmpty) {
          return BentoTile(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Row(children: [
              IconBadge(Icons.card_membership_outlined, color: AppColors.textMuted, size: 40),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr("Abonement yo'q"), style: t.titleSmall),
                  const SizedBox(height: 2),
                  Text(tr("To'lov zalda qilinadi, abonementni trener belgilaydi."), style: muted),
                ]),
              ),
            ]),
          );
        }
        final last = list.first;
        return BentoTile(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconBadge(Icons.card_membership_outlined, color: AppColors.accent, size: 40),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(trf('Abonement · {0}', [last.kindLabel]), style: t.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                      last.price > 0 ? fmtMoney(last.price, last.currency) : tr('Summa yozilmagan'),
                      style: t.titleMedium),
                ]),
              ),
              subscriptionPill(last.expiresAt),
            ]),
            const SizedBox(height: AppSpace.sm),
            Text(trf("To'langan: {0}", [fmtDay(last.paidDate ?? last.startDate)]),
                style: t.bodyMedium),
            Text(
              last.isDaily
                  ? trf('Amal qiladi: {0} kuni', [fmtDay(last.expiresAt)])
                  : trf('Amal qiladi: {0} gacha — keyingi to\'lov shu kuni',
                      [fmtDay(last.expiresAt)]),
              style: t.bodyMedium,
            ),
            if (list.length > 1) ...[
              const SizedBox(height: AppSpace.sm),
              Text(tr("Oldingi to'lovlar"), style: muted),
              for (final s in list.skip(1).take(5))
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    [
                      fmtDay(s.paidDate ?? s.startDate),
                      s.kindLabel,
                      if (s.price > 0) fmtMoney(s.price, s.currency),
                    ].join(' · '),
                    style: muted,
                  ),
                ),
            ],
          ]),
        );
      },
    );
  }
}
