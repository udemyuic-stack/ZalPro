import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/tr.dart';
import '../models/payment.dart';
import '../models/shop.dart';
import '../models/subscription.dart';
import '../services/api/api_error.dart';
import '../services/db.dart';
import '../theme.dart';
import 'ui.dart';

/// Talaba abonementni ilova ichidan sotib oladi: muddat -> Payme/Click -> to'lov sahifasi
/// (tashqi brauzer/ilova) -> holat so'raladi -> to'langanda abonement o'zi faollashadi.
/// `true` — abonement faollashdi.
Future<bool> showBuySubscription(BuildContext context, String uid) async {
  final done = await showSheet<bool>(context, BuySubscriptionBody(uid: uid));
  return done ?? false;
}

typedef OpenPayUrl = Future<bool> Function(String url);

Future<bool> _launchExternal(String url) async {
  try {
    return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

enum _Stage { choose, waiting, paid, canceled, stale }

class BuySubscriptionBody extends StatefulWidget {
  final String uid;
  final Future<PaymentOptions> Function()? loadOptions;
  final Future<PaymentOrder> Function(int months, String provider)? createOrder;
  final Stream<PaymentOrder> Function(String uid, String id)? watchOrder;
  final Future<PaymentOrder> Function(String id)? fetchOrder;
  final OpenPayUrl? openUrl;

  const BuySubscriptionBody({
    super.key,
    required this.uid,
    this.loadOptions,
    this.createOrder,
    this.watchOrder,
    this.fetchOrder,
    this.openUrl,
  });

  @override
  State<BuySubscriptionBody> createState() => _BuySubscriptionBodyState();
}

class _BuySubscriptionBodyState extends State<BuySubscriptionBody> with WidgetsBindingObserver {
  PaymentOptions? _options;
  Object? _error;
  bool _busy = false;
  int? _months;
  PaymentOrder? _order;
  _Stage _stage = _Stage.choose;
  StreamSubscription<PaymentOrder>? _watch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watch?.cancel();
    super.dispose();
  }

  /// To'lov ilovasidan qaytilganda kutmasdan holatni so'raymiz
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _stage == _Stage.waiting) _check();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _options = null;
    });
    try {
      final options = await (widget.loadOptions ?? Db.paymentOptions)();
      if (!mounted) return;
      setState(() {
        _options = options;
        _months ??= options.plans.isEmpty ? null : options.plans.first.months;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _pay(String provider) async {
    final months = _months;
    if (months == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final order = await (widget.createOrder ?? Db.createPaymentOrder)(months, provider);
      if (!mounted) return;
      setState(() {
        _order = order;
        _stage = _Stage.waiting;
        _busy = false;
      });
      _startWatching(order.id);
      await _open(order);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _busy = false;
        });
      }
    }
  }

  void _startWatching(String id) {
    _watch?.cancel();
    final stream = (widget.watchOrder ?? Db.watchPaymentOrder)(widget.uid, id);
    _watch = stream.listen(_onOrder, onError: (Object e) {
      if (mounted) setState(() => _error = e);
    }, onDone: () {
      if (mounted && _stage == _Stage.waiting) setState(() => _stage = _Stage.stale);
    });
  }

  void _onOrder(PaymentOrder order) {
    if (!mounted) return;
    setState(() {
      _order = order;
      if (order.isPaid) _stage = _Stage.paid;
      if (order.isCanceled) _stage = _Stage.canceled;
    });
  }

  Future<void> _check() async {
    final order = _order;
    if (order == null) return;
    try {
      final fresh = await (widget.fetchOrder ?? Db.paymentOrder)(order.id);
      if (fresh.isPaid) Db.refreshAfterPayment(widget.uid);
      _onOrder(fresh);
      if (mounted && !fresh.isFinal && _stage == _Stage.stale) {
        setState(() => _stage = _Stage.waiting);
        _startWatching(order.id);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _open(PaymentOrder order) async {
    final url = order.payUrl;
    final ok = url != null && url.isNotEmpty && await (widget.openUrl ?? _launchExternal)(url);
    if (!ok && mounted) showSnack(context, tr("To'lov sahifasini ochib bo'lmadi"));
  }

  void _retry() {
    _watch?.cancel();
    setState(() {
      _order = null;
      _error = null;
      _stage = _Stage.choose;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: switch (_stage) {
          _Stage.choose => _choose(t),
          _Stage.waiting => _waiting(t),
          _Stage.paid => _paid(t),
          _Stage.canceled => _canceled(t),
          _Stage.stale => _stale(t),
        },
      ),
    );
  }

  Widget _errorLine(TextTheme t) => Padding(
        padding: const EdgeInsets.only(top: AppSpace.sm),
        child: Text(
          apiErrorText(_error!),
          textAlign: TextAlign.center,
          style: t.bodyMedium?.copyWith(color: AppColors.danger),
        ),
      );

  List<Widget> _choose(TextTheme t) {
    final options = _options;
    final muted = t.bodyMedium?.copyWith(color: AppColors.textMuted);
    return [
      Text(tr('Obunani sotib olish'), style: t.titleLarge),
      const SizedBox(height: AppSpace.xs),
      Text(tr('Obuna muddatini tanlang'), style: muted),
      const SizedBox(height: AppSpace.md),
      if (options == null && _error == null)
        const Padding(
          padding: EdgeInsets.all(AppSpace.lg),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (options == null) ...[
        _errorLine(t),
        const SizedBox(height: AppSpace.md),
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: Text(tr('Qayta urinish')),
        ),
      ] else if (!options.available)
        Text(tr("Onlayn to'lov hozircha ulanmagan. To'lovni zalda qiling."), style: muted)
      else ...[
        for (final plan in options.plans) _planTile(t, plan),
        const SizedBox(height: AppSpace.md),
        Text(tr("To'lov usuli"), style: t.titleSmall),
        const SizedBox(height: AppSpace.sm),
        for (final provider in options.providers) ...[
          FilledButton(
            key: ValueKey('pay:$provider'),
            onPressed: _busy || _months == null ? null : () => _pay(provider),
            child: _busy
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_providerLabel(provider)),
          ),
          const SizedBox(height: AppSpace.sm),
        ],
        if (_error != null) _errorLine(t),
      ],
    ];
  }

  String _providerLabel(String provider) => switch (provider) {
        payProviderPayme => tr("Payme orqali to'lash"),
        payProviderClick => tr("Click orqali to'lash"),
        _ => provider,
      };

  Widget _planTile(TextTheme t, PaymentPlan plan) {
    final selected = plan.months == _months;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: InkWell(
        key: ValueKey('plan:${plan.months}'),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: _busy ? null : () => setState(() => _months = plan.months),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.textMuted.withValues(alpha: 0.3),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Text(Subscription.kindLabelOf(months: plan.months), style: t.titleSmall),
            ),
            Text(fmtMoney(plan.price, plan.currency), style: t.titleMedium),
          ]),
        ),
      ),
    );
  }

  List<Widget> _waiting(TextTheme t) {
    final order = _order;
    return [
      const Center(child: CircularProgressIndicator()),
      const SizedBox(height: AppSpace.lg),
      Text(tr("To'lov kutilmoqda…"), textAlign: TextAlign.center, style: t.titleLarge),
      const SizedBox(height: AppSpace.sm),
      Text(
        tr("To'lovni Payme yoki Click ilovasida yakunlang. Tasdiqlangach obuna o'zi faollashadi."),
        textAlign: TextAlign.center,
        style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
      ),
      if (_error != null) _errorLine(t),
      const SizedBox(height: AppSpace.xl),
      if (order != null)
        FilledButton(
          key: const ValueKey('reopen'),
          onPressed: () => _open(order),
          child: Text(tr("To'lov sahifasini qayta ochish")),
        ),
      const SizedBox(height: AppSpace.sm),
      OutlinedButton(
        key: const ValueKey('check'),
        onPressed: _check,
        child: Text(tr('Holatni tekshirish')),
      ),
    ];
  }

  List<Widget> _paid(TextTheme t) {
    final expires = _order?.expiresAt;
    return [
      Icon(Icons.check_circle_outline, color: AppColors.success, size: 56),
      const SizedBox(height: AppSpace.md),
      Text(tr('Obuna faollashdi'), textAlign: TextAlign.center, style: t.titleLarge),
      if (expires != null) ...[
        const SizedBox(height: AppSpace.xs),
        Text(
          trf('Amal qiladi: {0} gacha', [fmtDay(expires)]),
          textAlign: TextAlign.center,
          style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
        ),
      ],
      const SizedBox(height: AppSpace.xl),
      FilledButton(
        key: const ValueKey('done'),
        onPressed: () => Navigator.pop(context, true),
        child: Text(tr('Yopish')),
      ),
    ];
  }

  List<Widget> _canceled(TextTheme t) => [
        Icon(Icons.error_outline, color: AppColors.danger, size: 56),
        const SizedBox(height: AppSpace.md),
        Text(tr("To'lov bekor qilindi"), textAlign: TextAlign.center, style: t.titleLarge),
        const SizedBox(height: AppSpace.xl),
        FilledButton(
          key: const ValueKey('retry'),
          onPressed: _retry,
          child: Text(tr('Qayta urinish')),
        ),
        const SizedBox(height: AppSpace.sm),
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(tr('Yopish')),
        ),
      ];

  List<Widget> _stale(TextTheme t) => [
        Icon(Icons.hourglass_empty, color: AppColors.warning, size: 56),
        const SizedBox(height: AppSpace.md),
        Text(
          tr("To'lov tasdig'i hali kelmadi. Pul yechilgan bo'lsa, obuna bir necha daqiqada faollashadi."),
          textAlign: TextAlign.center,
          style: t.bodyMedium,
        ),
        const SizedBox(height: AppSpace.xl),
        FilledButton(
          key: const ValueKey('check'),
          onPressed: _check,
          child: Text(tr('Holatni tekshirish')),
        ),
        const SizedBox(height: AppSpace.sm),
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(tr('Yopish')),
        ),
      ];
}
