import '../services/api/json_helpers.dart';

enum AnnouncementAudience { all, students }

class Announcement {
  final String id;
  final String title;
  final String body;
  final AnnouncementAudience audience;
  final String authorId;
  final String authorName;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.authorId,
    required this.authorName,
    this.createdAt,
    this.expiresAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: jsonString(j['id']),
        title: jsonString(j['title']),
        body: jsonString(j['body']),
        audience: j['audience'] == 'all' ? AnnouncementAudience.all : AnnouncementAudience.students,
        authorId: jsonString(j['author_id']),
        authorName: jsonString(j['author_name']),
        createdAt: jsonDate(j['created_at']),
        expiresAt: jsonDate(j['expires_at']),
      );

  bool isActive(DateTime now) => expiresAt == null || expiresAt!.isAfter(now);
}

const announcementExpiryChoices = <int?>[1, 7, 30, null];
const announcementMaxActive = 20;
const announcementTitleMax = 80;
const announcementBodyMax = 500;

List<Announcement> activeAnnouncements(List<Announcement> all, DateTime now) => [
      for (final a in all)
        if (a.isActive(now)) a
    ];

bool announcementFull(List<Announcement> all, String authorId, DateTime now) =>
    all.where((a) => a.authorId == authorId && a.isActive(now)).length >= announcementMaxActive;
