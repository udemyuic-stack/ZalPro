import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../services/api/api_error.dart';
import '../services/db.dart';
import '../theme.dart';
import 'ui.dart';

/// Parolni o'zgartirish — pastdan chiquvchi varaqda (shogird, trener, bosh admin uchun bir xil)
Future<void> showChangePassword(BuildContext context) =>
    showSheet<void>(context, const _ChangePasswordSheet());

/// Yangi parol tekshiruvi: null — hammasi joyida, aks holda xato matni
String? validateNewPassword(String current, String next, String repeat) {
  if (current.isEmpty) return tr('Hozirgi parolni kiriting');
  if (next.length < 8) return tr("Yangi parol kamida 8 belgi bo'lsin");
  if (next == current) return tr('Yangi parol eskisidan farq qilsin');
  if (next != repeat) return tr('Yangi parollar bir xil emas');
  return null;
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false, _show = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final err = validateNewPassword(_current.text, _next.text, _repeat.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.changePassword(_current.text, _next.text);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(tr("Parol o'zgartirildi"))));
    } on ApiException catch (e) {
      setState(() => _error = apiErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController c, String label, {bool autofocus = false}) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.md),
        child: TextField(
          controller: c,
          autofocus: autofocus,
          obscureText: !_show,
          enabled: !_busy,
          decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.lock_outline)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr("Parolni o'zgartirish"), style: t.titleLarge),
        const SizedBox(height: AppSpace.lg),
        _field(_current, tr('Hozirgi parol'), autofocus: true),
        _field(_next, tr('Yangi parol (kamida 8 belgi)')),
        _field(_repeat, tr('Yangi parolni takrorlang')),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _show = !_show),
            icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
            label: Text(_show ? tr('Yashirish') : tr("Ko'rsatish")),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: Text(_error!, style: t.bodyMedium?.copyWith(color: AppColors.danger)),
          ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox.square(
                  dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Text(tr('Saqlash')),
        ),
      ],
    );
  }
}
