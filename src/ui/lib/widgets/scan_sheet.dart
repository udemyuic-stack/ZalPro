import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../l10n/tr.dart';
import '../models/scan_result.dart';
import '../services/api/api_error.dart';
import '../services/db.dart';
import '../theme.dart';
import 'ui.dart';

const scanResumeDelay = Duration(seconds: 2);
const scanSameTokenWindow = Duration(seconds: 60);

Future<void> showCheckinScanner(BuildContext context) => showSheet<void>(
      context,
      SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: const CheckinScanner(),
      ),
    );

class _Shown {
  final String message;
  final String? note;
  final Color color;
  final IconData icon;
  const _Shown(this.message, this.note, this.color, this.icon);
}

class CheckinScanner extends StatefulWidget {
  final Future<ScanResult> Function(String token)? scan;
  final bool camera;
  const CheckinScanner({super.key, this.scan, this.camera = true});

  @override
  State<CheckinScanner> createState() => _CheckinScannerState();
}

class _CheckinScannerState extends State<CheckinScanner> {
  final _code = TextEditingController();
  MobileScannerController? _controller;
  _Shown? _shown;
  bool _busy = false;
  String? _lastToken;
  DateTime? _lastAt;

  @override
  void initState() {
    super.initState();
    if (widget.camera) _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  }

  @override
  void dispose() {
    _code.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    for (final b in capture.barcodes) {
      final value = (b.rawValue ?? '').trim();
      if (value.isEmpty) continue;
      final repeated = value == _lastToken &&
          _lastAt != null &&
          DateTime.now().difference(_lastAt!) < scanSameTokenWindow;
      if (repeated) return;
      _submit(value);
      return;
    }
  }

  Future<void> _submit(String raw) async {
    final token = raw.trim();
    if (token.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _shown = null;
    });
    _Shown shown;
    try {
      final result = await (widget.scan ?? Db.scanCheckin)(token);
      final outcome = scanOutcome(result);
      _lastToken = token;
      _lastAt = DateTime.now();
      shown = _Shown(outcome.message, outcome.note, outcome.color(), outcome.icon);
    } catch (e) {
      shown = _Shown(apiErrorText(e), null, AppColors.danger, Icons.error_outline);
    }
    if (!mounted) return;
    setState(() => _shown = shown);
    await Future<void>.delayed(scanResumeDelay);
    if (!mounted) return;
    setState(() {
      _shown = null;
      _busy = false;
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) setState(() => _code.text = text);
  }

  void _submitManual() {
    final text = _code.text;
    _code.clear();
    _submit(text);
  }

  Widget _cameraError(Object error) {
    final denied = error is MobileScannerException &&
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return _cameraMessage(
      denied
          ? tr("Kamera ruxsati berilmagan. Sozlamalardan ruxsat bering yoki kodni qo'lda kiriting")
          : tr("Kamera ishlamayapti. Kodni qo'lda kiriting"),
    );
  }

  Widget _cameraMessage(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.no_photography_outlined, size: 40, color: AppColors.textMuted),
            const SizedBox(height: AppSpace.md),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
          ]),
        ),
      );

  Widget _preview() {
    final controller = _controller;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        color: AppColors.card,
        child: controller == null
            ? _cameraMessage(tr("Kamera mavjud emas. Kodni qo'lda kiriting"))
            : MobileScanner(
                controller: controller,
                onDetect: _onDetect,
                errorBuilder: (context, error) => _cameraError(error),
              ),
      ),
    );
  }

  Widget _resultCard() {
    final s = _shown;
    if (s == null) {
      return SizedBox(
        height: 64,
        child: Center(
          child: _busy
              ? const SizedBox(
                  width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Text(tr('QR kodni kameraga ko\'rsating'),
                  style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: s.color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(s.icon, color: s.color, size: 32),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.message, style: t.titleMedium?.copyWith(color: s.color)),
            if (s.note != null)
              Text(s.note!, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(tr('Skaner'), style: t.titleLarge)),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Yopish'))),
      ]),
      const SizedBox(height: AppSpace.sm),
      Expanded(child: _preview()),
      const SizedBox(height: AppSpace.md),
      _resultCard(),
      const SizedBox(height: AppSpace.md),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _code,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitManual(),
            decoration: InputDecoration(
              labelText: tr("Kodni qo'lda kiriting"),
              suffixIcon: IconButton(
                tooltip: tr('Joylashtirish'),
                onPressed: _paste,
                icon: const Icon(Icons.content_paste_outlined),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        SizedBox(
          height: kTouchTarget,
          width: kTouchTarget,
          child: IconButton.filled(
            tooltip: tr('Tekshirish'),
            onPressed: _busy ? null : _submitManual,
            icon: const Icon(Icons.check),
          ),
        ),
      ]),
    ]);
  }
}
