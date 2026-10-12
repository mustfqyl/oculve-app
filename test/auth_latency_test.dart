import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';

class _DelayedAccountApi extends OculveApi {
  final accountResponse = Completer<Map<String, dynamic>>();
  final requests = <String>[];

  @override
  Future<Map<String, String>> registrationHeaders() async => const {};

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String? method,
    Map<String, String>? headers,
  }) async {
    requests.add(path);
    if (path == '/api/auth/login') {
      return {
        'user': {'id': '42', 'authCode': 'ABCD-EFGH-IJKL'},
      };
    }
    if (path == '/api/auth/register') {
      return {
        'user': {'id': '42', 'authCode': 'ABCD-EFGH-IJKL'},
      };
    }
    if (path == '/api/user/me') return accountResponse.future;
    throw StateError('Unexpected API path: $path');
  }
}

void main() {
  test('login waits until account and server details finish loading', () async {
    final api = _DelayedAccountApi();
    final session = SessionController(api);
    var completed = false;

    final login = session.login('ABCD-EFGH-IJKL').then((_) {
      completed = true;
    });
    await Future<void>.delayed(Duration.zero);

    expect(api.requests, ['/api/auth/login', '/api/user/me']);
    expect(completed, isFalse);
    expect(session.state.isLoading, isTrue);

    api.accountResponse.complete({
      'id': '42',
      'authCode': 'ABCD-EFGH-IJKL',
      'status': 'active',
    });
    await login;
    expect(session.state.valueOrNull?.status, 'active');
    session.dispose();
  });

  test('registration waits until account details finish loading', () async {
    final api = _DelayedAccountApi();
    final session = SessionController(api);
    var completed = false;

    final registration = session.register('ABCD-EFGH-IJKL').then((_) {
      completed = true;
    });
    await Future<void>.delayed(Duration.zero);

    expect(api.requests, ['/api/auth/register', '/api/user/me']);
    expect(completed, isFalse);
    expect(session.state.isLoading, isTrue);

    api.accountResponse.complete({
      'id': '42',
      'authCode': 'ABCD-EFGH-IJKL',
      'status': 'active',
    });
    await registration;
    expect(session.state.valueOrNull?.status, 'active');
    session.dispose();
  });
}
