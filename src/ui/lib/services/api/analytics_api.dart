import '../../models/member_analytics.dart';
import '../../models/shop_analytics.dart';
import 'api_service.dart';

class AnalyticsApi extends ApiService {
  AnalyticsApi(super.client, {super.bus, super.activity});

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<ShopAnalytics> shop(DateTime from, DateTime to) async {
    final json = await client.getJson(
      '/v1/analytics/shop',
      query: {'from': _date(from), 'to': _date(to)},
    );
    return ShopAnalytics.fromJson(json);
  }

  Future<ChurnReport> churn() async =>
      ChurnReport.fromJson(await client.getJson('/v1/analytics/churn'));

  Future<Retention> retention(DateTime from, DateTime to) async => Retention.fromJson(
        await client.getJson(
          '/v1/analytics/retention',
          query: {'from': _date(from), 'to': _date(to)},
        ),
      );

  Future<TrainerStats> trainers(DateTime from, DateTime to) async => TrainerStats.fromJson(
        await client.getJson(
          '/v1/analytics/trainers',
          query: {'from': _date(from), 'to': _date(to)},
        ),
      );
}
