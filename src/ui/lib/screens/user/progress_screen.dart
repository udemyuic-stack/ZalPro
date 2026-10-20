import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/input_rules.dart';
import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../models/weight_trend.dart';
import '../../services/api/api_error.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/progress_photos.dart';
import '../../widgets/ui.dart';

/// Vazn haftada faqat 1 marta kiritiladi — erta kiritib bo'lmaydi:
/// kunlik tebranish (1–2 kg) grafikni chalg'itadi.
Future<void> addWeightSheet(BuildContext context, AppUser user, WeightLog? lastLog) async {
  if (!WeightLog.canAdd(lastLog)) {
    final left = WeightLog.daysLeft(lastLog);
    showSnack(
      context,
      trf(
          "Vazn haftada 1 marta kiritiladi. Keyingi o'lchov "
          "{0}.",
          [
            left == 1 ? tr('ertaga') : trf('{0} kundan keyin', [left])
          ]),
    );
    return;
  }
  final c = TextEditingController(text: user.weight > 0 ? fmtNum(user.weight) : '');
  final form = GlobalKey<FormState>();
  // Ekran o'rtasidagi pop-up emas — pastdan chiquvchi varaq (bosh barmoq zonasi)
  final w = await showSheet<double>(
    context,
    Form(
      key: form,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Bugungi vazn'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpace.xs),
            Text(
              tr('Haftada 1 marta — ertalab, nahorga tortiling'),
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: AppSpace.lg),
            TextFormField(
              controller: c,
              autofocus: true,
              textAlign: TextAlign.center,
              inputFormatters: InputRules.decimalOnly(maxDecimals: 1),
              validator: InputRules.decimalRange(InputLimits.weightMin, InputLimits.weightMax),
              style:
                  const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, fontFeatures: tabular),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(suffixText: tr('kg')),
            ),
            const SizedBox(height: AppSpace.lg),
            FilledButton(
              onPressed: () {
                if (InputRules.validateAndFocus(form)) {
                  Navigator.pop(context, InputRules.parseDecimal(c.text));
                }
              },
              child: Text(tr('Saqlash')),
            ),
            const SizedBox(height: AppSpace.sm),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('Bekor')),
            ),
          ]),
    ),
  );
  if (w == null) return;
  try {
    await Db.addWeight(user.id, w);
    if (context.mounted) showSnack(context, trf('Saqlandi: {0} kg', [fmtNum(w)]));
  } catch (e) {
    if (context.mounted) showSnack(context, trf("Bo'lmadi: {0}", [apiErrorText(e)]));
  }
}

class ProgressScreen extends StatelessWidget {
  final AppUser user;
  final bool readOnly;
  const ProgressScreen({super.key, required this.user, this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return StreamBuilder<List<WeightLog>>(
      stream: Db.weights(user.id),
      builder: (context, snap) {
        final all = snap.data;
        final lastLog = (all == null || all.isEmpty) ? null : all.last;
        // O'lchov muddati kelganda tugma urg'uli; kelmaguncha — o'chiq, necha kun qolgani yoziladi
        final due = WeightLog.canAdd(lastLog);
        return Scaffold(
          appBar: readOnly ? null : AppBar(title: Text(tr('Progress'))),
          floatingActionButton: readOnly || !due
              ? null
              : FloatingActionButton.extended(
                  onPressed: snap.hasData ? () => addWeightSheet(context, user, lastLog) : null,
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                  icon: const Icon(Icons.add),
                  label: Text(tr('Vazn kiritish')),
                ),
          body: Builder(
            builder: (context) {
              if (snap.hasError) return ErrorState(error: snap.error);
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final logs = snap.data!;
              if (logs.isEmpty) {
                return EmptyState(
                  icon: Icons.monitor_weight_outlined,
                  title: tr('Hali vazn kiritilmagan'),
                  subtitle: readOnly
                      ? null
                      : tr("Haftada 1 marta, ertalab nahorga tortilib, vazningizni kiriting. "
                          "Har kuni o'lchash shart emas — vazn kun davomida 1–2 kg tebranadi."),
                );
              }
              final first = logs.first.weight, last = logs.last.weight;
              final diff = last - first;
              final weights = logs.map((e) => e.weight);
              final minY = (weights.reduce((a, b) => a < b ? a : b) - 2).floorToDouble();
              final maxY = (weights.reduce((a, b) => a > b ? a : b) + 2).ceilToDouble();

              return ListView(
                padding:
                    EdgeInsets.fromLTRB(AppSpace.lg, readOnly ? 0 : AppSpace.sm, AppSpace.lg, 96),
                children: [
                  // Bosh ko'rsatkich — umumiy o'zgarish, ink fonda yirik raqam
                  FadeInUp(
                      child: _ChangePanel(diff: diff, from: first, to: last, gain: user.isGain)),
                  const SizedBox(height: AppSpace.md),
                  if (!readOnly) ...[
                    FadeInUp(index: 1, child: _WeeklyCard(last: logs.last)),
                    const SizedBox(height: AppSpace.md),
                  ],
                  FadeInUp(
                    index: 2,
                    child: Row(children: [
                      Expanded(
                        child: StatTile(
                          icon: Icons.flag_outlined,
                          label: tr("Boshlang'ich"),
                          value: trf('{0} kg', [fmtNum(first)]),
                          color: s.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: StatTile(
                          icon: Icons.monitor_weight_outlined,
                          label: tr('Hozir'),
                          value: trf('{0} kg', [fmtNum(last)]),
                          color: AppColors.water,
                        ),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: StatTile(
                          icon: Icons.event_repeat_outlined,
                          label: tr("O'lchov"),
                          value: '${logs.length}',
                          color: AppColors.protein,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: AppSpace.md),
                  BentoTile(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.md, AppSpace.lg, AppSpace.xl, AppSpace.md),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpace.sm, bottom: AppSpace.lg),
                        child: Eyebrow(tr('Vazn dinamikasi'), color: s.onSurfaceVariant),
                      ),
                      if (logs.length < 2)
                        SizedBox(
                          height: 120,
                          child: Center(
                            child: Text(
                              tr("Grafik uchun kamida 2 ta o'lchov kerak"),
                              textAlign: TextAlign.center,
                              style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                        height: 220,
                        child: LineChart(LineChartData(
                          minY: minY,
                          maxY: maxY,
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: s.outlineVariant.withValues(alpha: 0.5),
                              strokeWidth: 1,
                              dashArray: const [4, 4],
                            ),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles:
                                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles:
                                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 36,
                                getTitlesWidget: (v, meta) => Text(
                                  v.toStringAsFixed(0),
                                  style: t.bodySmall?.copyWith(color: s.onSurfaceVariant),
                                ),
                              ),
                            ),
                          ),
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (_) => s.inverseSurface,
                              getTooltipItems: (spots) => spots
                                  .map((sp) => LineTooltipItem(
                                        trf('{0} kg\n', [fmtNum(sp.y)]),
                                        TextStyle(
                                            color: s.onInverseSurface, fontWeight: FontWeight.w700),
                                        children: [
                                          TextSpan(
                                            text:
                                                DateFormat('dd.MM').format(logs[sp.x.toInt()].date),
                                            style: TextStyle(
                                              color: s.onInverseSurface.withValues(alpha: 0.7),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ))
                                  .toList(),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: [
                                for (var i = 0; i < logs.length; i++)
                                  FlSpot(i.toDouble(), logs[i].weight),
                              ],
                              isCurved: true,
                              preventCurveOverShooting: true,
                              color: AppColors.secondary,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                                  radius: 4,
                                  color: s.surface,
                                  strokeWidth: 2.5,
                                  strokeColor: AppColors.secondary,
                                ),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.secondary.withValues(alpha: 0.25),
                                    AppColors.secondary.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )),
                      ),
                    ]),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  ProgressPhotos(uid: user.id, weight: last, readOnly: readOnly),
                  SectionHeader(tr('Tarix'), eyebrow: tr("O'lchovlar")),
                  BentoTile(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (var i = logs.length - 1; i >= 0; i--) ...[
                        _HistoryRow(log: logs[i], prev: i > 0 ? logs[i - 1] : null, gain: user.isGain),
                        if (i > 0) const Divider(indent: AppSpace.lg, endIndent: AppSpace.lg),
                      ],
                    ]),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Haftalik o'lchov holati: keyingi o'lchovgacha necha kun qolgani.
/// Vazn haftada 1 marta kiritiladi — kunlik tebranish (1–2 kg) natijani buzadi.
class _WeeklyCard extends StatelessWidget {
  final WeightLog last;
  const _WeeklyCard({required this.last});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final days = WeightLog.daysSince(last.date);
    final left = WeightLog.daysLeft(last);
    final due = left <= 0;

    final (String title, String sub, Color color, IconData icon) = due
        ? (
            tr('Vaznni kiritish vaqti keldi'),
            days == 7
                ? tr("Oxirgi o'lchovdan 7 kun o'tdi")
                : trf("Oxirgi o'lchovdan {0} kun o'tdi", [days]),
            AppColors.warning,
            Icons.notifications_active_outlined,
          )
        : (
            left == 1
                ? tr("Keyingi o'lchov ertaga")
                : trf("Keyingi o'lchov {0} kundan keyin", [left]),
            tr("Haftada faqat 1 marta — ungacha vaznni o'zgartirib bo'lmaydi"),
            AppColors.success,
            Icons.event_available_outlined,
          );

    return BentoTile(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Row(children: [
        IconBadge(icon, color: color, size: 38),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleMedium),
            const SizedBox(height: 2),
            Text(sub, style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }
}

/// Umumiy o'zgarish — ink fonda yirik editorial raqam
class _ChangePanel extends StatelessWidget {
  final double diff, from, to;

  /// Massa nabor maqsadida vazn oshishi — yaxshi natija (urg'u rangi), ozishda — kamayishi
  final bool gain;
  const _ChangePanel({
    required this.diff,
    required this.from,
    required this.to,
    this.gain = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accent = weightTrendColor(weightTrendOf(diff, gainGoal: gain));
    final sign = diff > 0 ? '+' : (diff < 0 ? '−' : '');
    return BentoTile(
      feature: true,
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Eyebrow(tr("Umumiy o'zgarish"), color: AppColors.textFaint)),
          Icon(
            diff == 0
                ? Icons.trending_flat_rounded
                : (diff < 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded),
            color: accent,
            size: 20,
          ),
        ]),
        const SizedBox(height: AppSpace.md),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$sign${diff.abs().toStringAsFixed(1)}',
                  style: t.displaySmall?.copyWith(color: accent, fontFeatures: tabular),
                ),
                const SizedBox(width: AppSpace.sm),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(tr('kg'), style: t.titleMedium?.copyWith(color: AppColors.textFaint)),
                ),
              ]),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          trf('{0} kg dan {1} kg gacha', [fmtNum(from), fmtNum(to)]),
          style: t.bodySmall?.copyWith(
            color: AppColors.textMuted,
            fontFeatures: tabular,
          ),
        ),
      ]),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final WeightLog log;
  final WeightLog? prev;
  final bool gain;
  const _HistoryRow({required this.log, this.prev, this.gain = false});

  @override
  Widget build(BuildContext context) {
    final d = prev == null ? null : log.weight - prev!.weight;
    return ListTile(
      title: Text(trf('{0} kg', [fmtNum(log.weight)]),
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(DateFormat('dd.MM.yyyy, HH:mm').format(log.date)),
      trailing: d == null
          ? null
          : Pill(
              text: '${d > 0 ? '+' : ''}${d.toStringAsFixed(1)}',
              color: weightTrendColor(weightTrendOf(d, gainGoal: gain)),
              icon: d <= 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            ),
    );
  }
}
