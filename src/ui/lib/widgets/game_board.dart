import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../models/game.dart';
import '../services/db.dart';
import '../theme.dart';
import 'game_widgets.dart';
import 'ui.dart';

typedef GameBoardSource = Stream<GameLeaderboard> Function(String period, String? exercise);

const _periods = ['day', 'week', 'month', 'year', 'all'];
const _exercises = ['squat', 'pushup', 'pullup'];

String _periodLabel(String key) => switch (key) {
      'day' => tr('Kun'),
      'week' => tr('Hafta'),
      'month' => tr('Oy'),
      'year' => tr('Yil'),
      _ => tr('Hammasi'),
    };

class GameBoardView extends StatefulWidget {
  final String userId;
  final GameBoardSource? source;
  const GameBoardView({super.key, required this.userId, this.source});

  @override
  State<GameBoardView> createState() => _GameBoardViewState();
}

class _GameBoardViewState extends State<GameBoardView> {
  String _period = 'week';
  String? _exercise;
  late Stream<GameLeaderboard> _stream = _open();

  Stream<GameLeaderboard> _open() =>
      (widget.source ?? (p, e) => Db.gameLeaderboard(period: p, exercise: e))(_period, _exercise);

  void _change({String? period, Object? exercise = _keep}) {
    setState(() {
      if (period != null) _period = period;
      if (!identical(exercise, _keep)) _exercise = exercise as String?;
      _stream = _open();
    });
  }

  static const Object _keep = Object();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        AppSegmented<String>(
          segments: [for (final p in _periods) AppSegment(value: p, label: _periodLabel(p))],
          selected: _period,
          onChanged: (v) => _change(period: v),
        ),
        const SizedBox(height: AppSpace.md),
        SizedBox(
          height: kTouchTarget,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                label: tr('Hammasi'),
                selected: _exercise == null,
                onTap: () => _change(exercise: null),
              ),
              for (final e in _exercises)
                _FilterChip(
                  label: gameExerciseName(e),
                  selected: _exercise == e,
                  onTap: () => _change(exercise: e),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        StreamBuilder<GameLeaderboard>(
          stream: _stream,
          builder: (context, snap) {
            if (snap.hasError && !snap.hasData) return ErrorState(error: snap.error);
            final board = snap.data;
            if (board == null) {
              return const Padding(
                padding: EdgeInsets.all(AppSpace.xl),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (board.top.isEmpty) {
              return EmptyState(
                icon: Icons.emoji_events_outlined,
                title: tr("Hozircha reytingda hech kim yo'q"),
                subtitle: tr('Kamera bilan mashq qiling: takrorlar shu yerda chiqadi'),
              );
            }
            final rest = board.top.skip(3).toList();
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _Podium(top: board.top.take(3).toList(), me: widget.userId),
              const SizedBox(height: AppSpace.lg),
              for (final row in rest)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: _GameRow(entry: row, mine: row.userId == widget.userId),
                ),
              if (board.me != null) ...[
                const SizedBox(height: AppSpace.sm),
                BentoTile(
                  key: const Key('game-board-mine'),
                  feature: true,
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: Row(children: [
                    Icon(Icons.person_outline, color: AppColors.accent),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Text(
                        trf("Sizning o'rningiz: {0}", [board.me!.rank]),
                        style: t.titleMedium,
                      ),
                    ),
                    Text(
                      trf('{0} takror', [board.me!.reps]),
                      style: t.titleMedium?.copyWith(color: AppColors.gold, fontFeatures: tabular),
                    ),
                  ]),
                ),
              ],
            ]);
          },
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: AppSpace.sm),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
      );
}

class _Podium extends StatelessWidget {
  final List<GameEntry> top;
  final String me;
  const _Podium({required this.top, required this.me});

  @override
  Widget build(BuildContext context) {
    final order = <GameEntry?>[
      top.length > 1 ? top[1] : null,
      top.first,
      top.length > 2 ? top[2] : null,
    ];
    const heights = [96.0, 128.0, 76.0];
    const colors = [null, 0, 1];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: order[i] == null
                ? const SizedBox.shrink()
                : _PodiumColumn(
                    entry: order[i]!,
                    height: heights[i],
                    delayMs: colors[i] == 0 ? 0 : 120,
                    mine: order[i]!.userId == me,
                  ),
          ),
      ],
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  final GameEntry entry;
  final double height;
  final int delayMs;
  final bool mine;
  const _PodiumColumn({
    required this.entry,
    required this.height,
    required this.delayMs,
    required this.mine,
  });

  Color get _color => switch (entry.rank) {
        1 => AppColors.gold,
        2 => AppColors.sky,
        _ => AppColors.coral,
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        PopIn(
          delayMs: delayMs,
          child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _color.withValues(alpha: 0.18),
              border: Border.all(color: _color, width: mine ? 3 : 2),
              boxShadow: [BoxShadow(color: _color.withValues(alpha: 0.4), blurRadius: 14)],
            ),
            child: Text(initials(entry.name), style: t.titleMedium),
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: t.labelLarge?.copyWith(color: mine ? AppColors.accent : null),
        ),
        Text(
          trf('{0} takror', [entry.reps]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.bodySmall?.copyWith(color: AppColors.textMuted, fontFeatures: tabular),
        ),
        const SizedBox(height: AppSpace.xs),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: height),
          duration: motion(context, 700 + delayMs),
          curve: Curves.easeOutCubic,
          builder: (context, h, child) => Container(
            height: h,
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: AppSpace.sm),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_color.withValues(alpha: 0.55), _color.withValues(alpha: 0.08)],
              ),
            ),
            child: h > 28
                ? Text('${entry.rank}', style: t.headlineSmall?.copyWith(fontFeatures: tabular))
                : null,
          ),
        ),
      ]),
    );
  }
}

class _GameRow extends StatelessWidget {
  final GameEntry entry;
  final bool mine;
  const _GameRow({required this.entry, required this.mine});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return BentoTile(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(children: [
        SizedBox(width: 36, child: Text('${entry.rank}', style: t.titleMedium)),
        Expanded(
          child: Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.titleMedium?.copyWith(color: mine ? AppColors.accent : null),
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            trf('{0} takror', [entry.reps]),
            style: t.titleMedium?.copyWith(fontFeatures: tabular),
          ),
          Text(
            trf('{0} XP', [entry.xp]),
            style: t.bodySmall?.copyWith(color: AppColors.textMuted, fontFeatures: tabular),
          ),
        ]),
      ]),
    );
  }
}
