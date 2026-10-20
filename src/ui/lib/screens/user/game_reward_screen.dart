import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/game.dart';
import '../../theme.dart';
import '../../widgets/game_fx.dart';
import '../../widgets/game_widgets.dart';
import '../../widgets/hex_badge.dart';
import '../../widgets/ui.dart';

const gameLevelThresholds = [0, 500, 1500, 3500, 7000, 12000];

double rewardProgress(int xp, int level) {
  final index = clampLevel(level) - 1;
  if (index >= gameLevelThresholds.length - 1) return 1;
  final low = gameLevelThresholds[index];
  final high = gameLevelThresholds[index + 1];
  return ((xp - low) / (high - low)).clamp(0.0, 1.0);
}

class GameRewardScreen extends StatelessWidget {
  final GameSessionResult result;
  final String exercise;
  final int reps;
  final bool newRecord;
  const GameRewardScreen({
    super.key,
    required this.result,
    required this.exercise,
    required this.reps,
    this.newRecord = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final level = clampLevel(result.level);
    final color = gameLevelColor(level);
    final challenge = result.flagged ? null : result.challenge;
    final challengeDone = challenge?.completed ?? false;
    final coinsGained =
        result.coins + result.streakBonus + (challengeDone ? challenge!.coins : 0);
    final celebrate =
        !result.flagged && (result.levelUp || newRecord || challengeDone);
    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                result.flagged
                                    ? tr('Sessiya hisoblanmadi')
                                    : tr('Ajoyib mashq!'),
                                textAlign: TextAlign.center,
                                style: t.headlineMedium,
                              ),
                              const SizedBox(height: AppSpace.xs),
                              Text(
                                trf('{0}: {1} takror',
                                    [gameExerciseName(exercise), reps]),
                                textAlign: TextAlign.center,
                                style: t.bodyLarge
                                    ?.copyWith(color: AppColors.textMuted),
                              ),
                              const SizedBox(height: AppSpace.xl),
                              if (result.flagged)
                                BentoTile(
                                  child: Text(
                                    tr("Kamera takrorlarni to'liq ko'rmadi yoki tezlik g'ayrioddiy edi. Coin berilmadi."),
                                    style: t.bodyMedium
                                        ?.copyWith(color: AppColors.textMuted),
                                  ),
                                )
                              else ...[
                                Center(
                                  child: GlowRing(
                                    progress:
                                        rewardProgress(result.totalXp, level),
                                    size: 176,
                                    stroke: 12,
                                    color: color,
                                    ms: 1200,
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(tr('Daraja'),
                                              style: t.labelMedium?.copyWith(
                                                  color: AppColors.textMuted)),
                                          Text('$level',
                                              style: t.displayMedium?.copyWith(
                                                  fontFeatures: tabular)),
                                        ]),
                                  ),
                                ),
                                const SizedBox(height: AppSpace.sm),
                                Text(
                                  gameLevelName(level),
                                  textAlign: TextAlign.center,
                                  style: t.titleLarge,
                                ),
                                const SizedBox(height: AppSpace.xl),
                                Row(children: [
                                  if (coinsGained > 0) ...[
                                    Expanded(
                                      child: _Gain(
                                        icon: Icons.toll_outlined,
                                        color: AppColors.gold,
                                        value: coinsGained,
                                        label: tr('Coin'),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpace.md),
                                  ],
                                  Expanded(
                                    child: _Gain(
                                      icon: Icons.bolt_outlined,
                                      color: AppColors.violet,
                                      value: result.xp,
                                      label: tr('XP'),
                                    ),
                                  ),
                                ]),
                                if (challenge != null) ...[
                                  const SizedBox(height: AppSpace.md),
                                  PopIn(
                                    delayMs: 250,
                                    child: _ChallengeCard(
                                        key: const Key('reward-challenge'),
                                        challenge: challenge),
                                  ),
                                ],
                                if (result.streakBonus > 0) ...[
                                  const SizedBox(height: AppSpace.md),
                                  PopIn(
                                    delayMs: 300,
                                    child: BentoTile(
                                      key: const Key('reward-streak'),
                                      child: Row(children: [
                                        Icon(
                                            Icons
                                                .local_fire_department_outlined,
                                            color: AppColors.coral),
                                        const SizedBox(width: AppSpace.md),
                                        Expanded(
                                          child: Text(
                                            trf(
                                                '{0} kun ketma-ket: +{1} coin',
                                                [
                                                  result.streakDays,
                                                  result.streakBonus
                                                ]),
                                            style: t.titleMedium,
                                          ),
                                        ),
                                      ]),
                                    ),
                                  ),
                                ],
                                if (result.levelUp) ...[
                                  const SizedBox(height: AppSpace.md),
                                  PopIn(
                                    delayMs: 400,
                                    child: BentoTile(
                                      key: const Key('reward-levelup'),
                                      feature: true,
                                      child: Row(children: [
                                        Icon(Icons.emoji_events_outlined,
                                            color: AppColors.gold),
                                        const SizedBox(width: AppSpace.md),
                                        Expanded(
                                          child: Text(
                                            trf('Yangi daraja: {0}',
                                                [gameLevelName(level)]),
                                            style: t.titleMedium,
                                          ),
                                        ),
                                      ]),
                                    ),
                                  ),
                                ],
                                if (newRecord) ...[
                                  const SizedBox(height: AppSpace.md),
                                  PopIn(
                                    delayMs: 500,
                                    child: BentoTile(
                                      key: const Key('reward-record'),
                                      child: Row(children: [
                                        Icon(Icons.military_tech_outlined,
                                            color: AppColors.mint),
                                        const SizedBox(width: AppSpace.md),
                                        Expanded(
                                            child: Text(tr('Yangi rekord!'),
                                                style: t.titleMedium)),
                                      ]),
                                    ),
                                  ),
                                ],
                              ],
                            ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(tr('Davom etish')),
                  ),
                ]),
          ),
          if (celebrate)
            const Positioned.fill(
              child: IgnorePointer(
                child: Align(
                    alignment: Alignment(0, -0.2),
                    child: Burst(radius: 170, ms: 1500)),
              ),
            ),
        ]),
      ),
    );
  }
}

String _muscleName(String muscle) => switch (muscle) {
      'arms' => tr("Qo'llar"),
      'chest' => tr("Ko'krak"),
      _ => tr('Oyoqlar'),
    };

class _ChallengeCard extends StatelessWidget {
  final ChallengeResult challenge;
  const _ChallengeCard({super.key, required this.challenge});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final done = challenge.completed;
    final title = done
        ? trf('{0}-vazifa bajarildi!', [challenge.step])
        : trf('{0}-vazifa', [challenge.step]);
    final subtitle = done
        ? trf('{0} kuchaydi', [_muscleName(challenge.muscle)])
        : trf('{0} / {1}', [challenge.progress, challenge.target]);
    return BentoTile(
      feature: done,
      child: Row(children: [
        HexBadge(exercise: challenge.exercise, done: done, size: 64),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleMedium),
            const SizedBox(height: AppSpace.xs),
            Text(subtitle,
                style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
            if (!done) ...[
              const SizedBox(height: AppSpace.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: LinearProgressIndicator(
                  value: (challenge.progress / challenge.target).clamp(0.0, 1.0),
                  minHeight: 8,
                ),
              ),
            ],
            if (done && challenge.coins > 0) ...[
              const SizedBox(height: AppSpace.xs),
              Text(trf('+{0} coin', [challenge.coins]),
                  style: t.labelLarge?.copyWith(color: AppColors.gold)),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _Gain extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;
  final String label;
  const _Gain(
      {required this.icon,
      required this.color,
      required this.value,
      required this.label});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return BentoTile(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color),
        const SizedBox(height: AppSpace.sm),
        CountUp(
          value.toDouble(),
          style: t.headlineSmall?.copyWith(fontFeatures: tabular),
          suffix: '',
        ),
        Text(label, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
      ]),
    );
  }
}
