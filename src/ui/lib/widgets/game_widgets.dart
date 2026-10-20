import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../models/game.dart';
import '../models/models.dart';
import '../screens/user/game_hub_screen.dart';
import '../services/api/api_error.dart';
import '../services/db.dart';
import '../theme.dart';
import 'game_fx.dart';
import 'ui.dart';

const gameLevelCount = 6;

int clampLevel(int level) => level.clamp(1, gameLevelCount);

String gameLevelName(int level) => switch (clampLevel(level)) {
      1 => tr('Yangi boshlovchi'),
      2 => tr('Havaskor'),
      3 => tr('Sportchi'),
      4 => tr('Polvon'),
      5 => tr('Alp'),
      _ => tr('Afsona'),
    };

Color gameLevelColor(int level) => switch (clampLevel(level)) {
      1 => AppColors.textMuted,
      2 => AppColors.mint,
      3 => AppColors.sky,
      4 => AppColors.violet,
      5 => AppColors.gold,
      _ => AppColors.coral,
    };

String gameExerciseName(String key) => switch (key) {
      'pushup' => tr('Otjimaniya'),
      'squat' => tr("O'tirib-turish"),
      'lunge' => tr('Vypad'),
      'pullup' => tr('Turnik'),
      'situp' => tr('Press'),
      'shoulder' => tr('Yelka'),
      _ => tr('Boshqa mashq'),
    };

class LevelBadge extends StatelessWidget {
  final int level;
  final double size;
  const LevelBadge({super.key, required this.level, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final color = gameLevelColor(level);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.65)],
        ),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 12)],
      ),
      child: Text(
        '${clampLevel(level)}',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
          fontFeatures: tabular,
        ),
      ),
    );
  }
}

class GameMiniStat extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const GameMiniStat({super.key, required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: AppColors.text, fontFeatures: tabular),
        ),
      ]);
}

class GameLevelCard extends StatelessWidget {
  final AppUser user;
  final Stream<GameMe>? meSource;
  final Future<void> Function(bool enabled)? setEnabled;
  const GameLevelCard({super.key, required this.user, this.meSource, this.setEnabled});

  Future<void> _enable(BuildContext context) async {
    try {
      await (setEnabled?.call(true) ?? Db.setGameEnabled(user.id, true));
    } catch (e) {
      if (context.mounted) showSnack(context, trf("Saqlab bo'lmadi: {0}", [apiErrorText(e)]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (!user.gameEnabled) {
      return BentoTile(
        onTap: () => _enable(context),
        child: Row(children: [
          Icon(Icons.sports_esports_outlined, color: AppColors.violet),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(tr("O'yin rejimini yoqish"), style: t.titleMedium),
          ),
          Icon(Icons.chevron_right, color: AppColors.textFaint),
        ]),
      );
    }
    return StreamBuilder<GameMe>(
      stream: meSource ?? Db.gameMe(),
      builder: (context, snap) {
        final me = snap.data;
        if (me == null) return const SizedBox(height: 96);
        final level = clampLevel(me.level);
        final color = gameLevelColor(level);
        return BentoTile(
          feature: true,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => GameHubScreen(user: user, meSource: Stream.value(me)),
            ),
          ),
          child: Row(children: [
            GlowRing(
              progress: me.levelProgress,
              size: 76,
              stroke: 7,
              color: color,
              child: Text('$level', style: t.titleLarge?.copyWith(fontFeatures: tabular)),
            ),
            const SizedBox(width: AppSpace.lg),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  trf('{0}-daraja', [level]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelMedium?.copyWith(color: color),
                ),
                Text(
                  gameLevelName(level),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  me.nextLevelXp == null
                      ? tr('Eng yuqori daraja')
                      : trf('{0} uchun {1} XP kerak', [gameLevelName(level + 1), me.xpToNext]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpace.sm),
                Wrap(spacing: AppSpace.md, runSpacing: 4, children: [
                  GameMiniStat(icon: Icons.toll_outlined, text: trf('{0} coin', [me.coins]), color: AppColors.gold),
                  GameMiniStat(
                    icon: Icons.local_fire_department_outlined,
                    text: trf('{0} kun ketma-ket', [me.streakDays]),
                    color: AppColors.coral,
                  ),
                ]),
              ]),
            ),
            Icon(Icons.chevron_right, color: AppColors.textFaint),
          ]),
        );
      },
    );
  }
}
