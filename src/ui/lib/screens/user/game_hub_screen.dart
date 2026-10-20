import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/game.dart';
import '../../models/models.dart';
import '../../services/api/api_error.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/game_fx.dart';
import '../../widgets/game_widgets.dart';
import '../../widgets/ui.dart';
import 'challenges_screen.dart';
import 'leaderboard_screen.dart';

class GameHubScreen extends StatefulWidget {
  final AppUser user;
  final Stream<GameMe>? meSource;
  final Future<void> Function(bool enabled)? setEnabled;
  const GameHubScreen({super.key, required this.user, this.meSource, this.setEnabled});

  @override
  State<GameHubScreen> createState() => _GameHubScreenState();
}

class _GameHubScreenState extends State<GameHubScreen> {
  late final Stream<GameMe> _me = widget.meSource ?? Db.gameMe();
  late bool _enabled = widget.user.gameEnabled;

  Future<void> _toggle(bool value) async {
    setState(() => _enabled = value);
    try {
      await (widget.setEnabled?.call(value) ?? Db.setGameEnabled(widget.user.id, value));
      if (!value && mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _enabled = !value);
      showSnack(context, trf("Saqlab bo'lmadi: {0}", [apiErrorText(e)]));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr("O'yin markazi"))),
        body: StreamBuilder<GameMe>(
          stream: _me,
          builder: (context, snap) {
            if (snap.hasError && !snap.hasData) return ErrorState(error: snap.error);
            final me = snap.data;
            if (me == null) return const Center(child: CircularProgressIndicator());
            return _Body(me: me, enabled: _enabled, onToggle: _toggle, user: widget.user);
          },
        ),
      );
}

class _Body extends StatelessWidget {
  final GameMe me;
  final AppUser user;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  const _Body({required this.me, required this.user, required this.enabled, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final level = clampLevel(me.level);
    final color = gameLevelColor(level);
    final best = me.bestSets.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        BentoTile(
          feature: true,
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xl, horizontal: AppSpace.lg),
          child: Column(children: [
            GlowRing(
              progress: me.levelProgress,
              size: 168,
              stroke: 12,
              color: color,
              ms: 1000,
              child: PopIn(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(tr('Daraja'), style: t.labelMedium?.copyWith(color: AppColors.textMuted)),
                  Text('$level', style: t.displayMedium?.copyWith(fontFeatures: tabular)),
                ]),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(gameLevelName(level), style: t.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.xs),
            Text(
              me.nextLevelXp == null
                  ? tr('Eng yuqori daraja')
                  : trf('{0} / {1} XP', [me.xp, me.nextLevelXp!]),
              style: t.bodyMedium?.copyWith(color: AppColors.textMuted, fontFeatures: tabular),
            ),
          ]),
        ),
        const SizedBox(height: AppSpace.md),
        Row(children: [
          Expanded(
            child: StatTile(
              icon: Icons.toll_outlined,
              label: tr('Coin'),
              value: '${me.coins}',
              color: AppColors.gold,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: StatTile(
              icon: Icons.local_fire_department_outlined,
              label: tr('Streak'),
              value: trf('{0} kun', [me.streakDays]),
              color: AppColors.coral,
            ),
          ),
        ]),
        const SizedBox(height: AppSpace.md),
        Row(children: [
          Expanded(
            child: StatTile(
              icon: Icons.bolt_outlined,
              label: tr('XP'),
              value: '${me.xp}',
              color: AppColors.violet,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: StatTile(
              icon: Icons.fitness_center_outlined,
              label: tr('Sessiyalar'),
              value: '${me.sessionsTotal}',
              color: AppColors.sky,
            ),
          ),
        ]),
        const SizedBox(height: AppSpace.lg),
        SectionHeader(tr('Shaxsiy rekordlar')),
        if (best.isEmpty)
          BentoTile(
            child: Text(
              tr('Hali mashq yo\'q. Birinchi sessiyadan keyin rekordlar shu yerda chiqadi.'),
              style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          )
        else
          for (final e in best) ...[
            BentoTile(
              child: Row(children: [
                Expanded(child: Text(gameExerciseName(e.key), style: t.titleMedium)),
                Text(
                  trf('{0} takror', [e.value]),
                  style: t.titleMedium?.copyWith(color: AppColors.gold, fontFeatures: tabular),
                ),
              ]),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        const SizedBox(height: AppSpace.md),
        BentoTile(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ChallengesScreen()),
          ),
          child: Row(children: [
            Icon(Icons.flag_outlined, color: AppColors.gold),
            const SizedBox(width: AppSpace.md),
            Expanded(child: Text(tr('Challenjlar'), style: t.titleMedium)),
            Icon(Icons.chevron_right, color: AppColors.textFaint),
          ]),
        ),
        const SizedBox(height: AppSpace.md),
        BentoTile(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => LeaderboardScreen(user: user)),
          ),
          child: Row(children: [
            Icon(Icons.leaderboard_outlined, color: AppColors.violet),
            const SizedBox(width: AppSpace.md),
            Expanded(child: Text(tr('Zal reytingi'), style: t.titleMedium)),
            Icon(Icons.chevron_right, color: AppColors.textFaint),
          ]),
        ),
        const SizedBox(height: AppSpace.md),
        BentoTile(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: enabled,
            onChanged: onToggle,
            title: Text(tr("O'yin rejimi")),
            subtitle: Text(tr("O'chirsangiz daraja, coin va reyting ko'rinmaydi. Natijangiz saqlanadi.")),
          ),
        ),
      ],
    );
  }
}
