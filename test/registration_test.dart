import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'package:oculve/features/auth/presentation/signup_screen.dart';

class _RegistrationApi extends OculveApi {
  final calls = <String>[];
  @override
  Future<Map<String, String>> registrationHeaders() async => {
    'x-oculve-device-id': 'stable-test-id',
  };

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String? method,
    Map<String, String>? headers,
  }) async {
    calls.add(path);
    if (path == '/api/auth/generate-code') {
      expect(headers?['x-oculve-device-id'], 'stable-test-id');
      return {'code': 'ABCD-EFGH-IJKL'};
    }
    if (path == '/api/auth/register') {
      expect(headers?['x-oculve-device-id'], 'stable-test-id');
      expect(body, {'authCode': 'ABCD-EFGH-IJKL', 'planCode': 'open'});
      return {'success': true};
    }
    if (path == '/api/user/me') return {'status': 'active'};
    throw StateError('Unexpected API path: $path');
  }
}

void main() {
  test('registration uses website code and Open account APIs', () async {
    final api = _RegistrationApi();
    final session = SessionController(api);
    expect(await session.generateRegistrationCode(), 'ABCD-EFGH-IJKL');
    await session.register('ABCD-EFGH-IJKL');
    expect(api.calls, [
      '/api/auth/generate-code',
      '/api/auth/register',
      '/api/user/me',
    ]);
    expect(session.state.valueOrNull?.status, 'active');
    session.dispose();
  });

  testWidgets('account creation requires a successfully saved access code', (
    tester,
  ) async {
    final api = _RegistrationApi();
    final savedCodes = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          accessCodeSaverProvider.overrideWithValue((context, code) async {
            savedCodes.add(code);
            return true;
          }),
        ],
        child: const MaterialApp(home: SignUpScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ABCD-EFGH-IJKL'), findsNothing);
    expect(api.calls, isEmpty);
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('ABCD-EFGH-IJKL'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Ready to create your account?'), findsOneWidget);
    expect(savedCodes, ['ABCD-EFGH-IJKL']);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(find.byType(Checkbox), findsNothing);
    expect(api.calls, ['/api/auth/generate-code']);
    await tester.tap(find.text('Create account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(api.calls, [
      '/api/auth/generate-code',
      '/api/auth/register',
      '/api/user/me',
    ]);
  });
}
