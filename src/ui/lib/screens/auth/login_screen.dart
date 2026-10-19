import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/input_rules.dart';
import '../../l10n/tr.dart';
import '../../services/api/api_error.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/lang_picker.dart';
import '../../widgets/ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  bool _isRegister = false;
  bool _busy = false;
  bool _hidePass = true;
  bool _slow = false;
  Timer? _slowTimer;

  @override
  void dispose() {
    _slowTimer?.cancel();
    _name.dispose();
    _phone.dispose();
    _pass.dispose();
    super.dispose();
  }

  String? _passwordError(String? v) => InputRules.password(v, strict: _isRegister);

  Future<void> _submit() async {
    if (!InputRules.validateAndFocus(_form)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _slow = false;
    });
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _busy) setState(() => _slow = true);
    });
    try {
      if (_isRegister) {
        await AuthService.register(_name.text, _phone.text, _pass.text);
      } else {
        await AuthService.signIn(_phone.text, _pass.text);
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, apiErrorText(e));
    } catch (e) {
      if (mounted) showSnack(context, apiErrorText(e));
    } finally {
      _slowTimer?.cancel();
      if (mounted) {
        setState(() {
          _busy = false;
          _slow = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = Theme.of(context).colorScheme;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          GradientHeader(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.xl, 44, AppSpace.xl, 40),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  AuraLogo(size: 30),
                  Spacer(),
                  LangPicker(compact: true),
                ]),
                const SizedBox(height: AppSpace.xl),
                Heading(tr('Biz bilan'), accent: tr("kuchliroq bo'ling"), style: t.headlineLarge),
                const SizedBox(height: AppSpace.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text(
                    tr('Trener tuzgan shaxsiy reja, kunlik nazorat va progress — bitta ilovada.'),
                    style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
                  ),
                ),
              ]),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                child: Form(
                  key: _form,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: AutofillGroup(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _Toggle(
                        isRegister: _isRegister,
                        onChanged: (v) => setState(() => _isRegister = v),
                      ),
                      const SizedBox(height: AppSpace.xl),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: _isRegister
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: TextFormField(
                                  controller: _name,
                                  textCapitalization: TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.name],
                                  maxLength: InputLimits.name,
                                  buildCounter: InputRules.counterAtEighty,
                                  validator: InputRules.required(
                                    InputLimits.name,
                                    emptyMessage: tr('Ismingizni kiriting'),
                                  ),
                                  decoration: InputDecoration(
                                    labelText: tr('Ism'),
                                    prefixIcon: const Icon(Icons.person_outline),
                                  ),
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.telephoneNumberNational],
                        inputFormatters: InputRules.digitsMax(InputLimits.phoneDigits),
                        validator: (v) => (v ?? '').length == 9
                            ? null
                            : tr("Raqamni to'liq kiriting: 90 123 45 67"),
                        decoration: InputDecoration(
                          labelText: tr('Telefon raqam'),
                          hintText: '90 123 45 67',
                          prefixText: '+998 ',
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _pass,
                        obscureText: _hidePass,
                        maxLength: _isRegister ? InputLimits.passwordMax : null,
                        buildCounter: InputRules.counterAtEighty,
                        textInputAction: TextInputAction.done,
                        autofillHints: [
                          _isRegister ? AutofillHints.newPassword : AutofillHints.password
                        ],
                        onFieldSubmitted: (_) => _submit(),
                        validator: _passwordError,
                        decoration: InputDecoration(
                          labelText: tr('Parol'),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _hidePass ? tr("Parolni ko'rsatish") : tr('Parolni yashirish'),
                            onPressed: () => setState(() => _hidePass = !_hidePass),
                            icon: Icon(_hidePass
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.onAccentFill,
                                ))
                            : Text(_isRegister ? tr('Akkaunt yaratish') : tr('Kirish')),
                      ),
                      if (_busy && _slow)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpace.sm),
                          child: Text(
                            tr("Server uyg'onmoqda, biroz kuting"),
                            textAlign: TextAlign.center,
                            style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                          ),
                        ),
                      if (!_isRegister)
                        TextButton(
                          onPressed: () => showSheet<void>(
                            context,
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Heading(tr('Parolni unutdingizmi?'), style: t.titleLarge),
                                const SizedBox(height: AppSpace.sm),
                                Text(
                                  tr("SMS yuborilmaydi, shuning uchun parolni zal tiklaydi:\n\n"
                                      "1. Zal egasiga (bosh adminga) telefon raqamingizni ayting.\n"
                                      "2. U sizga vaqtinchalik yangi parol beradi.\n"
                                      "3. Shu parol bilan kiring va Profil → «Parolni o'zgartirish» "
                                      "orqali o'zingizning parolingizni qo'ying."),
                                  style: t.bodyMedium?.copyWith(height: 1.5),
                                ),
                                const SizedBox(height: AppSpace.xl),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(tr('Tushunarli')),
                                ),
                              ],
                            ),
                          ),
                          child: Text(tr('Parolni unutdim')),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        _isRegister
                            ? tr(
                                "Ro'yxatdan o'tgach, trener sizga shaxsiy ovqatlanish rejasini biriktiradi.")
                            : tr('Trener va mijozlar bitta ilovadan kiradi.'),
                        textAlign: TextAlign.center,
                        style: t.bodySmall?.copyWith(color: s.onSurfaceVariant),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final bool isRegister;
  final ValueChanged<bool> onChanged;
  const _Toggle({required this.isRegister, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpace.xs),
      decoration: BoxDecoration(
        color: s.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: s.outlineVariant),
      ),
      child: Row(children: [
        _seg(context, tr('Kirish'), !isRegister, () => onChanged(false)),
        _seg(context, tr("Ro'yxatdan o'tish"), isRegister, () => onChanged(true)),
      ]),
    );
  }

  Widget _seg(BuildContext context, String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          height: kTouchTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.accent.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md - 4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: active ? AppColors.accent : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
