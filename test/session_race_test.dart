import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';

class _DelayedAccountApi extends OculveApi {
  final accountResponse = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String? method,
    Map<String, String>? headers,
  }) {
    expect(path, '/api/user/me');
    return accountResponse.future;
  }
}

class _SignedInSession extends SessionController {
  _SignedInSession(super.api) {
    state = AsyncValue.data(Account({'status': 'active'}, const []));
  }

  Account? get current => state.valueOrNull;
}

void main() {
  test('late account refresh cannot restore a signed-out session', () async {
    final api = _DelayedAccountApi();
    final session = _SignedInSession(api);
    final pending = session.refreshAccount();
    session.clearLocalSession();
    api.accountResponse.complete({'status': 'active'});
    await pending;
    expect(session.current, isNull);
    session.dispose();
  });

  test('late full refresh cannot restore a signed-out session', () async {
    final api = _DelayedAccountApi();
    final session = _SignedInSession(api);
    final pending = session.refresh();
    session.clearLocalSession();
    api.accountResponse.complete({'status': 'active'});
    await pending;
    expect(session.current, isNull);
    session.dispose();
  });
}
