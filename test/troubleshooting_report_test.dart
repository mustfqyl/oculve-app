import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vless/flutter_vless.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/vpn/server_latency.dart';
import 'package:oculve/features/settings/presentation/client_logs_screen.dart';

/// Answers the two diagnostics calls the report page makes, so the page never
/// waits on a real native channel.
class _StubPlatform extends VlessPlatform {
  _StubPlatform({this.snapshot = '', this.fails = false});

  final String snapshot;
  final bool fails;

  @override
  Future<void> initializeVless({
    required void Function(VlessStatus status) onStatusChanged,
    required String notificationIconResourceType,
    required String notificationIconResourceName,
    required String providerBundleIdentifier,
    required String groupIdentifier,
    String? keychainAccessGroup,
  }) async {}

  @override
  Future<String> getProviderDebugSnapshot() async {
    if (fails) throw StateError('native diagnostics unavailable');
    return snapshot;
  }
}

/// Selectable diagnostics lines render through rich text, so plain `find.text`
/// cannot see them.
Finder _selectableContaining(String text) => find.byWidgetPredicate(
  (widget) =>
      widget is SelectableText &&
      (widget.textSpan?.toPlainText() ?? widget.data ?? '').contains(text),
);

Widget _screen(
  ProviderContainer container, {
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
}) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    theme: AppTheme.darkTheme,
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('es'), Locale('tr')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 640),
        textScaler: textScaler,
        disableAnimations: true,
      ),
      child: const ClientLogsScreen(),
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tapVisible(WidgetTester tester, String label) async {
  final finder = find.text(label);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      120,
      scrollable: find.byType(Scrollable).first,
    );
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VlessPlatform originalPlatform;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    originalPlatform = VlessPlatform.instance;
    VlessPlatform.instance = _StubPlatform();
  });
  tearDown(() => VlessPlatform.instance = originalPlatform);

  test('diagnostic lines keep the timestamp apart from the message', () {
    expect(diagnosticLineParts('2026-10-30T10:00:00.000 connected'), (
      stamp: '2026-10-30T10:00:00.000',
      message: 'connected',
    ));
    expect(diagnosticLineParts('error dismissed'), (
      stamp: null,
      message: 'error dismissed',
    ));
    expect(diagnosticLineParts(''), (stamp: null, message: ''));
  });

  testWidgets('the summary shows status and the latest activity first', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(vpnProvider.notifier).events.addAll([
      '2026-10-30T10:00:00.000 connection preparation started',
      '2026-10-30T10:00:02.000 Your subscription is not active.',
    ]);

    await tester.pumpWidget(_screen(container));
    await _settle(tester);

    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.text('Latest activity'), findsOneWidget);
    // Once in the summary, once in the expanded app-events preview.
    expect(
      _selectableContaining('Your subscription is not active.'),
      findsNWidgets(2),
    );
    expect(
      _selectableContaining('connection preparation started'),
      findsOneWidget,
    );
    expect(find.text('Export troubleshooting report'), findsOneWidget);
  });

  testWidgets('technical sections stay folded until the reader opens them', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_screen(container));
    await _settle(tester);

    expect(find.text('TCP ping checks'), findsOneWidget);
    expect(find.text('Xray diagnostics'), findsOneWidget);
    expect(
      find.text('No server ping checks have been recorded.'),
      findsNothing,
    );
    expect(find.text('Available'), findsNothing);

    await _tapVisible(tester, 'TCP ping checks');
    await _settle(tester);
    expect(
      find.text('No server ping checks have been recorded.'),
      findsOneWidget,
    );

    await _tapVisible(tester, 'Xray diagnostics');
    await _settle(tester);
    expect(find.text('No records'), findsOneWidget);
    expect(
      _selectableContaining('No native diagnostics have been recorded.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unavailable native snapshot is called out on its own row', (
    tester,
  ) async {
    VlessPlatform.instance = _StubPlatform(fails: true);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_screen(container));
    await _settle(tester);
    await _tapVisible(tester, 'Xray diagnostics');
    await _settle(tester);

    expect(find.text('Not available'), findsOneWidget);
    final message = tester.widget<SelectableText>(
      _selectableContaining('Native diagnostics could not be retrieved.'),
    );
    expect(message.style?.color, AppTheme.warningColor);
  });

  testWidgets('a long event history keeps a short preview', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    for (var i = 1; i <= 10; i++) {
      container
          .read(vpnProvider.notifier)
          .events
          .add(
            '2026-10-30T10:00:0$i.000 event ${i.toString().padLeft(2, '0')}',
          );
    }

    await tester.pumpWidget(_screen(container));
    await _settle(tester);

    expect(find.text('Show all'), findsOneWidget);
    expect(_selectableContaining('event 04'), findsNothing);
    expect(_selectableContaining('event 05'), findsOneWidget);

    await _tapVisible(tester, 'Show all');
    await tester.pump();
    expect(_selectableContaining('event 01'), findsOneWidget);
    expect(find.text('Show fewer'), findsOneWidget);

    await _tapVisible(tester, 'Show fewer');
    await tester.pump();
    expect(_selectableContaining('event 01'), findsNothing);
  });

  testWidgets('narrow screen with large text never overflows', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    VlessPlatform.instance = _StubPlatform(
      snapshot: 'SESSION_START value=1\nTUN_ESTABLISHED value=1',
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final longToken = 'x' * 240;
    container.read(vpnProvider.notifier).events.addAll([
      '2026-10-30T10:00:00.000 connection preparation started $longToken',
      '2026-10-30T10:00:02.000 Your subscription is not active.',
    ]);
    container.read(serverLatencyDiagnosticsProvider.notifier).state = [
      '2026-10-30T10:00:00.000 TCP ping example.com:443 | DNS: system | '
          'resolved: 203.0.113.10: [timeout, 42ms] → 42ms | shown: 42ms',
    ];

    await tester.pumpWidget(
      _screen(container, textScaler: const TextScaler.linear(2)),
    );
    await _settle(tester);

    await _tapVisible(tester, 'TCP ping checks');
    await _tapVisible(tester, 'Xray diagnostics');
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('TCP ping checks'), findsOneWidget);
  });

  testWidgets('report labels follow the app language', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_screen(container, locale: const Locale('tr')));
    await _settle(tester);

    expect(find.text('Durum'), findsOneWidget);
    expect(find.text('Son etkinlik'), findsOneWidget);
    expect(find.text('Uygulama olayları'), findsOneWidget);
    expect(find.text('TCP ping kontrolleri'), findsOneWidget);
    expect(find.text('Xray tanılaması'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
