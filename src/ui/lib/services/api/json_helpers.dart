DateTime? jsonDate(Object? v) {
  if (v is! String || v.isEmpty) return null;
  return DateTime.tryParse(v)?.toLocal();
}

String jsonString(Object? v, [String fallback = '']) => v is String ? v : fallback;

String? jsonStringOrNull(Object? v) => v is String ? v : null;

int jsonInt(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

double jsonDouble(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;

bool jsonBool(Object? v, [bool fallback = false]) => v is bool ? v : fallback;

List<Map<String, dynamic>> jsonMaps(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map) Map<String, dynamic>.from(e),
      ]
    : const [];

List<String> jsonStrings(Object? v) => v is List ? [for (final e in v) e.toString()] : const [];

List<int> jsonInts(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is num) e.toInt(),
      ]
    : const [];
