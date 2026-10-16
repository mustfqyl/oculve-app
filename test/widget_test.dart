import 'dart:async';
import 'package:oculve/main.dart';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oculve/features/auth/presentation/login_screen.dart';
import 'package:oculve/features/auth/presentation/signup_screen.dart';
import 'package:oculve/features/home/presentation/home_screen.dart';
import 'package:oculve/core/widgets/oculve_wordmark.dart';
import 'package:oculve/features/home/presentation/server_selection_screen.dart';
import 'package:oculve/features/settings/presentation/account_screen.dart';
import 'package:oculve/features/settings/presentation/android_app_routing_screen.dart';
import 'package:oculve/features/settings/presentation/client_logs_screen.dart';
import 'package:oculve/features/settings/presentation/settings_screen.dart';
import 'package:oculve/features/settings/presentation/usage_statistics_screen.dart';
import 'package:oculve/features/settings/presentation/tray_preferences_screen.dart';
import 'package:oculve/features/settings/presentation/xray_core_settings_screen.dart';
import 'package:oculve/core/vpn/xray_preferences.dart';
import 'package:oculve/core/vpn/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/theme/app_scroll_behavior.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:oculve/core/navigation/app_navigator.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'profile_test.dart' show testLink;

class _AccountSession extends SessionController {
  int refreshCount = 0;
  _AccountSession() : super(OculveApi()) {
    state = AsyncValue.data(
      Account({
        'authCode': 'ABCD-EFGH-IJKL',
        'status': 'active',
        'plan': 'Premium',
        'createdAt': '2026-09-22T12:00:00.000Z',
        'expiresAt': '2026-10-22T12:00:00.000Z',
        'usage': {'usedGB': 2.5, 'limitGB': 50},
        'security': {
          'totpEnabled': true,
          'totpConfigured': true,
          'passkeys': [
            {
              'credentialId': 'test-id',
              'label': 'My laptop',
              'enabled': true,
              'createdAt': '2026-09-22T12:00:00.000Z',
            },
          ],
        },
      }, const []),
    );
  }

  @override
  Future<void> refreshAccount() async {
    refreshCount++;
  }
}

class _TotpSetupApi extends OculveApi {
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String? method,
    Map<String, String>? headers,
  }) async {
    if (path == '/api/user/security/totp/setup') {
      return {
        'manualEntryKey': 'JBSWY3DPEHPK3PXP',
        'setupToken': 'test-setup-token',
        'qrDataUrl': '',
      };
    }
    return {};
  }
}

class _UnconfiguredTotpSession extends _AccountSession {
  _UnconfiguredTotpSession() {
    final data = Map<String, dynamic>.from(state.valueOrNull!.data)
      ..['security'] = <String, dynamic>{};
    state = AsyncValue.data(Account(data, const []));
  }
}

class _SignupSession extends SessionController {
  _SignupSession() : super(OculveApi());

  @override
  Future<String> generateRegistrationCode() async => 'ABCD-EFGH-IJKL';
}

class _OnboardingSession extends _SignupSession {
  int codeRequests = 0;
  int registrations = 0;
  @override
  Future<void> restore() async {
    state = const AsyncValue.data(null);
  }

  @override
  Future<String> generateRegistrationCode() async {
    codeRequests++;
    return super.generateRegistrationCode();
  }

  @override
  Future<void> register(String code) async {
    registrations++;
    state = AsyncValue.data(Account({'status': 'active'}, const []));
  }
}

class _DeferredSignupSession extends _OnboardingSession {
  final pendingCode = Completer<String>();

  @override
  Future<String> generateRegistrationCode() {
    codeRequests++;
    return pendingCode.future;
  }
}

class _LoginFlowSession extends _OnboardingSession {
  String? submittedCode;

  @override
  Future<void> login(String code, {String? challenge}) async {
    submittedCode = code;
    state = AsyncValue.data(
      Account({'authCode': code, 'status': 'active'}, const []),
    );
  }
}

class _TwoFactorSession extends _OnboardingSession {
  @override
  Future<void> login(String code, {String? challenge}) async {
    if (challenge == null) {
      throw const SecondFactorRequired(
        'test-challenge',
        totp: true,
        passkey: false,
      );
    }
  }
}

class _VlessSession extends SessionController {
  _VlessSession(VpnProfile profile) : super(OculveApi()) {
    state = AsyncValue.data(Account({'status': 'active'}, [profile]));
  }
}

void main() {
  testWidgets('two-factor code supports platform one-time-code autofill', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) => _TwoFactorSession())],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const LoginScreen(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'ABCD-EFGH-IJKL');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final codeField = tester.widget<TextField>(find.byType(TextField).first);
    expect(codeField.autofillHints, [AutofillHints.oneTimeCode]);
    expect(codeField.decoration?.hintText, 'VERIFICATION CODE');
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign in returns to the session gate after a valid code', (
    tester,
  ) async {
    final session = _LoginFlowSession();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) => session)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const SessionGate(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('welcome-sign-in')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'ABCD-EFGH-IJKL');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 250));

    expect(session.submittedCode, 'ABCD-EFGH-IJKL');
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('welcome only requests a code after choosing create account', (
    tester,
  ) async {
    final session = _OnboardingSession();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => session),
          accessCodeSaverProvider.overrideWithValue(
            (context, code) async => true,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const SessionGate(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SignUpScreen), findsOneWidget);
    expect(session.codeRequests, 0);
    expect(find.text('1 / 3'), findsNothing);
    expect(find.text('Already have an account?'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byKey(const ValueKey('signup-step-0-action')), findsOneWidget);
    expect(find.text('Get my access code'), findsNothing);
    await tester.tap(find.text('Continue setup'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Your sign-in key'), findsOneWidget);
    expect(session.codeRequests, 1);
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Ready to create your account?'), findsOneWidget);
    expect(find.text('Access code saved to this device'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(session.registrations, 0);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Create account'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Create account'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(session.registrations, 1);
    expect(find.byType(HomeScreen), findsOneWidget);
    session.clearLocalSession();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SignUpScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registration code scrambles while loading, then reveals code', (
    tester,
  ) async {
    final session = _DeferredSignupSession();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => session),
          accessCodeSaverProvider.overrideWithValue(
            (context, code) async => true,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const SignUpScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Continue setup'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 800));

    final scramble = find.byKey(const ValueKey('signup-code-scramble'));
    expect(scramble, findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    String displayedCode() => tester
        .widget<Text>(
          find.descendant(of: scramble, matching: find.byType(Text)),
        )
        .data!;
    final initial = displayedCode();
    await tester.pump(const Duration(milliseconds: 110));
    expect(displayedCode(), isNot(initial));

    session.pendingCode.complete('ABCD-EFGH-IJKL');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('ABCD-EFGH-IJKL'), findsOneWidget);
    expect(find.byKey(const ValueKey('signup-code-scramble')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing-account path opens sign in without generating a code', (
    tester,
  ) async {
    final session = _OnboardingSession();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) => session)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const SessionGate(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('welcome-sign-in')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(session.codeRequests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop popup overlays never show scrollbars', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        scrollBehavior: const AppScrollBehavior().copyWith(scrollbars: false),
        home: Scaffold(
          body: Center(
            child: PopupMenuButton<int>(
              itemBuilder: (context) => List.generate(
                30,
                (index) =>
                    PopupMenuItem(value: index, child: Text('Item $index')),
              ),
              child: const Text('Open menu'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate((widget) => widget is RawScrollbar),
      findsNothing,
    );
    expect(find.byType(Scrollbar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings place theme options above language', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.getTopLeft(find.text('Auto')).dy,
      lessThan(tester.getTopLeft(find.text('Language')).dy),
    );
  });

  testWidgets('home wordmark uses the website system type at header size', (
    tester,
  ) async {
    for (final (theme, color) in [
      (AppTheme.darkTheme, AppTheme.foreground),
      (AppTheme.lightTheme, AppTheme.lightForeground),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Row(children: [OculveWordmark(color: color)]),
          ),
        ),
      );
      final mark = find.byType(OculveWordmark);
      expect(
        tester.getSize(mark).width,
        tester.getSize(find.text('oculve')).width,
      );
      final wordmark = tester.widget<Text>(find.text('oculve'));
      expect(wordmark.style?.color, color);
      expect(wordmark.style?.fontSize, 22.8);
    }
  });

  testWidgets(
    'account shows real fields in a compact window and keeps access code hidden',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = _AccountSession();
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? copiedCode;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedCode = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionProvider.overrideWith((ref) => session)],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const AccountScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(session.refreshCount, 1);
      expect(tester.takeException(), isNull);
      expect(find.text('ABCD-EFGH-IJKL'), findsNothing);
      expect(find.text('••••••••••'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('account-code-visibility')),
        findsOneWidget,
      );
      expect(find.text('SUBSCRIPTION'), findsNothing);
      expect(find.text('Created on'), findsOneWidget);
      expect(find.text('09/22/2026'), findsOneWidget);
      expect(find.text('10/22/2026'), findsNothing);
      final codeButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('account-code-visibility')),
      );
      expect(codeButton.tooltip, isNull);
      expect(
        codeButton.style!.overlayColor!.resolve({WidgetState.hovered}),
        Colors.white.withValues(alpha: .055),
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('account-code-copy')))
            .tooltip,
        isNull,
      );
      expect(find.text('Manage subscription'), findsNothing);
      expect(find.byType(Scrollable), findsOneWidget);
      expect(
        tester.getCenter(find.text('Log out')).dy,
        lessThan(tester.getCenter(find.text('Delete account')).dy),
      );
      await tester.tap(find.byKey(const ValueKey('account-code-visibility')));
      await tester.pump();
      expect(find.text('ABCD-EFGH-IJKL'), findsOneWidget);
      expect(copiedCode, isNull);
      await tester.tap(find.byKey(const ValueKey('account-code-copy')));
      await tester.pump();
      expect(copiedCode, 'ABCD-EFGH-IJKL');
      await tester.tap(find.byKey(const ValueKey('account-code-visibility')));
      await tester.pump();
      expect(find.text('ABCD-EFGH-IJKL'), findsNothing);
      await tester.tap(find.text('Security'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('2FA / TOTP'), findsOneWidget);
      expect(find.text('Passkeys'), findsOneWidget);
      expect(find.text('Add passkey on website'), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      expect(session.refreshCount, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump(const Duration(seconds: 30));
      expect(session.refreshCount, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(session.refreshCount, 3);
    },
  );
  testWidgets('TOTP setup fits the compact app window in the app theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => _UnconfiguredTotpSession()),
          apiProvider.overrideWithValue(_TotpSetupApi()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const AccountScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Security'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('2FA / TOTP'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Set up authenticator'), findsOneWidget);
    expect(find.text('MANUAL SETUP KEY'), findsOneWidget);
    expect(find.text('JBSWY3DPEHPK3PXP'), findsOneWidget);
    expect(tester.getSize(find.byType(Dialog)).width, lessThanOrEqualTo(320));
    expect(tester.getSize(find.byType(Dialog)).width, greaterThan(280));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
  });
  testWidgets('sign-in gives the access code field a localized hint', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: const LoginScreen(), theme: ThemeData.light()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    final accessCodeField = tester.widget<TextField>(find.byType(TextField));
    expect(accessCodeField.decoration?.hintText, 'ACCESS CODE');
    expect(accessCodeField.decoration?.hintStyle?.color, Colors.transparent);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('CONNECTED'), findsNothing);
  });
  testWidgets('sign-up follows the website account setup layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => _SignupSession()),
          accessCodeSaverProvider.overrideWithValue(
            (context, code) async => true,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const SignUpScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Your private connection starts here.'), findsOneWidget);
    expect(find.byType(OculveWordmark), findsOneWidget);
    expect(tester.widget<Text>(find.text('oculve')).style?.fontSize, 22.8);
    expect(
      find.text(
        'Set up your access key, save it somewhere safe, then choose a location for your first private connection.',
      ),
      findsOneWidget,
    );
    expect(find.text('1 / 3'), findsNothing);
    expect(find.text('No email or password required.'), findsNothing);
    expect(find.text('YOUR ACCESS CODE'), findsNothing);
    expect(find.text('ABCD-EFGH-IJKL'), findsNothing);
    expect(find.byKey(const ValueKey('signup-step-0-action')), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Your sign-in key'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.getSize(find.byType(IconButton)), const Size(48, 48));
    expect(
      find.text(
        'This is your access code. Tap it to copy; continuing saves it to your device.',
      ),
      findsOneWidget,
    );
    expect(find.text('Copy'), findsNothing);
    expect(find.text('Save code'), findsNothing);
    expect(find.byIcon(Icons.key_rounded), findsNothing);
    expect(find.byIcon(Icons.copy_rounded), findsNothing);
    expect(find.text('Terms'), findsNothing);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Ready to create your account?'), findsOneWidget);
    expect(find.text('Access code saved to this device'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('access code tap copies; saving is required before continuing', (
    tester,
  ) async {
    var saveResult = false;
    var saveAttempts = 0;
    final clipboardCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        clipboardCalls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => _SignupSession()),
          accessCodeSaverProvider.overrideWithValue((context, code) async {
            saveAttempts++;
            return saveResult;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const SignUpScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.ensureVisible(find.text('ABCD-EFGH-IJKL'));
    await tester.pump();
    await tester.tap(find.text('ABCD-EFGH-IJKL'));
    await tester.pump();
    final setClipboardCalls = clipboardCalls
        .where((call) => call.method == 'Clipboard.setData')
        .toList();
    expect(setClipboardCalls, hasLength(1));
    expect(setClipboardCalls.single.arguments, {'text': 'ABCD-EFGH-IJKL'});
    expect(find.text('Copied'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('ABCD-EFGH-IJKL'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(saveAttempts, 1);
    expect(
      find.text('Choose a place to save your code before continuing.'),
      findsOneWidget,
    );
    expect(find.text('Ready to create your account?'), findsNothing);

    saveResult = true;
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(saveAttempts, 2);
    expect(find.text('Ready to create your account?'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-up pages can be swiped horizontally', (tester) async {
    final session = _OnboardingSession();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => session),
          accessCodeSaverProvider.overrideWithValue(
            (context, code) async => true,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const SignUpScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Your sign-in key'), findsOneWidget);
    expect(session.codeRequests, 1);

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Your sign-in key').hitTestable(), findsOneWidget);
    expect(
      find.text('Ready to create your account?').hitTestable(),
      findsNothing,
    );
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('Ready to create your account?').hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Create account'), findsOneWidget);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_back_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Your sign-in key').hitTestable(), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-up wizard fits every step in the compact app window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
      final session = _OnboardingSession();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith((ref) => session),
            accessCodeSaverProvider.overrideWithValue(
              (context, code) async => true,
            ),
          ],
          child: MaterialApp(
            theme: theme,
            home: SignUpScreen(key: ValueKey(theme.brightness)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Your sign-in key'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Ready to create your account?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Turkish sign-up copy fits the compact app window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => _SignupSession()),
          accessCodeSaverProvider.overrideWithValue(
            (context, code) async => true,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          supportedLocales: const [Locale('en'), Locale('tr')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: AppTheme.darkTheme,
          home: const SignUpScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Özel bağlantın burada başlıyor.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Giriş anahtarın'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('signup-step-1-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Hesabını oluşturmaya hazır mısın?'), findsOneWidget);
    expect(find.text('Erişim kodu bu cihaza kaydedildi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('access-code field gets the website focus halo', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    final container = find
        .ancestor(
          of: find.byType(TextField),
          matching: find.byType(AnimatedContainer),
        )
        .first;
    final before =
        tester.widget<AnimatedContainer>(container).decoration as BoxDecoration;
    expect(before.boxShadow, isNull);
    await tester.tap(find.byType(TextField));
    await tester.pump(const Duration(milliseconds: 200));
    final focused =
        tester.widget<AnimatedContainer>(container).decoration as BoxDecoration;
    expect(focused.boxShadow, isNotEmpty);
    expect(focused.boxShadow!.single.blurRadius, 16);
    expect(focused.boxShadow!.single.spreadRadius, 0.5);
    final focusLift = find
        .ancestor(
          of: find.byType(TextField),
          matching: find.byType(AnimatedSlide),
        )
        .first;
    expect(tester.widget<AnimatedSlide>(focusLift).offset.dy, -1 / 52);
  });
  testWidgets('home fits narrow mobile viewport in both themes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(theme: theme, home: const HomeScreen()),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(find.text('CONNECT'), findsOneWidget);
      final connectControl = find.byKey(const ValueKey('vpn-connect-control'));
      expect(tester.getSize(connectControl).width, 280);
      expect(tester.getSize(connectControl).height, lessThanOrEqualTo(300));
      expect(find.byIcon(Icons.power_settings_new_rounded), findsNothing);
      expect(find.text('CONNECTED'), findsNothing);
      expect(find.text('Optimal'), findsOneWidget);
    }
  });

  testWidgets('tray choose-server action opens the location picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => _LocationPickerSession()),
        ],
        child: MaterialApp(
          navigatorKey: appNavigatorKey,
          theme: AppTheme.darkTheme,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    unawaited(openServerPicker());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isTrue,
    );
    expect(find.byType(ServerSelectionScreen), findsOneWidget);
    expect(find.text('Locations'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final platform in [
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ]) {
    testWidgets('every page fits the $platform window and a narrow phone', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final screens = <Widget>[
        const SignUpScreen(),
        const LoginScreen(),
        const HomeScreen(),
        const ServerSelectionScreen(),
        const AccountScreen(),
        const SettingsScreen(),
        const UsageStatisticsScreen(),
        const ClientLogsScreen(),
        const XrayCoreSettingsScreen(),
        const TrayPreferencesScreen(),
        const AndroidAppRoutingScreen(),
      ];
      const locales = [Locale('en'), Locale('es'), Locale('tr')];
      for (final locale in locales) {
        for (final size in [
          const Size(320, 568),
          const Size(360, 640),
          const Size(800, 600),
        ]) {
          tester.view.physicalSize = size;
          for (final screen in screens) {
            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp(
                  locale: locale,
                  supportedLocales: locales,
                  localizationsDelegates: GlobalMaterialLocalizations.delegates,
                  theme: AppTheme.darkTheme.copyWith(platform: platform),
                  scrollBehavior: const AppScrollBehavior(),
                  home: screen,
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 350));
            expect(
              tester.takeException(),
              isNull,
              reason: '$screen at $size in ${locale.languageCode}',
            );
            expect(
              find.byWidgetPredicate((widget) => widget is RawScrollbar),
              findsNothing,
              reason: 'Scrollbars should stay hidden on $screen at $size',
            );
            expect(
              find.byType(cupertino.CupertinoScrollbar),
              findsNothing,
              reason: 'Cupertino indicators should stay hidden on $screen',
            );
          }
        }
      }
    });
  }

  testWidgets('Xray settings expose supported user controls only', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final profile = VpnProfile.parseSubscription(testLink).single;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => _VlessSession(profile)),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const XrayCoreSettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Connection Settings'), findsOneWidget);
    expect(find.text('DNS'), findsOneWidget);
    expect(find.text('SPLIT TUNNELING'), findsOneWidget);
    expect(find.text('Advanced'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('dns-provider-row')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    expect((await XrayPreferences.userDnsSettings()).servers, [
      'https://dns.google/dns-query',
    ]);
    await tester.ensureVisible(
      find.byKey(const ValueKey('split-tunneling-domains-row')),
    );
    await tester.tap(find.byKey(const ValueKey('split-tunneling-domains-row')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Split tunneling'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('split-tunneling-mode-row')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await XrayPreferences.vpnOnlyDomainsEnabled(), isTrue);
    final domains = find.byKey(const ValueKey('bypass-domains-field'));
    expect(find.text('Add website'), findsNothing);
    expect(find.text('No websites added'), findsNothing);
    for (final domain in ['example.com', 'news.example.org']) {
      await tester.enterText(domains, domain);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 350));
    }
    expect(await XrayPreferences.bypassDomains(), [
      'example.com',
      'news.example.org',
    ]);
    Navigator.of(tester.element(domains)).pop();
    await tester.pump(const Duration(milliseconds: 350));
    final fragmentation = find.byKey(
      const ValueKey('xray-fragmentation-switch'),
    );
    await tester.ensureVisible(fragmentation);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Fragmentation settings'), findsNothing);
    await tester.tap(fragmentation);
    await tester.pump(const Duration(milliseconds: 250));
    expect(await XrayPreferences.tlsHelloFragmentationEnabled(), isTrue);
    expect(find.text('Fragmentation settings'), findsOneWidget);
    await tester.tap(find.text('Fragmentation settings'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Save'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('fragment-length-field')),
      '50-120',
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect((await XrayPreferences.fragmentRanges())['length'], '50-120');
    final config = XrayPreferences.configure(
      profile.config,
      RealityFingerprint.serverDefault,
      dnsSettings: await XrayPreferences.userDnsSettings(),
      finalMaskSettings: await XrayPreferences.userFinalMaskSettings(),
    );
    expect(config, contains('"maxSplit":"3-6"'));
    expect(tester.takeException(), isNull);
  });
}

class _LocationPickerSession extends SessionController {
  _LocationPickerSession() : super(OculveApi()) {
    state = AsyncValue.data(Account({}, const []));
  }

  @override
  Future<void> refresh() async {}
}
