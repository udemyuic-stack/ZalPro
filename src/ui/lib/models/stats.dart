import '../l10n/tr.dart';
import '../services/api/json_helpers.dart';
import 'models.dart';

/// Trenerlar reytingi uchun hisob-kitob. Firestore'ga bog'liq emas — faqat
/// yuklab olingan ma'lumotdan ball chiqaradi (testlanadi).

/// Reyting davri
const statsDays = 7;

/// Bitta shogird bo'yicha ko'rsatkichlar
class ClientStat {
  final AppUser client;

  /// Biriktirilgan rejadagi mahallar soni (reja yo'q bo'lsa 0)
  final int mealsPerDay;

  /// So'nggi [trackedDays] kunda "yedim" belgilangan mahallar (har kun reja hajmi bilan cheklangan)
  final int mealsDone;
  final List<WeightLog> weights; // eskidan yangiga
  final List<ChatMessage> messages; // yangidan eskiga
  final DateTime now;

  ClientStat({
    required this.client,
    required this.mealsPerDay,
    required this.mealsDone,
    required this.weights,
    required this.messages,
    required this.now,
  });

  bool get hasPlan => client.planId != null && mealsPerDay > 0;

  /// Rioya hisoblanadigan kunlar: reja [statsDays] kundan kam oldin berilgan bo'lsa —
  /// faqat berilgan kundan bugungacha (kechagi reja 7 kunga bo'linib past chiqmasin).
  /// Berilgan vaqti noma'lum (eski hujjat) bo'lsa — to'liq davr.
  int get trackedDays => trackedDaysFor(client.planAssignedAt, now);

  static int trackedDaysFor(DateTime? assignedAt, DateTime now) {
    if (assignedAt == null) return statsDays;
    return (WeightLog.daysSince(assignedAt, now) + 1).clamp(1, statsDays);
  }

  /// Rejaga rioya: 0..1, reja yo'q bo'lsa null
  double? get adherence =>
      hasPlan ? (mealsDone / (mealsPerDay * trackedDays)).clamp(0.0, 1.0) : null;

  /// Oxirgi xabarni shogird yozgan va hali javob yo'q
  bool get waitingReply => messages.isNotEmpty && messages.first.senderId == client.id;

  Duration? get waitingFor => waitingReply ? now.difference(messages.first.createdAt) : null;

  /// Trener (yoki boshqa xodim) so'nggi davrda shogirdga yozgan xabarlar
  int staffMessages({String? by}) => messages
      .where((m) =>
          m.senderId != client.id &&
          (by == null || m.senderId == by) &&
          now.difference(m.createdAt).inDays < statsDays)
      .length;

  double? get weightChange =>
      weights.length < 2 ? null : weights.last.weight - weights.first.weight;

  /// Maqsad tomon siljiyaptimi: ozish — vazn kamaygan, massa — ko'paygan.
  /// Vazn 2 martadan kam kiritilgan yoki maqsad tanlanmagan bo'lsa null.
  bool? get progressing {
    final d = weightChange;
    if (d == null || client.goal.isEmpty) return null;
    return client.isGain ? d > 0 : d < 0;
  }

  DateTime? get lastWeighIn => weights.isEmpty ? null : weights.last.date;

  /// Trener nimaga e'tibor berishi kerak — bo'sh bo'lsa hammasi joyida
  List<String> get attention {
    final r = <String>[];
    if (!client.profileDone || client.goal.isEmpty) r.add(tr("Anketa to'liq emas"));
    if (client.planId == null) r.add(tr("Reja berilmagan"));
    final w = waitingFor;
    if (w != null && w.inHours >= 12) {
      r.add(w.inDays >= 1
          ? trf('Javob kutmoqda: {0} kun', [w.inDays])
          : trf('Javob kutmoqda: {0} soat', [w.inHours]));
    }
    final a = adherence;
    if (a != null && a < 0.5) r.add(trf('Rejaga rioya past: {0}%', [(a * 100).round()]));
    final last = lastWeighIn;
    if (client.profileDone && (last == null || now.difference(last).inDays > 14)) {
      r.add(tr('Vazn 2 haftadan beri kiritilmagan'));
    }
    if (progressing == false) r.add(tr("Vazn maqsadga qarab o'zgarmayapti"));
    return r;
  }
}

/// Bitta trener bo'yicha umumiy ko'rsatkichlar va ball
class TrainerSummary {
  final int clientCount;
  final double? planCoverage;
  final double? replyRate;
  final double? adherence;
  final double? progressRate;
  final int messagesSent;
  final int? score;
  final int? stars;

  const TrainerSummary({
    this.clientCount = 0,
    this.planCoverage,
    this.replyRate,
    this.adherence,
    this.progressRate,
    this.messagesSent = 0,
    this.score,
    this.stars,
  });

  static double? _rate(Object? v) => v is num ? v.toDouble() : null;

  static int? _whole(Object? v) => v is num ? v.toInt() : null;

  factory TrainerSummary.fromJson(Map<String, dynamic> j) => TrainerSummary(
        clientCount: jsonInt(j['client_count']),
        planCoverage: _rate(j['plan_coverage']),
        replyRate: _rate(j['reply_rate']),
        adherence: _rate(j['adherence']),
        progressRate: _rate(j['progress_rate']),
        messagesSent: jsonInt(j['messages_sent']),
        score: _whole(j['score']),
        stars: _whole(j['stars']),
      );
}

class TrainerStat {
  final AppUser trainer;
  final List<ClientStat> clients;
  final TrainerSummary? summary;
  TrainerStat({required this.trainer, required this.clients}) : summary = null;
  TrainerStat.remote({required this.trainer, required TrainerSummary this.summary})
      : clients = const [];

  bool get hasClientDetail => summary == null;

  int get clientCount => summary?.clientCount ?? clients.length;

  static double? _share(Iterable<bool> xs) {
    final l = xs.toList();
    return l.isEmpty ? null : l.where((x) => x).length / l.length;
  }

  /// Reja berilgan shogirdlar ulushi
  double? get planCoverage {
    final r = summary;
    if (r != null) return r.planCoverage;
    return _share(clients.map((c) => c.client.planId != null));
  }

  /// Yozgan shogirdlardan javob olganlari ulushi
  double? get replyRate {
    final r = summary;
    if (r != null) return r.replyRate;
    return _share(clients.where((c) => c.messages.isNotEmpty).map((c) => !c.waitingReply));
  }

  /// Shogirdlarning rejaga o'rtacha rioyasi
  double? get adherence {
    final r = summary;
    if (r != null) return r.adherence;
    final xs = clients.map((c) => c.adherence).whereType<double>().toList();
    return xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
  }

  /// Vazni maqsad tomon siljiyotgan shogirdlar ulushi
  double? get progressRate {
    final r = summary;
    if (r != null) return r.progressRate;
    return _share(clients.map((c) => c.progressing).whereType<bool>());
  }

  int get messagesSent =>
      summary?.messagesSent ?? clients.fold(0, (s, c) => s + c.staffMessages(by: trainer.id));

  List<ClientStat> get needAttention => clients.where((c) => c.attention.isNotEmpty).toList()
    ..sort((a, b) => b.attention.length.compareTo(a.attention.length));

  /// Ball tarkibi: (nomi, ulush 0..1 yoki null, og'irligi)
  List<(String, double?, int)> get parts => [
        (tr('Reja berilgan'), planCoverage, 30),
        (tr('Chatga javob'), replyRate, 25),
        (tr('Shogirdlar rioyasi'), adherence, 25),
        (tr('Natija (vazn)'), progressRate, 20),
      ];

  /// 0..100. Ma'lumoti yo'q qismlar hisobga olinmaydi; shogird yo'q bo'lsa null.
  int? get score {
    final r = summary;
    if (r != null) return r.score;
    if (clients.isEmpty) return null;
    var sum = 0.0, weight = 0;
    for (final (_, v, w) in parts) {
      if (v == null) continue;
      sum += v * w;
      weight += w;
    }
    return weight == 0 ? null : (sum / weight * 100).round();
  }

  /// 1..5 yulduz
  int? get stars {
    final r = summary;
    if (r != null) return r.stars;
    final s = score;
    return s == null ? null : (s / 20).ceil().clamp(1, 5);
  }
}
