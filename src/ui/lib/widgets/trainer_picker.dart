import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../models/models.dart';
import '../services/api/api_error.dart';
import '../services/db.dart';
import '../theme.dart';
import 'ui.dart';

Future<void> pickTrainer(BuildContext context, AppUser user) async {
  final hasTrainer = user.trainerId != null;
  final all = await Db.trainerDirectory().first;
  final others = all.where((t) => t.id != user.trainerId).toList();
  if (!context.mounted) return;
  if (others.isEmpty) {
    showSnack(
        context,
        hasTrainer
            ? tr("Hozircha shogird qabul qilayotgan boshqa trener yo'q")
            : tr("Hozircha shogird qabul qilayotgan trener yo'q"));
    return;
  }
  final picked = await showSheet<TrainerInfo>(
    context,
    ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: ListView(shrinkWrap: true, children: [
        Text(tr('Trenerni tanlang'), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpace.xs),
        Text(
          tr("Yangi treneringiz rejangiz va chatingizni ko'radi."),
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: AppSpace.md),
        for (final t in others)
          Card(
            child: ListTile(
              minTileHeight: kTouchTarget,
              leading: UserAvatar(name: t.name, size: 40),
              title: Text(t.name),
              subtitle: t.bio.isEmpty ? null : Text(t.bio),
              onTap: () => Navigator.pop(context, t),
            ),
          ),
      ]),
    ),
  );
  if (picked == null || !context.mounted) return;
  final ok = await confirm(
    context,
    title: hasTrainer ? tr('Trener almashtirilsinmi?') : tr('Trener tanlansinmi?'),
    message: hasTrainer
        ? trf('{0} sizning treneringiz bo\'ladi. Oldingi trener sizni endi ko\'rmaydi.',
            [picked.name])
        : trf('{0} sizning treneringiz bo\'ladi.', [picked.name]),
    ok: hasTrainer ? tr('Almashtirish') : tr('Tanlash'),
  );
  if (!ok) return;
  try {
    await Db.chooseTrainer(user.id, picked.id);
    if (context.mounted) showSnack(context, trf('Treneringiz: {0}', [picked.name]));
  } catch (e) {
    if (context.mounted) {
      showSnack(context, trf("Almashtirib bo'lmadi: {0}", [apiErrorText(e)]));
    }
  }
}
