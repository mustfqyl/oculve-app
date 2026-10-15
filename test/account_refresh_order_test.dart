import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'profile_test.dart' show testLink;

class _OrderedApi extends OculveApi {
  final replies = List.generate(3, (_) => Completer<Map<String, dynamic>>());
  var requests = 0;
  final subscriptionGate = Completer<SubscriptionResponse>();
  final subscriptionCalls = <String>[];
  @override
  Future<SubscriptionResponse> subscriptionResponse(String url) {
    subscriptionCalls.add(url);
    return url == '/old'
        ? subscriptionGate.future
        : Future.value(SubscriptionResponse(body: testLink));
  }

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String? method,
    Map<String, String>? headers,
  }) {
    expect(path, '/api/user/me');
    return replies[requests++].future;
  }
}

class _ChangingUrlApi extends OculveApi {
  var reads = 0, downloads = 0;
  late Future<void> Function() changeDetails;
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String? method,
    Map<String, String>? headers,
  }) async => {'status': 'active', 'subscriptionUrl': '/v${reads++}'};
  @override
  Future<SubscriptionResponse> subscriptionResponse(String url) async {
    downloads++;
    await changeDetails();
    return SubscriptionResponse(body: testLink);
  }
}

void main() {
  test(
    'continuously changing subscription URL fails within three loads without fake success',
    () async {
      final api = _ChangingUrlApi();
      final session = SessionController(api)
        ..state = const AsyncValue.data(Account({'status': 'active'}, []));
      addTearDown(api.close);
      addTearDown(session.dispose);
      api.changeDetails = session.refreshAccount;
      await expectLater(session.refresh(), throwsA(isA<ApiFailure>()));
      expect(api.downloads, 3);
      expect(session.state.valueOrNull!.subscriptionUrl, '/v3');
      expect(session.state.valueOrNull!.profiles, isEmpty);
    },
  );

  test(
    'old inactive account read still loads servers for a newer active account',
    () async {
      final api = _OrderedApi();
      final session = SessionController(api)
        ..state = const AsyncValue.data(Account({'status': 'active'}, []));
      addTearDown(api.close);
      addTearDown(session.dispose);
      final full = session.refresh();
      final details = session.refreshAccount();
      api.replies[1].complete({'status': 'active', 'subscriptionUrl': '/new'});
      await details;
      api.replies[0].complete({'status': 'expired', 'subscriptionUrl': '/new'});
      await full;
      expect(session.state.valueOrNull!.canConnect, isTrue);
      expect(api.subscriptionCalls, ['/new']);
      expect(session.state.valueOrNull!.profiles, isNotEmpty);
    },
  );

  test('full refresh supersedes older detail refresh', () async {
    final api = _OrderedApi();
    final session = SessionController(api)
      ..state = const AsyncValue.data(Account({'status': 'active'}, []));
    addTearDown(api.close);
    addTearDown(session.dispose);
    final oldDetails = session.refreshAccount();
    final full = session.refresh();
    api.replies[1].complete({'status': 'expired'});
    await full;
    api.replies[0].complete({'status': 'active'});
    await oldDetails;
    expect(session.state.valueOrNull!.canConnect, isFalse);
  });

  test(
    'pending server load cannot overwrite a newer expired account',
    () async {
      final api = _OrderedApi();
      final session = SessionController(api)
        ..state = const AsyncValue.data(Account({'status': 'active'}, []));
      addTearDown(api.close);
      addTearDown(session.dispose);
      final full = session.refresh();
      api.replies[0].complete({'status': 'active', 'subscriptionUrl': '/old'});
      await Future<void>.delayed(Duration.zero);
      expect(api.subscriptionCalls, ['/old']);
      final details = session.refreshAccount();
      api.replies[1].complete({'status': 'expired', 'subscriptionUrl': '/old'});
      await details;
      api.subscriptionGate.complete(SubscriptionResponse(body: testLink));
      await full;
      expect(session.state.valueOrNull!.canConnect, isFalse);
      expect(session.state.valueOrNull!.profiles, isEmpty);
    },
  );

  test(
    'pending old subscription loads the newer URL before settling',
    () async {
      final api = _OrderedApi();
      final session = SessionController(api)
        ..state = const AsyncValue.data(Account({'status': 'active'}, []));
      addTearDown(api.close);
      addTearDown(session.dispose);
      final full = session.refresh();
      api.replies[0].complete({'status': 'active', 'subscriptionUrl': '/old'});
      await Future<void>.delayed(Duration.zero);
      final details = session.refreshAccount();
      api.replies[1].complete({'status': 'active', 'subscriptionUrl': '/new'});
      await details;
      api.subscriptionGate.complete(SubscriptionResponse(body: testLink));
      await full;
      expect(api.subscriptionCalls, ['/old', '/new']);
      expect(session.state.valueOrNull!.subscriptionUrl, '/new');
      expect(session.state.valueOrNull!.profiles, isNotEmpty);
    },
  );

  test(
    'older account response cannot restore active status after newer expiry',
    () async {
      final api = _OrderedApi();
      final session = SessionController(api)
        ..state = const AsyncValue.data(Account({'status': 'active'}, []));
      addTearDown(api.close);
      addTearDown(session.dispose);
      final old = session.refreshAccount();
      final latest = session.refreshAccount();
      api.replies[1].complete({'status': 'expired'});
      await latest;
      api.replies[0].complete({'status': 'active'});
      await old;
      expect(session.state.valueOrNull!.canConnect, isFalse);
      expect(session.state.valueOrNull!.status, 'expired');
    },
  );

  test(
    'successful older account response survives a newer failed request',
    () async {
      final api = _OrderedApi();
      final session = SessionController(api)
        ..state = const AsyncValue.data(Account({'status': 'active'}, []));
      addTearDown(api.close);
      addTearDown(session.dispose);
      final old = session.refreshAccount();
      final latest = session.refreshAccount();
      final failure = expectLater(latest, throwsA(isA<ApiFailure>()));
      api.replies[1].completeError(const ApiFailure('fixture unreachable'));
      await failure;
      api.replies[0].complete({'status': 'expired'});
      await old;
      expect(session.state.valueOrNull!.status, 'expired');
    },
  );
}
