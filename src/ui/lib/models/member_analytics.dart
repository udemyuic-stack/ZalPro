import '../services/api/json_helpers.dart';

class ChurnItem {
  final String userId;
  final String name;
  final String phone;
  final String? trainerId;
  final String trainerName;
  final List<String> reasons;
  final int score;
  final String? lastVisit;
  final int visitsLast14;
  final int visitsPrev14;
  final String? expiresAt;

  const ChurnItem({
    required this.userId,
    required this.name,
    required this.phone,
    this.trainerId,
    this.trainerName = '',
    this.reasons = const [],
    this.score = 0,
    this.lastVisit,
    this.visitsLast14 = 0,
    this.visitsPrev14 = 0,
    this.expiresAt,
  });

  factory ChurnItem.fromJson(Map<String, dynamic> j) => ChurnItem(
        userId: jsonString(j['user_id']),
        name: jsonString(j['name']),
        phone: jsonString(j['phone']),
        trainerId: jsonStringOrNull(j['trainer_id']),
        trainerName: jsonString(j['trainer_name']),
        reasons: jsonStrings(j['reasons']),
        score: jsonInt(j['score']),
        lastVisit: jsonStringOrNull(j['last_visit']),
        visitsLast14: jsonInt(j['visits_last14']),
        visitsPrev14: jsonInt(j['visits_prev14']),
        expiresAt: jsonStringOrNull(j['expires_at']),
      );

  bool get hasTrainer => trainerId != null;
}

class ChurnReport {
  final String asOf;
  final List<ChurnItem> items;

  const ChurnReport({this.asOf = '', this.items = const []});

  factory ChurnReport.fromJson(Map<String, dynamic> j) => ChurnReport(
        asOf: jsonString(j['as_of']),
        items: [for (final r in jsonMaps(j['items'])) ChurnItem.fromJson(r)],
      );

  bool get isEmpty => items.isEmpty;
}

class RetentionSplit {
  final int eligible;
  final int retained;

  const RetentionSplit({this.eligible = 0, this.retained = 0});

  factory RetentionSplit.fromJson(Object? v) {
    if (v is! Map) return const RetentionSplit();
    final j = Map<String, dynamic>.from(v);
    return RetentionSplit(eligible: jsonInt(j['eligible']), retained: jsonInt(j['retained']));
  }
}

class RetentionCohort {
  final int day;
  final int eligible;
  final int retained;
  final double? rate;
  final RetentionSplit withTrainer;
  final RetentionSplit withoutTrainer;

  const RetentionCohort({
    required this.day,
    this.eligible = 0,
    this.retained = 0,
    this.rate,
    this.withTrainer = const RetentionSplit(),
    this.withoutTrainer = const RetentionSplit(),
  });

  factory RetentionCohort.fromJson(Map<String, dynamic> j) => RetentionCohort(
        day: jsonInt(j['day']),
        eligible: jsonInt(j['eligible']),
        retained: jsonInt(j['retained']),
        rate: j['rate'] is num ? (j['rate'] as num).toDouble() : null,
        withTrainer: RetentionSplit.fromJson(j['with_trainer']),
        withoutTrainer: RetentionSplit.fromJson(j['without_trainer']),
      );
}

class Retention {
  final String from;
  final String to;
  final List<RetentionCohort> cohorts;

  const Retention({this.from = '', this.to = '', this.cohorts = const []});

  factory Retention.fromJson(Map<String, dynamic> j) => Retention(
        from: jsonString(j['from']),
        to: jsonString(j['to']),
        cohorts: [for (final r in jsonMaps(j['cohorts'])) RetentionCohort.fromJson(r)],
      );

  bool get isEmpty => cohorts.every((c) => c.eligible == 0);
}

class TrainerRow {
  final String? trainerId;
  final String name;
  final int students;
  final int activeStudents;
  final double visitsPerStudentWeek;
  final int feedbackCount;
  final int hardCount;
  final double? hardShare;

  const TrainerRow({
    this.trainerId,
    this.name = '',
    this.students = 0,
    this.activeStudents = 0,
    this.visitsPerStudentWeek = 0,
    this.feedbackCount = 0,
    this.hardCount = 0,
    this.hardShare,
  });

  factory TrainerRow.fromJson(Map<String, dynamic> j) => TrainerRow(
        trainerId: jsonStringOrNull(j['trainer_id']),
        name: jsonString(j['name']),
        students: jsonInt(j['students']),
        activeStudents: jsonInt(j['active_students']),
        visitsPerStudentWeek: jsonDouble(j['visits_per_student_week']),
        feedbackCount: jsonInt(j['feedback_count']),
        hardCount: jsonInt(j['hard_count']),
        hardShare: j['hard_share'] is num ? (j['hard_share'] as num).toDouble() : null,
      );
}

class TrainerStats {
  final String from;
  final String to;
  final List<TrainerRow> rows;

  const TrainerStats({this.from = '', this.to = '', this.rows = const []});

  factory TrainerStats.fromJson(Map<String, dynamic> j) => TrainerStats(
        from: jsonString(j['from']),
        to: jsonString(j['to']),
        rows: [for (final r in jsonMaps(j['rows'])) TrainerRow.fromJson(r)],
      );

  bool get isEmpty => rows.every((r) => r.students == 0);
}
