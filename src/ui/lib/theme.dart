import 'package:flutter/material.dart';

class AppColors {
  static bool light = false;

  static Color _c(int dark, int lightValue) => Color(light ? lightValue : dark);
  static Color get bg => _c(0xFF0D0D0F, 0xFFF6F6F8);
  static Color get bgDeep => _c(0xFF070708, 0xFFEDEDF1);
  static Color get card => _c(0xFF17171B, 0xFFFFFFFF);
  static Color get cardHigh => _c(0xFF222228, 0xFFF0F0F4);
  static Color get text => _c(0xFFF5F5F7, 0xFF141418);
  static Color get textMuted => _c(0xFF9A9AA5, 0xFF5C5C68);
  static Color get textFaint => _c(0xFF8F8F9A, 0xFF6C6C78);
  static Color get accent => _c(0xFFFF3B5C, 0xFFC8102E);
  static Color get accentFill => _c(0xFFE11D48, 0xFFC8102E);
  static Color get accentSoft => _c(0xFFFF7A92, 0xFF9F0D25);
  static Color get accentText => _c(0xFFFF3B5C, 0xFFC8102E);
  static Color get onAccent => _c(0xFF14050A, 0xFFFFFFFF);
  static Color get onAccentFill => const Color(0xFFFFFFFF);
  static Color get success => _c(0xFF4ADE80, 0xFF15803D);
  static Color get warning => _c(0xFFFBBF24, 0xFFB45309);
  static Color get danger => _c(0xFFFB7185, 0xFFD3173D);
  static Color get water => _c(0xFF38BDF8, 0xFF0369A1);
  static Color get protein => _c(0xFFA78BFA, 0xFF7C3AED);
  static Color get hairline => _c(0x14FFFFFF, 0x1A141418);
  static Color get hairlineStrong => _c(0x33FFFFFF, 0x4D141418);
  static Color get hairlineSoft => _c(0x0AFFFFFF, 0x0F141418);
  static RadialGradient get glow => RadialGradient(
        center: const Alignment(0, -1.05),
        radius: 1.25,
        colors: light
            ? const [Color(0x14C8102E), Color(0x00F6F6F8), Color(0x00F6F6F8)]
            : const [Color(0x2BFF3B5C), Color(0x00070708), Color(0x00070708)],
        stops: const [0.0, 0.55, 1.0],
      );
  static LinearGradient get headerGradient => LinearGradient(
        colors: [light ? const Color(0xFFFCE8EB) : const Color(0xFF1C1618), bg],
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
  static const sm = 8.0;
  static const md = 10.0;
  static const lg = 12.0;
  static const xl = 16.0;
  static const pill = 999.0;
}

const tabular = [FontFeature.tabularFigures()];
const kTouchTarget = 52.0;

class AppTheme {
  static const radius = AppRadius.md;
  static ThemeData current() => dark();

  static ThemeData dark() {
    final isLight = AppColors.light;
    final s = (isLight ? const ColorScheme.light() : const ColorScheme.dark()).copyWith(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      primaryContainer: isLight ? const Color(0xFFFFD9DF) : const Color(0xFF3A0F18),
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
          fontSize: 20,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
          letterSpacing: -0.3,
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
        hintStyle: TextStyle(color: AppColors.textFaint),
        labelStyle: TextStyle(color: AppColors.textMuted),
        floatingLabelStyle: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
        helperStyle: TextStyle(color: AppColors.textFaint, fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentFill,
          foregroundColor: AppColors.onAccentFill,
          disabledBackgroundColor: AppColors.cardHigh,
          disabledForegroundColor: AppColors.textFaint,
          minimumSize: const Size(64, kTouchTarget + 4),
          shape: RoundedRectangleBorder(borderRadius: r),
          textStyle: const TextStyle(
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
          shape: RoundedRectangleBorder(borderRadius: r),
          textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size(56, kTouchTarget),
          shape: RoundedRectangleBorder(borderRadius: r),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        backgroundColor: AppColors.bgDeep.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppColors.accent.withValues(alpha: 0.14),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (st) => IconThemeData(
            size: 23,
            color: st.contains(WidgetState.selected) ? AppColors.accentText : AppColors.textFaint,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (st) => TextStyle(
            fontSize: 12,
            letterSpacing: 0.1,
            fontWeight: st.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: st.contains(WidgetState.selected) ? AppColors.accentText : AppColors.textFaint,
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
        extendedTextStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      chipTheme: theme.chipTheme.copyWith(
        backgroundColor: AppColors.cardHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        side: BorderSide.none,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: AppColors.text,
        ),
        contentTextStyle: TextStyle(fontSize: 14.5, height: 1.5, color: AppColors.textMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.cardHigh,
        contentTextStyle: TextStyle(color: AppColors.text, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: r),
        iconColor: AppColors.textMuted,
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        subtitleTextStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
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
        textStyle: TextStyle(color: AppColors.text, fontSize: 12),
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static TextTheme _textTheme(TextTheme t) => t
      .copyWith(
        displaySmall: t.displaySmall?.copyWith(
          fontSize: 38,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
          letterSpacing: -1.4,
          height: 1.0,
        ),
        headlineLarge: t.headlineLarge?.copyWith(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
          letterSpacing: -1.0,
          height: 1.1,
        ),
        headlineMedium: t.headlineMedium?.copyWith(
          fontSize: 25,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
          letterSpacing: -0.8,
          height: 1.15,
        ),
        headlineSmall: t.headlineSmall?.copyWith(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        titleLarge: t.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: t.titleMedium?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
        bodyLarge: t.bodyLarge?.copyWith(fontSize: 15, height: 1.5),
        bodyMedium: t.bodyMedium?.copyWith(fontSize: 14, height: 1.55),
        bodySmall: t.bodySmall?.copyWith(fontSize: 12.5, height: 1.4),
        labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.1),
        labelSmall: t.labelSmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      )
      .apply(bodyColor: AppColors.text, displayColor: AppColors.text);
}
