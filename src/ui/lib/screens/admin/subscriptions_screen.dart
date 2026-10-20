import 'package:flutter/material.dart';
import '../../core/input_rules.dart';
import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../models/subscription.dart';
import '../../services/api/api_error.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/lazy_stack.dart';
import '../../widgets/ui.dart';
import '../payments_screen.dart';

/// Trener (va bosh admin) uchun abonement: mijozlar holati (qolgan kun, eslatma yuborish)
/// va abonement tugashi haqida yuborilgan eslatmalarning haftalik hisoboti.
class SubscriptionsScreen extends StatefulWidget {
  final AppUser admin;
  const SubscriptionsScreen({super.key, required this.admin});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  late final _clients = widget.admin.isOwner ? Db.clients() : Db.clientsOf(widget.admin.id);
  late final _reminders =
      widget.admin.isOwner ? Db.allReminders() : Db.remindersOf(widget.admin.id);
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.sm),
        child: AppSegmented<int>(
          segments: [
            AppSegment(value: 0, label: tr('Mijozlar')),
            AppSegment(value: 1, label: tr("To'lovlar")),
            AppSegment(value: 2, label: tr('Eslatmalar')),
          ],
          selected: _tab,
          onChanged: (v) => setState(() => _tab = v),
        ),
      ),
      Expanded(
        child: LazyIndexedStack(index: _tab, children: [
          _ClientsTab(stream: _clients, adminId: widget.admin.id),
          // zalning hamma mijozlari (boshqa trenerniki ham) — faqat ko'rish
          PaymentsScreen(me: widget.admin),
          _ReminderReportTab(stream: _reminders),
        ]),
      ),
    ]);
  }
}

class _ClientsTab extends StatelessWidget {
  final Stream<List<AppUser>> stream;
  final String adminId;
  const _ClientsTab({required this.stream, required this.adminId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = Subscription.sortByExpiry(snap.data!, (u) => u.subscriptionExpiresAt);
        if (list.isEmpty) {
          return EmptyState(icon: Icons.event_repeat_outlined, title: tr("Hali mijoz yo'q"));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.xl),
          children: [
            for (final u in list)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: _SubscriptionTile(client: u, adminId: adminId),
              ),
          ],
        );
      },
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  final AppUser client;
  final String adminId;
  const _SubscriptionTile({required this.client, required this.adminId});

  Future<void> _sendReminder(BuildContext context, int daysLeft) async {
    try {
      await Db.sendSubscriptionReminder(client, daysLeft, adminId);
      if (context.mounted) showSnack(context, tr('Eslatma yuborildi'));
    } catch (e) {
      if (context.mounted) showSnack(context, trf("Bo'lmadi: {0}", [apiErrorText(e)]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final u = client;
    final name = u.name.isEmpty ? fmtPhone(u.phone) : u.name;
    final exp = u.subscriptionExpiresAt;
    final daysLeft = Subscription.daysLeft(exp);
    final expiringSoon = Subscription.isExpiringSoon(exp);
    final expired = Subscription.isExpired(exp);
    final status = switch (Subscription.urgencyOf(exp)) {
      SubscriptionUrgency.none => Pill(text: tr("Abonement yo'q"), color: AppColors.textMuted),
      SubscriptionUrgency.expired => Pill(text: tr("Muddati o'tdi"), color: AppColors.danger),
      SubscriptionUrgency.soon =>
        Pill(text: trf('{0} kun qoldi', [daysLeft]), color: AppColors.warning),
      SubscriptionUrgency.ok =>
        Pill(text: trf('{0} kun qoldi', [daysLeft]), color: AppColors.success),
    };

    return BentoTile(
      onTap: () => addSubscriptionSheet(context, u),
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          UserAvatar(name: name),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(name, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: AppSpace.sm),
          status,
        ]),
        if (expiringSoon || expired) ...[
          const SizedBox(height: AppSpace.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, kTouchTarget)),
              onPressed: () => _sendReminder(context, daysLeft),
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: Text(tr('Eslatma yubor')),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Mijozga yangi abonement qo'shish — tugash sanasi avtomatik hisoblanadi (boshlanish + oy soni).
Future<void> addSubscriptionSheet(BuildContext context, AppUser client) async {
  // 0 — kunlik tashrif, aks holda oy soni
  var months = subscriptionMonths.first;
  int stdPrice() =>
      months == 0 ? Subscription.priceOf(days: 1) : Subscription.priceOf(months: months);
  final price = TextEditingController(text: '${stdPrice()}');
  final form = GlobalKey<FormState>();

  final saved = await showSheet<bool>(
    context,
    StatefulBuilder(
      builder: (ctx, setS) => Form(
        key: form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(trf('Abonement — {0}', [client.name.isEmpty ? fmtPhone(client.phone) : client.name]),
              style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: AppSpace.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
              for (final m in [0, ...subscriptionMonths])
                ChoiceChip(
                  selected: months == m,
                  // tur almashganda narx belgilangan qiymatga qaytadi
                  onSelected: (_) => setS(() {
                    months = m;
                    price.text = '${stdPrice()}';
                  }),
                  label: Text(m == 0 ? tr('Kunlik') : trf('{0} oy', [m])),
                ),
            ]),
          ),
          const SizedBox(height: AppSpace.md),
          TextFormField(
            controller: price,
            keyboardType: TextInputType.number,
            inputFormatters: InputRules.digitsMax(10),
            validator: InputRules.intRange(0, InputLimits.maxInt),
            decoration: InputDecoration(labelText: tr('Narxi'), suffixText: tr("so'm")),
          ),
          const SizedBox(height: AppSpace.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (InputRules.validateAndFocus(form)) Navigator.pop(ctx, true);
              },
              child: Text(tr('Saqlash')),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Bekor')),
          ),
          const SizedBox(height: AppSpace.sm),
        ]),
      ),
    ),
  );

  if (saved == true) {
    try {
      await Db.addSubscription(
        client,
        Subscription(
          startDate: DateTime.now(),
          months: months,
          days: months == 0 ? 1 : 0,
          price: InputRules.parseInt(price.text) ?? 0,
          paidDate: DateTime.now(),
        ),
      );
      if (context.mounted) showSnack(context, tr("Abonement qo'shildi"));
    } catch (e) {
      if (context.mounted) showSnack(context, trf("Bo'lmadi: {0}", [apiErrorText(e)]));
    }
  }
}

class _ReminderReportTab extends StatelessWidget {
  final Stream<List<Reminder>> stream;
  const _ReminderReportTab({required this.stream});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return StreamBuilder<List<Reminder>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final byDay = ReminderReport.byDay(snap.data!, days: 7);
        final autoByDay = ReminderReport.byDay(snap.data!, days: 7, autoOnly: true);
        final total = byDay.values.fold<int>(0, (s, v) => s + v);
        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.xl),
          children: [
            SectionHeader(tr('Oxirgi 7 kun'),
                trailing: Pill(text: trf('{0} ta', [total]), color: AppColors.accent)),
            for (final e in byDay.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: BentoTile(
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: Row(children: [
                    Expanded(
                      child: Text(uzDate(DateTime.parse(e.key)), style: t.bodyMedium),
                    ),
                    if ((autoByDay[e.key] ?? 0) > 0) ...[
                      Pill(
                        text: trf('Avto: {0}', [autoByDay[e.key]]),
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: AppSpace.sm),
                    ],
                    Pill(
                      text: '${e.value}',
                      color: e.value > 0 ? AppColors.accent : AppColors.textMuted,
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
