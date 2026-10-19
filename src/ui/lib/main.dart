import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsBinding;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/upgrade_screen.dart';
import 'services/api/api_instance.dart';
import 'services/api/poll_stream.dart';
import 'services/settings.dart';
import 'theme.dart';
import 'widgets/ui.dart';
import 'l10n/tr.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  final info = await PackageInfo.fromPlatform();
  apiClient.setAppVersion('${info.version}+${info.buildNumber}');
  await apiClient.restore();
  await AppSettings.init();
  runApp(const ProviderScope(child: App()));
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  String? _look;

  void _rebuildAll() {
    if (!mounted) return;
    void visit(Element e) {
      e.markNeedsBuild();
      e.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // "Telefon sozlamasiga qarab" rejimida telefon temasi almashsa — ilova ham almashadi
  @override
  void didChangePlatformBrightness() => setState(() {});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    pollActivity.value = state == AppLifecycleState.resumed;
  }

  @override
  Widget build(BuildContext context) {
    // til almashganda ham butun ilova qayta quriladi (matnlar tr() orqali olinadi)
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, lang, _) => ValueListenableBuilder<ThemeMode>(
        valueListenable: AppSettings.themeMode,
        builder: (context, mode, _) {
          final platformLight =
              WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.light;
          final light = mode == ThemeMode.light || (mode == ThemeMode.system && platformLight);
          AppColors.light = light;
          final look = '$light-$lang';
          if (_look != null && _look != look) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAll());
          }
          _look = look;
          return MaterialApp(
            title: 'Aura Fit',
            // Tizim oynalari (vaqt tanlash, "Orqaga" va h.k.) ham ilova tilida chiqsin
            locale: Locale(lang),
            supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.current(),
            darkTheme: AppTheme.current(),
            themeMode: light ? ThemeMode.light : ThemeMode.dark,
            builder: (context, child) => _WideScreenFrame(
              child: AppBackdrop(child: UpgradeGate(child: child ?? const SizedBox())),
            ),
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

/// Keng ekranda (web/desktop) ilova telefon kengligida markazda ko'rinadi
class _WideScreenFrame extends StatelessWidget {
  final Widget child;
  const _WideScreenFrame({required this.child});

  static const _maxWidth = 520.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width < 700) return child;
    return ColoredBox(
      color: AppColors.bgDeep,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: MediaQuery(
            data: mq.copyWith(size: Size(_maxWidth, mq.size.height)),
            child: ClipRect(child: child),
          ),
        ),
      ),
    );
  }
}
