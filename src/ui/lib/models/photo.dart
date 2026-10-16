import 'dart:typed_data';
import '../services/api/json_helpers.dart';

/// `users/{uid}/photos/{id}` — shogirdning "oldin / keyin" rasmi.
/// Rasm siqilgan holda hujjatning o'zida saqlanadi (Cloud Storage Blaze tarifini talab qiladi).
class ProgressPhoto {
  /// Firestore hujjati 1 MB dan oshmasligi kerak — rasm uchun chegara (qoidalarda ham shu)
  static const maxBytes = 350 * 1024;

  final String id;
  final Uint8List bytes;
  final DateTime? takenAt;

  /// Rasm olingan paytdagi vazn (0 — noma'lum)
  final double weight;

  final String? url;
  final DateTime? urlExpiresAt;

  const ProgressPhoto({
    this.id = '',
    required this.bytes,
    this.takenAt,
    this.weight = 0,
    this.url,
    this.urlExpiresAt,
  });

  factory ProgressPhoto.fromJson(Map<String, dynamic> j, {DateTime? urlExpiresAt}) {
    return ProgressPhoto(
      id: jsonString(j['id']),
      bytes: Uint8List(0),
      takenAt: jsonDate(j['taken_at']),
      weight: jsonDouble(j['weight']),
      url: jsonStringOrNull(j['download_url']),
      urlExpiresAt: urlExpiresAt,
    );
  }

  /// Sana: "05.10.2026"
  String get dateLabel {
    final d = takenAt;
    if (d == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }
}
