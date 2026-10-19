import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../theme.dart';
import '../../widgets/trainer_picker.dart';
import '../../widgets/ui.dart';
import 'chat_screen.dart';

class TrainerTab extends StatelessWidget {
  final AppUser user;
  final Future<void> Function(BuildContext context, AppUser user) onPick;
  final Stream<TrainerInfo?> Function(String uid)? trainerSource;
  final Widget Function(String title)? chatBuilder;
  const TrainerTab({
    super.key,
    required this.user,
    this.onPick = pickTrainer,
    this.trainerSource,
    this.chatBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (user.trainerId != null) {
      final id = user.trainerId!;
      return StreamBuilder<TrainerInfo?>(
        stream: (trainerSource ?? Db.trainerProfile)(id),
        builder: (context, snap) {
          final name = snap.data?.name.trim() ?? '';
          final title = name.isEmpty ? tr('Trener') : name;
          return chatBuilder?.call(title) ??
              ChatScreen(
                chatUid: user.id,
                myId: user.id,
                title: title,
                subtitle: tr('Savollaringizga javob beradi'),
              );
        },
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(tr('Trener tanlanmagan'))),
      body: EmptyState(
        icon: Icons.support_agent_outlined,
        title: tr('Trener tanlang'),
        subtitle: tr("Trener sizga ovqatlanish rejasi tuzadi va savollaringizga javob beradi."),
        action: FilledButton.icon(
          key: const Key('choose-trainer'),
          onPressed: () => onPick(context, user),
          style: FilledButton.styleFrom(minimumSize: const Size(0, kTouchTarget)),
          icon: const Icon(Icons.badge_outlined),
          label: Text(tr('Trener tanlang')),
        ),
      ),
    );
  }
}
