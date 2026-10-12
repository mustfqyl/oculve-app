import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:passkeys/types.dart';
import 'package:oculve/core/auth/client_passkey.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'package:oculve/features/auth/presentation/login_screen.dart';

final options = <String, dynamic>{
  'challenge': base64Url.encode(List<int>.filled(32, 42)).replaceAll('=', ''),
  'rpId': 'www.oculve.com',
  'userVerification': 'required',
  'allowCredentials': [
    {
      'id': 'Y3JlZGVudGlhbA',
      'type': 'public-key',
      'transports': ['internal'],
    },
  ],
};
const assertion = AuthenticateResponseType(
  id: 'Y3JlZGVudGlhbA',
  rawId: 'Y3JlZGVudGlhbA',
  clientDataJSON: 'ZGF0YQ',
  authenticatorData: 'YXV0aA',
  signature: 'c2ln',
  userHandle: '',
);
ClientPasskey service({
  bool biometrics = true,
  bool supported = true,
  bool nativePlatform = true,
  Future<AuthenticateResponseType> Function(AuthenticateRequestType)? sign,
}) => ClientPasskey(
  supportedPlatform: nativePlatform,
  hasEnrolledBiometrics: () async => biometrics,
  supportsPasskeys: () async => supported,
  authenticate: sign ?? (_) async => assertion,
  cancel: () async {},
);

class PasskeyApi extends OculveApi {
  final bodies = <Map<String, dynamic>>[];
  final paths = <String>[];
  bool passkeyOnly = false;
  bool nativeConfigured = true;
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String? method,
    Map<String, String>? headers,
  }) async {
    paths.add(path);
    if (body != null) bodies.add(body);
    if (path == '/api/auth/login') {
      return {
        'requiresTwoFactor': true,
        'challengeToken': 'challenge',
        'methods': {'totp': !passkeyOnly, 'passkey': true},
        'passkeyOptions': options,
        'nativePasskeySupported': nativeConfigured,
      };
    }
    if (path == '/api/auth/login/passkey' ||
        path == '/api/auth/login/two-factor') {
      return {};
    }
    if (path == '/api/user/me') return {'id': '42', 'status': 'active'};
    throw StateError('Unexpected request');
  }
}

void main() {
  testWidgets(
    'leaving during a capability probe does not touch a disposed screen',
    (tester) async {
      final api = PasskeyApi();
      final capability = Completer<bool>();
      final native = ClientPasskey(
        supportedPlatform: true,
        hasEnrolledBiometrics: () => capability.future,
        supportsPasskeys: () async => true,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiProvider.overrideWithValue(api),
            clientPasskeyProvider.overrideWithValue(native),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.enterText(find.byType(TextField), 'ABCD-EFGH-IJKL');
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      capability.complete(true);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      api.close();
    },
  );
  testWidgets('cancelled native attempt cannot submit a late assertion', (
    tester,
  ) async {
    final api = PasskeyApi();
    final signed = Completer<AuthenticateResponseType>();
    var cancelled = false;
    final native = ClientPasskey(
      supportedPlatform: true,
      hasEnrolledBiometrics: () async => true,
      supportsPasskeys: () async => true,
      authenticate: (_) => signed.future,
      cancel: () async {
        cancelled = true;
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          clientPasskeyProvider.overrideWithValue(native),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.enterText(find.byType(TextField), 'ABCD-EFGH-IJKL');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Sign in with passkey'));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    signed.complete(assertion);
    await tester.pump();
    expect(cancelled, isTrue);
    expect(api.paths, isNot(contains('/api/auth/login/passkey')));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    api.close();
  });
  for (final biometrics in [false, true]) {
    for (final passkeyOnly in [false, true]) {
      testWidgets(
        'button matches enrolled sensor, biometrics=$biometrics, passkeyOnly=$passkeyOnly',
        (tester) async {
          final api = PasskeyApi()..passkeyOnly = passkeyOnly;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                apiProvider.overrideWithValue(api),
                clientPasskeyProvider.overrideWithValue(
                  service(biometrics: biometrics),
                ),
              ],
              child: const MaterialApp(home: LoginScreen()),
            ),
          );
          await tester.enterText(find.byType(TextField), 'ABCD-EFGH-IJKL');
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(
            find.text('Sign in with passkey'),
            biometrics ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(TextField),
            passkeyOnly ? findsNothing : findsOneWidget,
          );
          if (passkeyOnly && !biometrics) {
            expect(
              find.textContaining('Set up an authenticator code'),
              findsOneWidget,
            );
          }
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Back to sign in'));
          await tester.pump(const Duration(seconds: 1));
          expect(find.text('Sign in with passkey'), findsNothing);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
          api.close();
        },
      );
    }
  }
  testWidgets(
    'missing native server setup hides passkey even on a biometric device',
    (tester) async {
      final api = PasskeyApi()..nativeConfigured = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiProvider.overrideWithValue(api),
            clientPasskeyProvider.overrideWithValue(service()),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.enterText(find.byType(TextField), 'ABCD-EFGH-IJKL');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Sign in with passkey'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      api.close();
    },
  );
  test(
    'native request uses the original challenge, local credentials and required verification',
    () async {
      AuthenticateRequestType? signed;
      final native = service(
        sign: (request) async {
          signed = request;
          return assertion;
        },
      );
      final response = await native.authenticate(options);
      expect(signed!.challenge, options['challenge']);
      expect(signed!.relyingPartyId, 'www.oculve.com');
      expect(signed!.userVerification, 'required');
      expect(signed!.preferImmediatelyAvailableCredentials, isTrue);
      expect(signed!.canBeSecurityKey, isFalse);
      expect(signed!.allowCredentials!.single.id, 'Y3JlZGVudGlhbA');
      expect(response!['response'], {
        'clientDataJSON': 'ZGF0YQ',
        'authenticatorData': 'YXV0aA',
        'signature': 'c2ln',
      });
      final api = PasskeyApi();
      final session = SessionController(api);
      await session.loginWithPasskey('challenge', response);
      expect(api.paths, ['/api/auth/login/passkey', '/api/user/me']);
      expect(api.bodies.single, {
        'challengeToken': 'challenge',
        'response': response,
      });
      expect(session.state.valueOrNull?.status, 'active');
      session.dispose();
      api.close();
    },
  );
  test(
    'no enrolled sensor, unsupported OS and unsupported passkey implementation stay hidden',
    () async {
      expect(await service(biometrics: false).isAvailable(), isFalse);
      expect(await service(supported: false).isAvailable(), isFalse);
      expect(await service(nativePlatform: false).isAvailable(), isFalse);
      var signed = false;
      await expectLater(
        service(
          biometrics: false,
          sign: (_) async {
            signed = true;
            return assertion;
          },
        ).authenticate(options),
        throwsA(isA<ApiFailure>()),
      );
      expect(signed, isFalse);
    },
  );
  test('capability failure is safe and never prompts', () async {
    final native = ClientPasskey(
      supportedPlatform: true,
      hasEnrolledBiometrics: () async => throw StateError('sensor unavailable'),
    );
    expect(await native.isAvailable(), isFalse);
  });
  test('cancelled native sheet returns no assertion or session', () async {
    expect(
      await service(
        sign: (_) async => throw PasskeyAuthCancelledException(),
      ).authenticate(options),
      isNull,
    );
  });
  test(
    'missing local passkey and missing app association produce actionable TOTP errors',
    () async {
      await expectLater(
        service(
          sign: (_) async => throw NoCredentialsAvailableException(),
        ).authenticate(options),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.message,
            'message',
            contains('No matching passkey'),
          ),
        ),
      );
      await expectLater(
        service(
          sign: (_) async => throw DomainNotAssociatedException('not linked'),
        ).authenticate(options),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.message,
            'message',
            contains('not configured'),
          ),
        ),
      );
    },
  );
  test(
    'method availability preserves TOTP and carries native options',
    () async {
      final api = PasskeyApi();
      final session = SessionController(api);
      await expectLater(
        session.login('access'),
        throwsA(
          isA<SecondFactorRequired>()
              .having((e) => e.totp, 'TOTP', true)
              .having((e) => e.passkeyOptions, 'options', options),
        ),
      );
      await session.login('123456', challenge: 'challenge');
      expect(api.paths, contains('/api/auth/login/two-factor'));
      api.passkeyOnly = true;
      await expectLater(
        session.login('access'),
        throwsA(
          isA<SecondFactorRequired>().having((e) => e.totp, 'TOTP', false),
        ),
      );
      session.dispose();
      api.close();
    },
  );
}
