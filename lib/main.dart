import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vless/flutter_vless.dart';
import 'package:window_manager/window_manager.dart';

import 'core/desktop/desktop_tray_controller.dart';
import 'core/desktop/startup_service.dart';
import 'core/providers/vpn_provider.dart';
import 'core/navigation/app_navigator.dart';
import 'core/providers/locale_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/widgets/app_feedback.dart';
import 'core/providers/theme_provider.dart';
import 'core/vpn/linux_platform.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/signup_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/settings/providers/statistics_provider.dart';
import 'features/splash/presentation/loading_screen.dart';

void main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  final initialThemeMode = await ThemeNotifier.loadInitialMode();
  if (Platform.isLinux) VlessPlatform.instance = LinuxXrayPlatform();
  var loginLaunch = false;
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    try {
      loginLaunch = await DesktopStartupBackend().launchedAtLogin(arguments);
    } catch (_) {
      /* Manual launch remains available. */
    }
  }
  final container = ProviderContainer(
    overrides: [
      loginLaunchProvider.overrideWithValue(loginLaunch),
      themeProvider.overrideWith(
        (ref) => ThemeNotifier(
          initialMode: initialThemeMode,
          restorePreferences: false,
        ),
      ),
    ],
  );

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    final trayPlatform =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    final windowOptions = WindowOptions(
      size: desktopWindowSize,
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: trayPlatform,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: !Platform.isMacOS,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (trayPlatform) {
        try {
          final tray = DesktopTrayController(container);
          await tray.initialize();
          if (shouldShowDesktopWindowAtLaunch(
            loginLaunch: loginLaunch,
            platform: defaultTargetPlatform,
          )) {
            await tray.showWindow();
          }
          return;
        } catch (_) {
          // Leave the UI reachable if tray creation fails on this machine.
          await windowManager.setSkipTaskbar(false);
        }
      }
      await windowManager.setResizable(false);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
  // Orientation is a platform-channel round trip. Let Flutter paint its first
  // frame while the OS applies the phone-only portrait preference.
  unawaited(_lockPhonesToPortrait().catchError((Object _) {}));
}

Future<void> _lockPhonesToPortrait() async {
  if (!Platform.isAndroid && !Platform.isIOS) return;

  final views = ui.PlatformDispatcher.instance.views;
  if (views.isEmpty) return;

  final view = views.first;
  if (view.physicalSize.isEmpty || view.devicePixelRatio <= 0) return;
  final shortestSide = view.physicalSize.shortestSide / view.devicePixelRatio;
  if (shortestSide >= 600) return;

  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final Timer _themeClock;

  @override
  void initState() {
    super.initState();
    _themeClock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && ref.read(themeProvider) == AppThemeMode.auto) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _themeClock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);
    final resolvedThemeMode = resolveThemeMode(themeMode, DateTime.now());

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      navigatorObservers: [appFeedbackNavigatorObserver],
      title: 'Oculve',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: supportedAppLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      scrollBehavior: const AppScrollBehavior().copyWith(scrollbars: false),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: resolvedThemeMode == AppThemeMode.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      builder: (context, child) {
        final systemDisablesAnimations = MediaQuery.disableAnimationsOf(
          context,
        );
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: systemDisablesAnimations),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SessionGate(),
    );
  }
}

class SessionGate extends ConsumerStatefulWidget {
  const SessionGate({super.key});
  @override
  ConsumerState<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends ConsumerState<SessionGate> {
  bool _statisticsSessionActive = false;

  void _syncStatisticsPrefetch(bool authenticated) {
    if (!authenticated) {
      if (_statisticsSessionActive) {
        _statisticsSessionActive = false;
        ref.invalidate(statisticsProvider);
      }
      return;
    }
    if (_statisticsSessionActive) return;
    _statisticsSessionActive = true;
    ref.invalidate(statisticsProvider);
    unawaited(_prefetchStatistics());
  }

  Future<void> _prefetchStatistics() async {
    try {
      await ref.read(statisticsProvider.future);
    } catch (_) {
      // Keep the provider error available so Statistics can show its retry.
    }
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(sessionProvider, (previous, next) {
      _syncStatisticsPrefetch(next.valueOrNull != null);
    });
    Future.microtask(() async {
      await ref.read(sessionProvider.notifier).restore();
      if (!mounted) return;
      _syncStatisticsPrefetch(ref.read(sessionProvider).valueOrNull != null);
      if (!ref.read(loginLaunchProvider)) return;
      try {
        await ref
            .read(startupServiceProvider)
            .connectAfterRestore(
              loginLaunch: true,
              hasAccount: ref.read(sessionProvider).valueOrNull != null,
              connect: () => ref.read(vpnProvider.notifier).connect(),
            );
      } catch (error) {
        if (mounted) {
          AppFeedback.showError(
            context,
            error,
            fallback: 'Could not connect at startup.',
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(sessionProvider)
      .when(
        loading: () => const LoadingScreen(),
        error: (error, _) => Scaffold(
          body: PremiumBackground(
            child: Center(
              child: AppErrorState(
                title: 'Unable to load your account',
                message: AppFeedback.errorMessage(error),
                primaryLabel: 'Retry',
                onPrimary: () => ref.read(sessionProvider.notifier).restore(),
                secondaryLabel: 'Sign in again',
                onSecondary: () async {
                  await ref.read(apiProvider).clear();
                  await ref.read(sessionProvider.notifier).restore();
                },
              ),
            ),
          ),
        ),
        data: (account) =>
            account == null ? const SignUpScreen() : const HomeScreen(),
      );
}
