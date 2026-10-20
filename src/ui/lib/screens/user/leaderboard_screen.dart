import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/leaderboard.dart';
import '../../models/models.dart';
import '../../services/api/api_error.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/game_board.dart';
import '../../widgets/ui.dart';

class LeaderboardScreen extends StatefulWidget {
  final AppUser user;
  final Stream<Leaderboard>? boardSource;
  final Stream<AppUser?>? userSource;
  final Future<void> Function(bool visible)? setVisible;
  final GameBoardSource? gameBoardSource;
  const LeaderboardScreen({
    super.key,
    required this.user,
    this.boardSource,
    this.userSource,
    this.setVisible,
    this.gameBoardSource,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final _board = widget.boardSource ?? Db.leaderboard();
  late final _me = widget.userSource ?? Db.user(widget.user.id);
  String _tab = 'points';

  Future<void> _toggle(bool visible) async {
    try {
      await (widget.setVisible?.call(visible) ?? Db.setLeaderboardVisible(widget.user.id, visible));
    } catch (e) {
      if (mounted) showSnack(context, trf("Saqlab bo'lmadi: {0}", [apiErrorText(e)]));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr('Zal reytingi'))),
        body: Column(children: [
          if (widget.user.gameEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
              child: AppSegmented<String>(
                segments: [
                  AppSegment(value: 'points', label: tr('Ball')),
                  AppSegment(value: 'reps', label: tr('Takror')),
                ],
                selected: _tab,
                onChanged: (v) => setState(() => _tab = v),
              ),
            ),
          Expanded(
            child: _tab == 'reps' && widget.user.gameEnabled
                ? GameBoardView(userId: widget.user.id, source: widget.gameBoardSource)
                : _pointsBody(),
          ),
        ]),
      );

  Widget _pointsBody() => StreamBuilder<Leaderboard>(
        stream: _board,
        builder: (context, snap) {
          if (snap.hasError && !snap.hasData) return ErrorState(error: snap.error);
          final board = snap.data;
          if (board == null) return const Center(child: CircularProgressIndicator());
          return StreamBuilder<AppUser?>(
            stream: _me,
            initialData: widget.user,
            builder: (context, me) => _Body(
              board: board,
              user: me.data ?? widget.user,
              canJoin: widget.user.role == 'user',
              onToggle: _toggle,
            ),
          );
        },
      );
}

class _Body extends StatelessWidget {
  final Leaderboard board;
  final AppUser user;
  final bool canJoin;
  final ValueChanged<bool> onToggle;
  const _Body({
    required this.board,
    required this.user,
    required this.canJoin,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        Text(
          trf('Oxirgi {0} kun', [board.periodDays]),
          style: t.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          tr("Kelgan kun — 10 ball, mashq — 5 ball, haftada 3 faol kun — +15 ball"),
          style: t.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpace.lg),
        if (board.top.isEmpty)
          EmptyState(
            icon: Icons.emoji_events_outlined,
            title: tr("Hozircha reytingda hech kim yo'q"),
            subtitle: tr("Zalga keling va mashq qiling: ball to'planadi"),
          )
        else
          for (var i = 0; i < board.top.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: FadeInUp(
                index: i < 8 ? i : 8,
                child: _Row(entry: board.top[i], mine: board.top[i].userId == user.id),
              ),
            ),
        if (canJoin) ...[
          const SizedBox(height: AppSpace.lg),
          _Mine(board: board, user: user),
          const SizedBox(height: AppSpace.sm),
          SwitchListTile(
            key: const Key('leaderboard-visible'),
            contentPadding: EdgeInsets.zero,
            value: user.showInLeaderboard,
            onChanged: onToggle,
            title: Text(tr("Reytingda ko'rinish")),
            subtitle: Text(tr("Ismingiz boshqa shogirdlarga ko'rinadi")),
          ),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool mine;
  const _Row({required this.entry, required this.mine});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final medal = switch (entry.rank) {
      1 => AppColors.gold,
      2 => AppColors.sky,
      3 => AppColors.coral,
      _ => null,
    };
    return BentoTile(
      feature: mine || entry.rank == 1,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(children: [
        SizedBox(
          width: 36,
          child: medal == null
              ? Text('${entry.rank}', style: t.titleMedium?.copyWith(color: AppColors.textMuted))
              : PopIn(
                  delayMs: entry.rank * 80,
                  child: Icon(Icons.emoji_events_outlined, color: medal, size: 28),
                ),
        ),
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
          Text(trf('{0} ball', [entry.points]), style: t.titleMedium),
          Text(
            trf('{0} kun', [entry.activeDays]),
            style: t.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ]),
      ]),
    );
  }
}

class _Mine extends StatelessWidget {
  final Leaderboard board;
  final AppUser user;
  const _Mine({required this.board, required this.user});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final me = board.me;
    final String title;
    String? detail;
    if (!user.showInLeaderboard) {
      title = tr("Reytingda ko'rinmaysiz");
    } else if (me == null) {
      title = tr("Hali ballingiz yo'q");
    } else {
      title = trf('Sizning o\'rningiz: {0}', [me.rank]);
      detail = '${trf('{0} ball', [me.points])} · ${trf('{0} kun', [me.activeDays])}';
    }
    return BentoTile(
      key: const Key('leaderboard-mine'),
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(children: [
        Icon(Icons.person_outline, color: AppColors.accent),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleMedium),
            if (detail != null)
              Text(detail, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          ]),
        ),
      ]),
    );
  }
}
