import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotta_qani_diet/models/announcement.dart';
import 'package:kotta_qani_diet/services/api/announcements_api.dart';
import 'package:kotta_qani_diet/services/api/api_client.dart';
import 'package:kotta_qani_diet/services/api/poll_stream.dart';
import 'package:kotta_qani_diet/services/api/session_store.dart';

import 'support/fake_api.dart';

void main() {
  late FakeAdapter adapter;
  late AnnouncementsApi api;
  Future<ResponseBody> Function(RequestOptions) respond = (o) async => jsonBody([], 200);

  setUp(() {
    respond = (o) async => jsonBody([], 200);
    adapter = FakeAdapter((o) => respond(o));
    final client = ApiClient(store: MemorySessionStore(), baseUrl: 'http://x', adapter: adapter);
    api = AnnouncementsApi(client, bus: ChangeBus(), activity: PollActivity());
  });

  RequestOptions last() => adapter.calls.last;

  test('announcements: GET list mapped to models', () async {
    respond = (o) async => jsonBody([
          {
            'id': 'i1',
            'title': 'T',
            'body': 'B',
            'audience': 'all',
            'author_id': 'a',
            'author_name': 'N',
            'created_at': '2026-05-07T10:00:00Z',
            'expires_at': null,
          },
        ], 200);
    final list = await api.announcements().first;
    expect(last().method, 'GET');
    expect(last().path, '/v1/announcements');
    expect(list.single.audience, AnnouncementAudience.all);
  });

  test('add: POST body carries audience and expiry', () async {
    await api.add(
      title: 'T',
      body: 'B',
      audience: AnnouncementAudience.students,
      expiresInDays: 7,
    );
    expect(last().method, 'POST');
    expect(last().path, '/v1/announcements');
    expect(last().data, {
      'title': 'T',
      'body': 'B',
      'audience': 'students',
      'expires_in_days': 7,
    });
    await api.add(title: 'T', body: 'B', audience: AnnouncementAudience.all);
    expect(last().data['audience'], 'all');
    expect(last().data['expires_in_days'], isNull);
  });

  test('remove: DELETE by id', () async {
    await api.remove('abc');
    expect(last().method, 'DELETE');
    expect(last().path, '/v1/announcements/abc');
  });
}
