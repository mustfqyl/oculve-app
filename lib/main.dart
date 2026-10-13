import 'dart:io';
import 'dart:ui' as ui;

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

void main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  await _lockPhonesToPortrait();
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
    overrides: [loginLaunchProvider.overrideWithValue(loginLaunch)],
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
          if (loginLaunch) await tray.showWindow();
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

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);

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
      themeMode: switch (themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
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
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(sessionProvider.notifier).restore();
      if (!mounted || !ref.read(loginLaunchProvider)) return;
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
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
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
