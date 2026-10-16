import 'package:dio/dio.dart';

import '../../l10n/tr.dart';
import 'upgrade_gate.dart';

class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.status,
    this.retryAfter,
    this.errors = const [],
    this.downloadUrl = '',
  });

  final String code;
  final String message;
  final int? status;
  final Duration? retryAfter;
  final List<Map<String, String>> errors;
  final String downloadUrl;

  static const networkCode = 'network_error';

  bool get isNetwork => code == networkCode;
  bool get isUpgradeRequired => status == 426 && code == upgradeRequiredCode;

  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    if (response == null) {
      return ApiException(code: networkCode, message: e.message ?? networkCode);
    }
    final data = response.data;
    final detail = data is Map ? data['detail'] : null;
    final retry = int.tryParse(response.headers.value('retry-after') ?? '');
    final errors = <Map<String, String>>[];
    if (detail is Map && detail['errors'] is List) {
      for (final item in detail['errors'] as List) {
        if (item is Map) {
          errors.add({for (final k in item.keys) '$k': '${item[k]}'});
        }
      }
    }
    return ApiException(
      code: detail is Map ? '${detail['code'] ?? 'http_error'}' : 'http_error',
      message: detail is Map ? '${detail['message'] ?? ''}' : '',
      status: response.statusCode,
      retryAfter: retry == null ? null : Duration(seconds: retry),
      errors: errors,
      downloadUrl: detail is Map ? '${detail['download_url'] ?? ''}' : '',
    );
  }

  @override
  String toString() => 'ApiException($code, $status)';
}

String apiErrorText(Object error) {
  if (error is! ApiException) return error.toString();
  switch (error.code) {
    case 'invalid_credentials':
      return tr("Telefon raqam yoki parol noto'g'ri");
    case 'phone_taken':
      return tr("Bu raqam bilan akkaunt allaqachon bor — Kirish'ni bosing");
    case 'wrong_password':
      return tr("Joriy parol noto'g'ri");
    case 'too_many_attempts':
      final wait = error.retryAfter;
      if (wait == null) return tr("Juda ko'p urinish. Birozdan so'ng qayta urinib ko'ring");
      final minutes = (wait.inSeconds / 60).ceil().clamp(1, 1000000);
      return trf("Juda ko'p urinish. {0} daqiqadan so'ng qayta urinib ko'ring", ['$minutes']);
    case 'validation_error':
      final fields = error.errors.map((e) => e['field'] ?? '').toList();
      if (fields.any((f) => f.endsWith('password'))) {
        return tr("Parol kamida 8 belgi bo'lsin");
      }
      if (fields.any((f) => f.endsWith('phone'))) return tr("Telefon raqam noto'g'ri");
      return error.message.isEmpty ? tr("Ma'lumotlar noto'g'ri") : error.message;
    case 'insufficient_stock':
      return tr("Omborda tovar yetarli emas");
    case 'product_missing':
      return tr("Tovar topilmadi, buyurtmani bera olmaysiz");
    case 'invalid_status_transition':
      return tr("Buyurtma holatini o'zgartirib bo'lmaydi");
    case 'product_inactive':
      return tr("Tovar sotuvda emas");
    case 'weigh_in_too_soon':
      return tr("Vazn haftada bir marta kiritiladi. Keyingi o'lchov uchun biroz kuting");
    case 'storage_unavailable':
      return tr("Rasm saqlash hozir ishlamayapti. Keyinroq urinib ko'ring");
    case 'video_too_large':
      return tr('Video 60 MB dan katta');
    case 'video_not_uploaded':
      return tr('Video serverga yetib bormagan. Qayta yuklang');
    case upgradeRequiredCode:
      return tr("Ilova eskirgan. Yangi versiyani yuklab oling");
    case ApiException.networkCode:
      return tr('Internet aloqasini tekshiring');
    default:
      return error.message.isEmpty ? error.code : error.message;
  }
}
