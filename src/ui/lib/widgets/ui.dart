import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../theme.dart';

const _weekdays = [
  'Dushanba',
  'Seshanba',
  'Chorshanba',
  'Payshanba',
  'Juma',
  'Shanba',
  'Yakshanba'
];
const _months = [
  'yanvar',
  'fevral',
  'mart',
  'aprel',
  'may',
  'iyun',
  'iyul',
  'avgust',
  'sentyabr',
  'oktyabr',
  'noyabr',
  'dekabr',
];

String microLabel(String text) => text;

String uzDate(DateTime d) =>
    trf('{0}, {1}-{2}', [tr(_weekdays[d.weekday - 1]), d.day, tr(_months[d.month - 1])]);

String fmtNum(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

String fmtPhone(String digits) {
  final d = digits.replaceAll(RegExp(r'\D'), '');
  if (d.length != 12 || !d.startsWith('998')) return d.isEmpty ? '' : '+$d';
  return '+998 ${d.substring(3, 5)} ${d.substring(5, 8)} ${d.substring(8, 10)} ${d.substring(10)}';
}

String userContact(String phone, String email) => phone.isNotEmpty ? fmtPhone(phone) : email;

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

Color avatarColor(String seed) {
  final palette = [
    AppColors.accent,
    AppColors.water,
    AppColors.protein,
    AppColors.success,
    AppColors.warning,
    Color(AppColors.light ? 0xFF4F46E5 : 0xFF818CF8),
    Color(AppColors.light ? 0xFF0F766E : 0xFF2DD4BF),
    Color(AppColors.light ? 0xFFA21CAF : 0xFFF0ABFC),
  ];
  return palette[seed.hashCode.abs() % palette.length];
}

class AppBackdrop extends StatelessWidget {
  final Widget child;
  const AppBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: AppColors.bg),
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.glow),
          child: child,
        ),
      );
}

void showSnack(BuildContext context, String message) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message)));

Duration motion(BuildContext context, int ms) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false
        ? Duration.zero
        : Duration(milliseconds: ms);

Future<T?> showSheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
            child: child,
          ),
        ),
      ),
    );

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String? ok,
  bool destructive = false,
}) async {
  final r = await showSheet<bool>(
    context,
    Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpace.sm),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpace.xl),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: AppColors.onAccent,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(ok ?? tr('Ha')),
          ),
          const SizedBox(height: AppSpace.sm),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(ok == tr('Bekor qilish') ? tr('Orqaga') : tr('Bekor qilish')),
          ),
        ]),
  );
  return r ?? false;
}

class FadeInUp extends StatelessWidget {
  final Widget child;
  final int index;
  const FadeInUp({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: motion(context, 240 + index * 40),
        curve: Curves.easeOutCubic,
        builder: (context, v, c) => Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: c),
        ),
        child: child,
      );
}

class CountUp extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final String suffix;
  final int decimals;
  const CountUp(this.value, {super.key, this.style, this.suffix = '', this.decimals = 0});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: motion(context, 450),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Text(
          '${v.toStringAsFixed(decimals)}$suffix',
          style: (style ?? const TextStyle()).copyWith(fontFeatures: tabular),
        ),
      );
}

class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  const Eyebrow(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Text(
        microLabel(text),
        style:
            Theme.of(context).textTheme.labelSmall?.copyWith(color: color ?? AppColors.textFaint),
      );
}

class Heading extends StatelessWidget {
  final String text;
  final String? accent;
  final TextStyle? style;
  const Heading(this.text, {super.key, this.accent, this.style});

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.headlineSmall!;
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: text),
        if (accent != null) ...[
          const TextSpan(text: ' '),
          TextSpan(text: accent!, style: TextStyle(color: AppColors.accentText)),
        ],
      ]),
      style: base,
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final Widget? trailing;
  const SectionHeader(this.title, {super.key, this.eyebrow, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, AppSpace.sm, 2, AppSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (eyebrow != null) ...[Eyebrow(eyebrow!), const SizedBox(height: AppSpace.xs)],
              Heading(title, style: t.titleLarge),
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: AppSpace.sm),
        Container(height: 1, color: AppColors.hairline),
      ]),
    );
  }
}

class SubHeader extends StatelessWidget {
  final String title;
  final int? count;
  final Color? color;
  const SubHeader(this.title, {super.key, this.count, this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, AppSpace.xs, 2, AppSpace.sm),
      child: Row(children: [
        Container(
          width: 3,
          height: 16,
          margin: const EdgeInsets.only(right: AppSpace.sm),
          decoration: BoxDecoration(
            color: color ?? AppColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(child: Text(title, style: t.titleSmall)),
        if (count != null) Text('$count', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
      ]),
    );
  }
}

class BentoTile extends StatelessWidget {
  final Widget child;
  final bool feature;
  final bool blur;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const BentoTile({
    super.key,
    required this.child,
    this.feature = false,
    this.blur = false,
    this.color,
    this.padding = const EdgeInsets.all(AppSpace.md + 2),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    final fill = color ??
        (feature
            ? Color.alphaBlend(AppColors.accent.withValues(alpha: 0.08), AppColors.card)
            : AppColors.card.withValues(alpha: AppColors.light ? 0.9 : 0.92));
    final edge = feature ? AppColors.accent.withValues(alpha: 0.4) : AppColors.hairline;

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: edge),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(Colors.white.withValues(alpha: AppColors.light ? 0.0 : 0.02), fill),
            fill,
          ],
          stops: const [0.0, 0.35],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: onTap == null ? 0 : kTouchTarget),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );

    if (blur) {
      content = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: content,
      );
    }
    return ClipRRect(borderRadius: radius, child: content);
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyState(
      {super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: FadeInUp(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.card.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Icon(icon, size: 30, color: AppColors.textFaint),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(title, textAlign: TextAlign.center, style: t.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpace.sm),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
            ],
            if (action != null) ...[const SizedBox(height: AppSpace.xl), action!],
          ]),
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final Object? error;
  final VoidCallback? onRetry;
  final bool compact;
  const ErrorState({super.key, this.error, this.onRetry, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (error != null) debugPrint('ErrorState: $error');
    if (compact) {
      return BentoTile(
        padding: const EdgeInsets.all(AppSpace.md),
        onTap: onRetry,
        child: Row(children: [
          Icon(Icons.error_outline, size: 20, color: AppColors.textMuted),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              tr("Ma'lumot olinmadi"),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ),
          if (onRetry != null) Icon(Icons.refresh, size: 20, color: AppColors.accentText),
        ]),
      );
    }
    return EmptyState(
      icon: Icons.error_outline,
      title: tr("Ma'lumot olinmadi"),
      subtitle: tr('Internet aloqasini tekshiring'),
      action: onRetry == null
          ? null
          : OutlinedButton(onPressed: onRetry, child: Text(tr('Qayta urinish'))),
    );
  }
}

class UserAvatar extends StatelessWidget {
  final String name;
  final double size;
  const UserAvatar({super.key, required this.name, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final c = avatarColor(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.withValues(alpha: 0.28)),
      ),
      child: Text(
        initials(name),
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.33,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconBadge(this.icon, {super.key, required this.color, this.size = 40});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Icon(icon, color: color, size: size * 0.46),
      );
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final bool solid;
  final Color? textColor;
  const Pill({
    super.key,
    required this.text,
    required this.color,
    this.icon,
    this.solid = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final fg = solid ? AppColors.onAccent : (textColor ?? color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm + 2, vertical: 5),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: solid ? null : Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 5)],
        Text(
          text,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFeatures: tabular,
          ),
        ),
      ]),
    );
  }
}

class StepButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool tonal;
  const StepButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tonal = false,
  });

  @override
  Widget build(BuildContext context) {
    const size = BoxConstraints(minWidth: kTouchTarget, minHeight: kTouchTarget);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: tonal
          ? IconButton.filledTonal(onPressed: onPressed, icon: Icon(icon), constraints: size)
          : IconButton(onPressed: onPressed, icon: Icon(icon), constraints: size),
    );
  }
}

class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      label: trf('{0}: {1}', [label, value]),
      excludeSemantics: true,
      child: BentoTile(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: AppSpace.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              microLabel(label),
              maxLines: 1,
              softWrap: false,
              style: t.labelSmall?.copyWith(color: AppColors.textFaint, fontSize: 12),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: t.headlineSmall?.copyWith(fontFeatures: tabular)),
          ),
        ]),
      ),
    );
  }
}

class KcalRing extends StatelessWidget {
  final double value, total, size;
  final Color? color, trackColor, textColor;
  const KcalRing({
    super.key,
    required this.value,
    required this.total,
    this.size = 120,
    this.color,
    this.trackColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = total > 0 ? (value / total).clamp(0.0, 1.0) : 0.0;
    final fg = textColor ?? AppColors.text;
    return SizedBox.square(
      dimension: size,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: p),
            duration: motion(context, 600),
            curve: Curves.easeOutCubic,
            builder: (context, v, child) => CircularProgressIndicator(
              value: v,
              strokeWidth: size * 0.055,
              strokeCap: StrokeCap.round,
              color: color ?? AppColors.accent,
              backgroundColor: trackColor ?? AppColors.cardHigh,
            ),
          ),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          CountUp(value, style: t.headlineMedium?.copyWith(color: fg)),
          const SizedBox(height: 2),
          Text(
            '/ ${trf('{0} kkal', [total.round()])}',
            style: t.labelSmall?.copyWith(color: AppColors.textFaint, fontFeatures: tabular),
          ),
        ]),
      ]),
    );
  }
}

class GradientHeader extends StatelessWidget {
  final Widget child;
  const GradientHeader({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.headerGradient,
          border: Border(bottom: BorderSide(color: AppColors.hairline)),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
        ),
        child: SafeArea(bottom: false, child: child),
      );
}

class AuraLogo extends StatelessWidget {
  final double size;
  final bool stacked;
  const AuraLogo({super.key, this.size = 28, this.stacked = false});

  @override
  Widget build(BuildContext context) {
    final mark = Icon(Icons.change_history_outlined, size: size, color: AppColors.accent);
    final word = Text.rich(
      TextSpan(children: [
        const TextSpan(text: 'AURA'),
        TextSpan(text: ' FIT', style: TextStyle(color: AppColors.accentText)),
      ]),
      style: TextStyle(
        color: AppColors.text,
        fontSize: size * 0.55,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
    return Semantics(
      label: 'Aura Fit',
      child: stacked
          ? Column(mainAxisSize: MainAxisSize.min, children: [
              mark,
              SizedBox(height: size * 0.25),
              word,
            ])
          : Row(mainAxisSize: MainAxisSize.min, children: [
              mark,
              SizedBox(width: size * 0.3),
              word,
            ]),
    );
  }
}

class AppSegment<T> {
  final T value;
  final String label;
  final IconData? icon;
  const AppSegment({required this.value, required this.label, this.icon});
}

class AppSegmented<T> extends StatelessWidget {
  final List<AppSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  const AppSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: kTouchTarget),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.hairlineStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(children: [
        for (final seg in segments)
          Expanded(
            child: Semantics(
              button: true,
              selected: seg.value == selected,
              label: seg.label,
              excludeSemantics: true,
              child: Material(
                color: seg.value == selected ? AppColors.accentFill : Colors.transparent,
                child: InkWell(
                  onTap: () => onChanged(seg.value),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: kTouchTarget),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        if (seg.icon != null) ...[
                          Icon(
                            seg.icon,
                            size: 18,
                            color: seg.value == selected
                                ? AppColors.onAccentFill
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: AppSpace.xs),
                        ],
                        Flexible(
                          child: Text(
                            seg.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.labelLarge?.copyWith(
                              color: seg.value == selected
                                  ? AppColors.onAccentFill
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
