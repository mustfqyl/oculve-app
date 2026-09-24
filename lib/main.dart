import 'dart:io';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/desktop/desktop_tray_controller.dart';
import 'core/providers/locale_provider.dart';
import 'core/localization/localized_text.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/providers/theme_provider.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();

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
          await DesktopTrayController(container).initialize();
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

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'Oculve',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: supportedAppLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      scrollBehavior: const AppScrollBehavior(),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: switch (themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
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
    Future.microtask(() => ref.read(sessionProvider.notifier).restore());
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
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error.toString(), textAlign: TextAlign.center),
                    TextButton(
                      onPressed: () =>
                          ref.read(sessionProvider.notifier).restore(),
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await ref.read(apiProvider).clear();
                        await ref.read(sessionProvider.notifier).restore();
                      },
                      child: const Text('Sign in again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        data: (account) =>
            account == null ? const LoginScreen() : const HomeScreen(),
      );
}
