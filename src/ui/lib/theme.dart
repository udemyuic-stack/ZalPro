import 'package:flutter/material.dart';

enum AppPalette { graphite, emerald, amber }

class AppColors {
  static bool light = false;
  static AppPalette palette = AppPalette.graphite;

  static ({Color bg, Color card, Color accent}) swatch(AppPalette p, {required bool isLight}) {
    final savedLight = light;
    final savedPalette = palette;
    light = isLight;
    palette = p;
    final result = (bg: bg, card: card, accent: accent);
    light = savedLight;
    palette = savedPalette;
    return result;
  }

  static bool get _emerald => !light && palette == AppPalette.emerald;
  static bool get _amber => !light && palette == AppPalette.amber;

  static Color _c(int dark, int lightValue) => Color(light ? lightValue : dark);
  static Color _p(int dark, int lightValue, {int? emerald, int? amber}) {
    if (_emerald && emerald != null) return Color(emerald);
    if (_amber && amber != null) return Color(amber);
    return Color(light ? lightValue : dark);
  }

  static Color get bg => _p(0xFF13151F, 0xFFEFF1FA, emerald: 0xFF0A1115, amber: 0xFF120F0C);
  static Color get bgDeep => _p(0xFF0E0F16, 0xFFECECF1, emerald: 0xFF070C0F, amber: 0xFF0C0A08);
  static Color get card => _p(0xFF1B1E2A, 0xFFFFFFFF, emerald: 0xFF121F26, amber: 0xFF1C1712);
  static Color get cardHigh => _p(0xFF262A38, 0xFFF0F0F4, emerald: 0xFF1B2D36, amber: 0xFF2A2319);
  static Color get text => _p(0xFFF5F5F7, 0xFF141418, emerald: 0xFFF0FDF4, amber: 0xFFFFFBEB);
  static Color get textMuted => _p(0xFFA4A4B0, 0xFF5A5A66, emerald: 0xFF9FB8B0, amber: 0xFFBFAE92);
  static Color get textFaint => _p(0xFF9A9AA6, 0xFF666672, emerald: 0xFF8AA39B, amber: 0xFFA8977C);
  static Color get accent => _p(0xFFFF3B5C, 0xFFC8102E, emerald: 0xFF10B981, amber: 0xFFF59E0B);
  static Color get accentFill => _p(0xFFE11D48, 0xFFC8102E, emerald: 0xFF047857, amber: 0xFFD97706);
  static Color get accentSoft => _p(0xFFFF7A92, 0xFF9F0D25, emerald: 0xFF6EE7B7, amber: 0xFFFCD34D);
  static Color get accentText => accent;
  static Color get secondary => _p(0xFF7C8BFF, 0xFF4338CA, emerald: 0xFF38BDF8, amber: 0xFF7C8BFF);
  static Color get accentContainer =>
      _p(0xFF3A0F18, 0xFFFFD9DF, emerald: 0xFF0B3B2B, amber: 0xFF3A2708);
  static Color get onAccent => _p(0xFF14050A, 0xFFFFFFFF, emerald: 0xFF04130D, amber: 0xFF1A1003);
  static Color get onAccentFill => _p(0xFFFFFFFF, 0xFFFFFFFF, amber: 0xFF1A1003);
  static Color get bubbleOwn => accentFill;
  static Color get onBubbleOwn => onAccentFill;
  static Color get success => _c(0xFF4ADE80, 0xFF15803D);
  static Color get successText => _c(0xFF4ADE80, 0xFF166534);
  static Color get warning => _c(0xFFFBBF24, 0xFFB45309);
  static Color get danger => _c(0xFFFB7185, 0xFFD3173D);
  static Color get violet => _c(0xFF9B87FF, 0xFF6D3FE0);
  static Color get sky => _c(0xFF38BDF8, 0xFF0369A1);
  static Color get coral => _p(0xFFFB7185, 0xFFD3173D, emerald: 0xFFFB923C, amber: 0xFFFF8A65);
  static Color get gold => _c(0xFFFBBF24, 0xFFB45309);
  static Color get mint => _c(0xFF34D399, 0xFF047857);
  static Color get water => _c(0xFF38BDF8, 0xFF0369A1);
  static Color get protein => _c(0xFFA78BFA, 0xFF7C3AED);
  static Color get hairline => _c(0x1AFFFFFF, 0x1F141418);
  static Color get hairlineStrong => _c(0x2EFFFFFF, 0x47141418);
  static Color get hairlineSoft => _c(0x0AFFFFFF, 0x0F141418);
  static RadialGradient get glow => RadialGradient(
        center: const Alignment(0, -1.05),
        radius: 1.25,
        colors: light
            ? const [Color(0x14C8102E), Color(0x00F4F4F7), Color(0x00F4F4F7)]
            : [accent.withValues(alpha: 0.17), bgDeep.withValues(alpha: 0), bgDeep.withValues(alpha: 0)],
        stops: const [0.0, 0.55, 1.0],
      );
  static LinearGradient get headerGradient => LinearGradient(
        colors: [
          light
              ? const Color(0xFFFCE8EB)
              : _p(0xFF211A2B, 0, emerald: 0xFF0F2019, amber: 0xFF1F1810),
          bg
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const xxl = 40.0;
}

class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
  static const pill = 999.0;
}

const tabular = [FontFeature.tabularFigures()];
const kTouchTarget = 52.0;
const appFontFamily = 'Inter';

class AppTheme {
  static const radius = AppRadius.md;
  static ThemeData current() => dark();

  static ThemeData dark() {
    final isLight = AppColors.light;
    final s = (isLight ? const ColorScheme.light() : const ColorScheme.dark()).copyWith(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      primaryContainer: AppColors.accentContainer,
      onPrimaryContainer: AppColors.accentSoft,
      secondary: AppColors.water,
      onSecondary: AppColors.onAccent,
      surface: AppColors.card,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.textMuted,
      surfaceContainerHighest: AppColors.cardHigh,
      surfaceContainerHigh: AppColors.cardHigh,
      surfaceContainer: AppColors.card,
      outline: isLight ? const Color(0xFFC9C9D1) : const Color(0xFF34343C),
      outlineVariant: isLight ? const Color(0xFFE0E0E6) : const Color(0xFF26262C),
      error: AppColors.danger,
      onError: AppColors.onAccent,
      inverseSurface: AppColors.text,
      onInverseSurface: AppColors.bg,
    );

    final theme = ThemeData(
      colorScheme: s,
      useMaterial3: true,
      fontFamily: appFontFamily,
      brightness: isLight ? Brightness.light : Brightness.dark,
    );
    final r = BorderRadius.circular(AppRadius.md);

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: r,
          borderSide: BorderSide(color: c, width: w),
        );

    return theme.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: AppColors.bg,
      textTheme: _textTheme(theme.textTheme),
      iconTheme: IconThemeData(color: AppColors.textMuted, size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.text, size: 22),
        titleTextStyle: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: AppColors.text,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.card.withValues(alpha: AppColors.light ? 0.9 : 0.55),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.hairline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md + 2,
          vertical: AppSpace.md + 4,
        ),
        border: border(AppColors.hairlineStrong),
        enabledBorder: border(AppColors.hairlineStrong),
        focusedBorder: border(AppColors.accent, 1.5),
        errorBorder: border(AppColors.danger),
        focusedErrorBorder: border(AppColors.danger, 1.5),
        prefixIconColor: AppColors.textFaint,
        suffixIconColor: AppColors.textFaint,
        hintStyle: TextStyle(fontFamily: appFontFamily, color: AppColors.textFaint),
        labelStyle: TextStyle(fontFamily: appFontFamily, color: AppColors.textMuted),
        floatingLabelStyle: TextStyle(
            fontFamily: appFontFamily, color: AppColors.accent, fontWeight: FontWeight.w600),
        helperStyle: TextStyle(fontFamily: appFontFamily, color: AppColors.textFaint, fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentFill,
          foregroundColor: AppColors.onAccentFill,
          disabledBackgroundColor: AppColors.cardHigh,
          disabledForegroundColor: AppColors.textFaint,
          minimumSize: const Size(64, kTouchTarget),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: appFontFamily,
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          minimumSize: const Size(64, kTouchTarget),
          side: BorderSide(color: AppColors.hairlineStrong),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
              fontFamily: appFontFamily, fontSize: 15.5, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size(56, kTouchTarget),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontFamily: appFontFamily, fontWeight: FontWeight.w600),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: _RisePageTransitions(),
        TargetPlatform.iOS: _RisePageTransitions(),
        TargetPlatform.linux: _RisePageTransitions(),
        TargetPlatform.macOS: _RisePageTransitions(),
        TargetPlatform.windows: _RisePageTransitions(),
        TargetPlatform.fuchsia: _RisePageTransitions(),
      }),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        backgroundColor: AppColors.bgDeep.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppColors.accent.withValues(alpha: 0.14),
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith(
          (st) => IconThemeData(
            size: 23,
            color: st.contains(WidgetState.selected) ? AppColors.accentText : AppColors.textMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (st) => TextStyle(
            fontFamily: appFontFamily,
            fontSize: 12,
            letterSpacing: 0.1,
            fontWeight: st.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: st.contains(WidgetState.selected) ? AppColors.accentText : AppColors.textMuted,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        backgroundColor: AppColors.accentFill,
        foregroundColor: AppColors.onAccentFill,
        extendedTextStyle:
            const TextStyle(fontFamily: appFontFamily, fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      chipTheme: theme.chipTheme.copyWith(
        backgroundColor: AppColors.cardHigh,
        selectedColor: AppColors.accent.withValues(alpha: 0.18),
        checkmarkColor: AppColors.accentText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 19),
        labelStyle: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        titleTextStyle: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: AppColors.text,
        ),
        contentTextStyle: TextStyle(
            fontFamily: appFontFamily, fontSize: 14.5, height: 1.5, color: AppColors.textMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.cardHigh,
        showCloseIcon: true,
        closeIconColor: AppColors.textMuted,
        contentTextStyle: TextStyle(
            fontFamily: appFontFamily,
            color: AppColors.text,
            fontSize: 14.5,
            fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, kTouchTarget)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (st) => st.contains(WidgetState.selected) ? AppColors.accentFill : null,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (st) =>
                st.contains(WidgetState.selected) ? AppColors.onAccentFill : AppColors.textMuted,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: r),
        iconColor: AppColors.textMuted,
        titleTextStyle: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        subtitleTextStyle:
            TextStyle(fontFamily: appFontFamily, fontSize: 13, color: AppColors.textMuted),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.hairlineSoft,
        space: 1,
        thickness: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: AppColors.textFaint,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.accent,
        circularTrackColor: AppColors.cardHigh,
        linearTrackColor: AppColors.cardHigh,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.cardHigh,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: TextStyle(fontFamily: appFontFamily, color: AppColors.text, fontSize: 12),
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static TextTheme _textTheme(TextTheme t) => t
      .copyWith(
        displaySmall: t.displaySmall?.copyWith(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          height: 1.1,
        ),
        headlineLarge: t.headlineLarge?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          height: 1.15,
        ),
        headlineMedium: t.headlineMedium?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        headlineSmall: t.headlineSmall?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          height: 1.25,
        ),
        titleLarge: t.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleMedium: t.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        titleSmall: t.titleSmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        bodyLarge: t.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
        bodyMedium: t.bodyMedium?.copyWith(fontSize: 14.5, height: 1.5),
        bodySmall: t.bodySmall?.copyWith(fontSize: 13, height: 1.4),
        labelLarge:
            t.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0),
        labelMedium: t.labelMedium?.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600),
        labelSmall: t.labelSmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      )
      .apply(
        fontFamily: appFontFamily,
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      );
}

class _RisePageTransitions extends PageTransitionsBuilder {
  const _RisePageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final out = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(curve),
        child: ScaleTransition(
          scale: Tween(begin: 1.0, end: 0.97).animate(out),
          child: child,
        ),
      ),
    );
  }
}
