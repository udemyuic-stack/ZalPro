import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/tr.dart';
import '../../models/member_analytics.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/ui.dart';

typedef ChurnLoader = Future<ChurnReport> Function();
typedef RetentionLoader = Future<Retention> Function(DateTime from, DateTime to);
typedef TrainerStatsLoader = Future<TrainerStats> Function(DateTime from, DateTime to);

const _retentionPeriods = [90, 180, 365];
const _trainerPeriods = [7, 30, 90];

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

class MemberAnalyticsScreen extends StatefulWidget {
  final bool isOwner;
  final ChurnLoader? churnLoader;
  final RetentionLoader? retentionLoader;
  final TrainerStatsLoader? trainersLoader;

  const MemberAnalyticsScreen({
    super.key,
    required this.isOwner,
    this.churnLoader,
    this.retentionLoader,
    this.trainersLoader,
  });

  @override
  State<MemberAnalyticsScreen> createState() => _MemberAnalyticsScreenState();
}

class _MemberAnalyticsScreenState extends State<MemberAnalyticsScreen> {
  var _section = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr("A'zolar tahlili"))),
        body: Column(children: [
          if (widget.isOwner)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
              child: SizedBox(
                width: double.infinity,
                child: AppSegmented<int>(
                  key: const Key('segments'),
                  segments: [
                    AppSegment(value: 0, label: tr('Xavf')),
                    AppSegment(value: 1, label: tr('Qolish')),
                    AppSegment(value: 2, label: tr('Trenerlar')),
                  ],
                  selected: _section,
                  onChanged: (v) => setState(() => _section = v),
                ),
              ),
            ),
          Expanded(
            child: switch (widget.isOwner ? _section : 0) {
              1 => _RetentionSection(key: const Key('retention'), loader: widget.retentionLoader),
              2 => _TrainersSection(key: const Key('trainers'), loader: widget.trainersLoader),
              _ => _ChurnSection(key: const Key('churn'), loader: widget.churnLoader),
            },
          ),
        ]),
      );
}

class _PeriodChips extends StatelessWidget {
  final List<int> periods;
  final int selected;
  final ValueChanged<int> onSelected;
  const _PeriodChips({required this.periods, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
        child: SizedBox(
          height: kTouchTarget,
          child: Row(children: [
            for (final d in periods)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: d == periods.last ? 0 : AppSpace.sm),
                  child: ChoiceChip(
                    key: Key('period-$d'),
                    showCheckmark: false,
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(
                        trf('{0} kun', [d]),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    selected: selected == d,
                    onSelected: (_) => onSelected(d),
                  ),
                ),
              ),
          ]),
        ),
      );
}

String _percent(double? rate) => rate == null ? '—' : '${(rate * 100).round()}%';

class _ChurnSection extends StatefulWidget {
  final ChurnLoader? loader;
  const _ChurnSection({super.key, this.loader});

  @override
  State<_ChurnSection> createState() => _ChurnSectionState();
}

const _churnFilters = ['all', 'silent', 'drop', 'expiring', 'expired'];

String _churnFilterLabel(String key) => switch (key) {
      'silent' => tr("Kelmay qo'ydi"),
      'drop' => tr('Kelishi kamaydi'),
      'expiring' => tr('Abonement tugayapti'),
      'expired' => tr('Abonement tugagan'),
      _ => tr('Hammasi'),
    };

class _ChurnSectionState extends State<_ChurnSection> {
  late Future<ChurnReport> _future = _load();
  var _filter = 'all';

  Future<ChurnReport> _load() => (widget.loader ?? Db.churn)();

  void _retry() => setState(() {
        _future = _load();
      });

  @override
  Widget build(BuildContext context) => FutureBuilder<ChurnReport>(
        key: ValueKey(_future),
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorState(error: snap.error, onRetry: _retry);
          final data = snap.data;
          if (data == null) return const Center(child: CircularProgressIndicator());
          if (data.isEmpty) {
            return EmptyState(
              icon: Icons.favorite_border,
              title: tr("Ketish xavfi ostida shogird yo'q"),
              subtitle: tr('Hammasi odatdagidek kelyapti'),
            );
          }
          int count(String key) => key == 'all'
              ? data.items.length
              : data.items.where((i) => i.reasons.contains(key)).length;
          final shown = _filter == 'all'
              ? data.items
              : data.items.where((i) => i.reasons.contains(_filter)).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xxl),
            children: [
              Text(
                trf('Jami: {0}', [data.items.length]),
                key: const Key('churn-total'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpace.sm),
              Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.xs, children: [
                for (final f in _churnFilters)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: kTouchTarget),
                    child: ChoiceChip(
                      key: Key('filter-$f'),
                      showCheckmark: false,
                      label: Text('${_churnFilterLabel(f)} (${count(f)})'),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ]),
              const SizedBox(height: AppSpace.md),
              for (final i in shown) _ChurnCard(item: i),
            ],
          );
        },
      );
}

class _ChurnCard extends StatelessWidget {
  final ChurnItem item;
  const _ChurnCard({required this.item});

  static String? _reason(String key) => switch (key) {
        'silent' => tr("Kelmay qo'ydi"),
        'drop' => tr('Kelishi kamaydi'),
        'expiring' => tr('Abonement tugayapti'),
        'expired' => tr('Abonement tugagan'),
        _ => null,
      };

  String _lastVisit() {
    final d = item.lastVisit == null ? null : DateTime.tryParse(item.lastVisit!);
    if (d == null) return tr('Hali kelmagan');
    final days = _today().difference(DateTime(d.year, d.month, d.day)).inDays;
    if (days <= 0) return tr('Oxirgi kelgan: bugun');
    return trf('Oxirgi kelgan: {0} kun oldin', [days]);
  }

  Future<void> _call(BuildContext context) async {
    final digits = item.phone.replaceAll(RegExp(r'\D'), '');
    var ok = false;
    try {
      ok = await launchUrl(Uri(scheme: 'tel', path: '+$digits'));
    } catch (_) {}
    if (!ok && context.mounted) {
      await Clipboard.setData(ClipboardData(text: fmtPhone(digits)));
      if (context.mounted) showSnack(context, tr('Raqam nusxalandi'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final reasons = [
      for (final r in item.reasons)
        if (_reason(r) != null) _reason(r)!,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: BentoTile(
        key: Key('churn-${item.userId}'),
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            UserAvatar(name: item.name, size: 40),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                _RiskLabel(score: item.score),
                Text(
                  item.hasTrainer && item.trainerName.isNotEmpty
                      ? item.trainerName
                      : tr('Trenersiz'),
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
          ]),
          const SizedBox(height: AppSpace.sm),
          Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: [
            for (final r in reasons) _ReasonChip(label: r),
          ]),
          const SizedBox(height: AppSpace.sm),
          Text(_lastVisit(), style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(
            trf('Oxirgi 14 kun: {0} · oldingi 14 kun: {1}', [item.visitsLast14, item.visitsPrev14]),
            style: t.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpace.md),
          SizedBox(
            width: double.infinity,
            height: kTouchTarget,
            child: OutlinedButton.icon(
              key: Key('call-${item.userId}'),
              onPressed: () => _call(context),
              icon: const Icon(Icons.call_outlined, size: 22),
              label: Text(tr("Qo'ng'iroq")),
            ),
          ),
        ]),
      ),
    );
  }
}

class _RiskLabel extends StatelessWidget {
  final int score;
  const _RiskLabel({required this.score});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (score) {
      >= 5 => (tr('Yuqori xavf'), AppColors.danger),
      >= 3 => (tr("O'rta xavf"), AppColors.warning),
      _ => (tr('Past xavf'), AppColors.textMuted),
    };
    return Text(
      label,
      key: const Key('risk-label'),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  final String label;
  const _ReasonChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.accentText),
        ),
      );
}

class _RetentionSection extends StatefulWidget {
  final RetentionLoader? loader;
  const _RetentionSection({super.key, this.loader});

  @override
  State<_RetentionSection> createState() => _RetentionSectionState();
}

class _RetentionSectionState extends State<_RetentionSection> {
  var _days = 180;
  late Future<Retention> _future = _load();

  Future<Retention> _load() {
    final to = _today();
    return (widget.loader ?? Db.retention)(to.subtract(Duration(days: _days)), to);
  }

  void _setDays(int d) {
    if (d == _days) return;
    setState(() {
      _days = d;
      _future = _load();
    });
  }

  void _retry() => setState(() {
        _future = _load();
      });

  @override
  Widget build(BuildContext context) => Column(children: [
        _PeriodChips(periods: _retentionPeriods, selected: _days, onSelected: _setDays),
        Expanded(
          child: FutureBuilder<Retention>(
            key: ValueKey(_future),
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) return ErrorState(error: snap.error, onRetry: _retry);
              final data = snap.data;
              if (data == null) return const Center(child: CircularProgressIndicator());
              if (data.isEmpty) {
                return EmptyState(
                  icon: Icons.group_outlined,
                  title: tr("Bu davrda yangi a'zo yo'q"),
                  subtitle: tr("Yangi a'zolar 30/60/90 kundan keyin shu yerda hisoblanadi"),
                );
              }
              return ListView(
                padding:
                    const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xxl),
                children: [for (final c in data.cohorts) _CohortCard(cohort: c)],
              );
            },
          ),
        ),
      ]);
}

class _CohortCard extends StatelessWidget {
  final RetentionCohort cohort;
  const _CohortCard({required this.cohort});

  static String _split(RetentionSplit s) =>
      s.eligible == 0 ? '—' : '${(s.retained * 100 / s.eligible).round()}%';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rate = cohort.rate;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: BentoTile(
        key: Key('cohort-${cohort.day}'),
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(trf('{0} kun', [cohort.day]), style: t.titleSmall)),
            Text(_percent(rate), key: Key('rate-${cohort.day}'), style: t.titleLarge),
          ]),
          const SizedBox(height: AppSpace.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: rate?.clamp(0.0, 1.0) ?? 0,
              minHeight: 10,
              color: AppColors.accent,
              backgroundColor: AppColors.hairline,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            trf('{0} / {1} qoldi', [cohort.retained, cohort.eligible]),
            style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            trf('Trenerli: {0} · Trenersiz: {1}',
                [_split(cohort.withTrainer), _split(cohort.withoutTrainer)]),
            key: Key('split-${cohort.day}'),
            style: t.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            trf("Qoldi = a'zo bo'lgandan {0} kun keyin keyingi 14 kun ichida kamida 1 marta kelgan",
                [cohort.day]),
            key: Key('definition-${cohort.day}'),
            style: t.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ]),
      ),
    );
  }
}

class _TrainersSection extends StatefulWidget {
  final TrainerStatsLoader? loader;
  const _TrainersSection({super.key, this.loader});

  @override
  State<_TrainersSection> createState() => _TrainersSectionState();
}

class _TrainersSectionState extends State<_TrainersSection> {
  var _days = 30;
  var _byVisits = false;
  late Future<TrainerStats> _future = _load();

  Future<TrainerStats> _load() {
    final to = _today();
    return (widget.loader ?? Db.trainerAnalytics)(to.subtract(Duration(days: _days - 1)), to);
  }

  void _setDays(int d) {
    if (d == _days) return;
    setState(() {
      _days = d;
      _future = _load();
    });
  }

  void _retry() => setState(() {
        _future = _load();
      });

  @override
  Widget build(BuildContext context) => Column(children: [
        _PeriodChips(periods: _trainerPeriods, selected: _days, onSelected: _setDays),
        Expanded(
          child: FutureBuilder<TrainerStats>(
            key: ValueKey(_future),
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) return ErrorState(error: snap.error, onRetry: _retry);
              final data = snap.data;
              if (data == null) return const Center(child: CircularProgressIndicator());
              if (data.isEmpty) {
                return EmptyState(
                  icon: Icons.fitness_center_outlined,
                  title: tr("Trener ma'lumoti yo'q"),
                  subtitle: tr("Shogirdlar biriktirilgach, natijalar shu yerda ko'rinadi"),
                );
              }
              final rows = [...data.rows]..sort((a, b) => _byVisits
                  ? b.visitsPerStudentWeek.compareTo(a.visitsPerStudentWeek)
                  : (b.hardShare ?? -1).compareTo(a.hardShare ?? -1));
              final maxVisits = rows.fold<double>(
                  0, (m, r) => r.visitsPerStudentWeek > m ? r.visitsPerStudentWeek : m);
              return ListView(
                padding:
                    const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xxl),
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: AppSegmented<bool>(
                      key: const Key('trainer-sort'),
                      segments: [
                        AppSegment(value: false, label: tr('"Qiyin" bo\'yicha')),
                        AppSegment(value: true, label: tr('Kelish bo\'yicha')),
                      ],
                      selected: _byVisits,
                      onChanged: (v) => setState(() => _byVisits = v),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  for (final r in rows) _TrainerCard(row: r, maxVisits: maxVisits),
                ],
              );
            },
          ),
        ),
      ]);
}

class _TrainerCard extends StatelessWidget {
  final TrainerRow row;
  final double maxVisits;
  const _TrainerCard({required this.row, required this.maxVisits});

  static const _lowData = 5;

  Widget _bar(double fraction, Color color) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          height: 8,
          width: double.infinity,
          color: AppColors.hairline,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction.clamp(0.0, 1.0),
            child: Container(color: color),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = t.bodyMedium?.copyWith(color: AppColors.textMuted);
    Widget line(String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Expanded(child: Text(label, style: muted)),
            const SizedBox(width: AppSpace.sm),
            Text(value, style: t.titleSmall),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: BentoTile(
        key: Key('trainer-${row.trainerId ?? 'none'}'),
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Text(
                row.trainerId == null ? tr('Trenersiz') : row.name,
                style: t.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (row.feedbackCount < _lowData) ...[
              const SizedBox(width: AppSpace.sm),
              Container(
                key: Key('lowdata-${row.trainerId ?? 'none'}'),
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  tr("kam ma'lumot"),
                  style: t.labelMedium?.copyWith(color: AppColors.textMuted),
                ),
              ),
            ],
          ]),
          const SizedBox(height: AppSpace.xs),
          line(tr('Shogirdlar'), '${row.students}'),
          line(tr('Faol shogirdlar'), '${row.activeStudents}'),
          line(tr('Haftasiga kelish (shogirdga)'), fmtNum(row.visitsPerStudentWeek)),
          const SizedBox(height: 4),
          KeyedSubtree(
            key: Key('visits-bar-${row.trainerId ?? 'none'}'),
            child:
                _bar(maxVisits <= 0 ? 0 : row.visitsPerStudentWeek / maxVisits, AppColors.accent),
          ),
          line(tr('"Qiyin" ulushi'), _percent(row.hardShare)),
          const SizedBox(height: 4),
          KeyedSubtree(
            key: Key('hard-bar-${row.trainerId ?? 'none'}'),
            child: _bar(row.hardShare ?? 0, AppColors.warning),
          ),
        ]),
      ),
    );
  }
}
