import '../../models/scan_result.dart';
import 'api_service.dart';
import 'json_helpers.dart';

class CheckinApi extends ApiService {
  CheckinApi(super.client, {super.bus, super.activity});

  Future<String> checkinToken() async {
    final row = await client.getJson('/v1/users/me/checkin-token');
    return jsonString(row['token']);
  }

  Future<ScanResult> scanCheckin(String token) async {
    final row = await client.request<Map<String, dynamic>>(
      'POST',
      '/v1/attendance/scan',
      data: {'token': token},
    );
    final result = ScanResult.fromJson(row ?? const {});
    bus.touchAll(['attendance:${result.userId}:${result.day}', 'attendance:${result.userId}']);
    return result;
  }
}
