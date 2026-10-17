import '../../models/announcement.dart';
import 'api_service.dart';
import 'json_helpers.dart';

class AnnouncementsApi extends ApiService {
  AnnouncementsApi(super.client, {super.bus, super.activity});

  static const _every = Duration(seconds: 60);
  static const _tag = 'announcements';

  Stream<List<Announcement>> announcements() => poll(() async {
        final rows = await client.getList('/v1/announcements');
        return [for (final row in jsonMaps(rows)) Announcement.fromJson(row)];
      }, _every, {_tag});

  Future<void> add({
    required String title,
    required String body,
    required AnnouncementAudience audience,
    int? expiresInDays,
  }) =>
      write(
        'POST',
        '/v1/announcements',
        {
          'title': title,
          'body': body,
          'audience': audience == AnnouncementAudience.all ? 'all' : 'students',
          'expires_in_days': expiresInDays,
        },
        {_tag},
      );

  Future<void> remove(String id) =>
      write('DELETE', '/v1/announcements/${Uri.encodeComponent(id)}', null, {_tag});
}
