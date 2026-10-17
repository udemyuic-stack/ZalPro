import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../l10n/tr.dart';
import '../services/api/api_error.dart';
import '../services/db.dart';
import '../theme.dart';
import 'subscription_card.dart';
import 'ui.dart';

const checkinRefreshSeconds = 50;

Future<void> showCheckinQr(BuildContext context) => showSheet<void>(context, const CheckinQrBody());

class CheckinQrBody extends ConsumerStatefulWidget {
  final Future<String> Function()? fetchToken;
  final bool showSubscription;
  const CheckinQrBody({super.key, this.fetchToken, this.showSubscription = true});

  @override
  ConsumerState<CheckinQrBody> createState() => _CheckinQrBodyState();
}

class _CheckinQrBodyState extends ConsumerState<CheckinQrBody> {
  Timer? _ticker;
  String? _token;
  Object? _error;
  bool _loading = true;
  int _left = checkinRefreshSeconds;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted || _loading) return;
    if (_left > 1) {
      setState(() => _left--);
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await (widget.fetchToken ?? Db.checkinToken)();
      if (!mounted || generation != _generation) return;
      if (token.isEmpty) throw StateError('empty_token');
      setState(() {
        _token = token;
        _left = checkinRefreshSeconds;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _token = null;
        _error = e;
        _loading = false;
      });
    }
  }

  Widget _qr() {
    const box = 220.0;
    if (_error != null) {
      return SizedBox(
        height: box + AppSpace.md * 2,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.wifi_off_outlined, color: AppColors.textMuted, size: 36),
          const SizedBox(height: AppSpace.sm),
          Text(
            apiErrorText(_error!),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpace.md),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: Text(tr('Qayta urinish')),
          ),
        ]),
      );
    }
    return Container(
      width: box + AppSpace.md * 2,
      height: box + AppSpace.md * 2,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: _token == null
          ? const Center(child: CircularProgressIndicator())
          : QrImageView(
              key: ValueKey('qr:$_token'),
              data: _token!,
              size: box,
              backgroundColor: Colors.white,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final me = ref.watch(meProvider).value;
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(tr('Zalga kirish'), style: t.titleLarge),
        if (me != null) ...[
          const SizedBox(height: AppSpace.xs),
          Text(me.name, style: t.titleMedium),
        ],
        const SizedBox(height: AppSpace.sm),
        Text(
          tr("Shu kodni zal xodimiga skanerlating"),
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpace.lg),
        _qr(),
        const SizedBox(height: AppSpace.md),
        if (_error == null && _token != null)
          Text(
            trf('Kod {0} soniyadan keyin yangilanadi', [_left]),
            style: t.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        if (widget.showSubscription && me != null) ...[
          const SizedBox(height: AppSpace.lg),
          MySubscriptionCard(uid: me.id),
        ],
        const SizedBox(height: AppSpace.sm),
      ]),
    );
  }
}
