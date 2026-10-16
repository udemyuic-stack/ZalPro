import '../../models/models.dart';
import '../../models/stats.dart';
import 'api_service.dart';
import 'json_helpers.dart';

class StatsApi extends ApiService {
  StatsApi(super.client, {super.bus, super.activity});

  Future<List<TrainerStat>> trainerStats(List<AppUser> trainers) async {
    final rows = await client.getList('/v1/stats/trainers', query: {'days': statsDays});
    final byTrainer = {
      for (final row in jsonMaps(rows)) jsonString(row['trainer_id']): TrainerSummary.fromJson(row),
    };
    return [
      for (final t in trainers)
        TrainerStat.remote(trainer: t, summary: byTrainer[t.id] ?? const TrainerSummary()),
    ];
  }
}
