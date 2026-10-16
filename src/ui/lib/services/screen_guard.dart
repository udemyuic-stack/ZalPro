import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Skrinshot va ekran yozuvini bloklash (Android `FLAG_SECURE`) — shogird kirganda yoqiladi,
/// xodimlarda va kirish ekranida o'chiq. Web va boshqa platformalarda hech narsa qilmaydi.
/// Android tomoni: `MainActivity.kt` (`qobil/ekran` kanali).
class ScreenGuard {
  static const _channel = MethodChannel('qobil/ekran');
  static bool? _on;

  static void set(bool secure) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (_on == secure) return;
    _on = secure;
    // bloklash ishlamasa ham ilova ishlayveradi
    _channel.invokeMethod<void>('secure', secure).catchError((_) {});
  }
}
