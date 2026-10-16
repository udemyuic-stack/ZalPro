// Mashq videosi havolasini tahlil qilish. Video fayl ilovada saqlanmaydi — trener havola
// qo'yadi; YouTube havolasi bo'lsa ilova ichida o'ynatiladi va muqova rasmi ko'rsatiladi.

/// YouTube video id'si ([url] YouTube havolasi bo'lmasa — null).
/// Tushunadi: `youtu.be/ID`, `youtube.com/watch?v=ID`, `/shorts/ID`, `/embed/ID`, `/live/ID`,
/// `m.youtube.com`, `music.youtube.com`, `youtube-nocookie.com`.
String? youtubeId(String url) {
  final u = Uri.tryParse(url.trim());
  if (u == null || !u.hasScheme) return null;
  final host = u.host.toLowerCase().replaceFirst(RegExp(r'^(www|m|music)\.'), '');
  final parts = u.pathSegments.where((p) => p.isNotEmpty).toList();
  String? id;
  if (host == 'youtu.be') {
    id = parts.isEmpty ? null : parts.first;
  } else if (host == 'youtube.com' || host == 'youtube-nocookie.com') {
    if (parts.isNotEmpty && parts.first == 'watch') {
      id = u.queryParameters['v'];
    } else if (parts.length >= 2 && const {'shorts', 'embed', 'live', 'v'}.contains(parts.first)) {
      id = parts[1];
    }
  }
  // YouTube id'si: 11 ta belgi (harf, raqam, - va _)
  return id != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id) ? id : null;
}

/// YouTube videosining muqova rasmi (kalit kerak emas); YouTube bo'lmasa — null
String? youtubeThumb(String url) {
  final id = youtubeId(url);
  return id == null ? null : 'https://img.youtube.com/vi/$id/hqdefault.jpg';
}
