import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';

class _Headers implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation call) => null;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(
    this.payload, {
    this.cookies = const [],
    this.statusCode = 200,
    this.rawBody,
  });
  final Map<String, dynamic> payload;
  final String? rawBody;
  @override
  final List<Cookie> cookies;
  @override
  final int statusCode;
  @override
  final HttpHeaders headers = _Headers();
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(utf8.encode(rawBody ?? jsonEncode(payload))).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation call) => super.noSuchMethod(call);
}

class _Request implements HttpClientRequest {
  final result = Completer<HttpClientResponse>();
  final sent = Completer<void>();
  @override
  final List<Cookie> cookies = [];
  @override
  final HttpHeaders headers = _Headers();
  @override
  Future<HttpClientResponse> close() {
    sent.complete();
    return result.future;
  }

  @override
  dynamic noSuchMethod(Invocation call) => null;
}

class _Client implements HttpClient {
  final auth = <_Request>[];
  final other = <_Request>[];
  bool deferAccount = false;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final request = _Request();
    if (url.path.startsWith('/api/auth/')) {
      auth.add(request);
    } else {
      other.add(request);
      if (!deferAccount) {
        unawaited(
          request.sent.future.then((_) {
            final token = request.cookies
                .where((cookie) => cookie.name == 'token')
                .firstOrNull
                ?.value;
            request.result.complete(
              _Response({'status': 'expired', 'authCode': token}),
            );
          }),
        );
      }
    }
    return request;
  }

  @override
  dynamic noSuchMethod(Invocation call) => null;
}

class _DelayedRegistrationApi extends OculveApi {
  final headersGate = Completer<Map<String, String>>();
  @override
  Future<Map<String, String>> registrationHeaders() => headersGate.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage();
  const key = 'oculve.session.https://www.oculve.com';
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Oculve',
      packageName: 'com.oculve.app',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });
  for (final oldestFirst in [true, false]) {
    test(
      'latest login owns cookie regardless of response order ($oldestFirst)',
      () async {
        final client = _Client();
        await HttpOverrides.runZoned(() async {
          final api = OculveApi(storage: storage);
          final session = SessionController(api);
          addTearDown(api.close);
          addTearDown(session.dispose);
          final old = session.login('OLDER-CODE');
          await Future<void>.delayed(Duration.zero);
          final latest = session.login('LATEST-CODE');
          await Future<void>.delayed(Duration.zero);
          expect(client.auth, hasLength(2));
          await Future.wait(client.auth.map((request) => request.sent.future));
          if (oldestFirst) {
            client.auth[0].result.complete(
              _Response({}, cookies: [Cookie('token', 'older-fixture')]),
            );
            await old;
            client.auth[1].result.complete(
              _Response({}, cookies: [Cookie('token', 'latest-fixture')]),
            );
          } else {
            client.auth[1].result.complete(
              _Response({}, cookies: [Cookie('token', 'latest-fixture')]),
            );
            await latest;
            client.auth[0].result.complete(
              _Response({}, cookies: [Cookie('token', 'older-fixture')]),
            );
          }
          await Future.wait([old, latest]);
          expect(
            session.state.valueOrNull!.authCode == 'latest-fixture',
            isTrue,
          );
          expect(await storage.read(key: key) == 'latest-fixture', isTrue);
        }, createHttpClient: (_) => client);
      },
    );
  }

  for (final failure in ['missing-cookie', 'empty-cookie', 'invalid-json']) {
    test(
      'invalid login acknowledgement cannot reuse or replace an old session ($failure)',
      () async {
        FlutterSecureStorage.setMockInitialValues({key: 'existing-fixture'});
        final client = _Client();
        await HttpOverrides.runZoned(() async {
          final api = OculveApi(storage: storage);
          final session = SessionController(api);
          addTearDown(api.close);
          addTearDown(session.dispose);
          await api.restore();
          await session.refresh();
          final login = session.login('DIFFERENT-CODE');
          final rejected = expectLater(login, throwsA(isA<ApiFailure>()));
          await Future<void>.delayed(Duration.zero);
          await client.auth.single.sent.future;
          client.auth.single.result.complete(
            _Response(
              {},
              cookies: failure == 'missing-cookie'
                  ? []
                  : [
                      Cookie(
                        'token',
                        failure == 'empty-cookie' ? '' : 'new-fixture',
                      ),
                    ],
              rawBody: failure == 'invalid-json' ? 'not-json' : null,
            ),
          );
          await rejected;
          expect(client.other, hasLength(1));
          expect(
            session.state.valueOrNull?.authCode == 'existing-fixture',
            isTrue,
          );
          expect(await storage.read(key: key) == 'existing-fixture', isTrue);
        }, createHttpClient: (_) => client);
      },
    );
  }

  test(
    'second-factor challenge cannot persist a prematurely supplied session',
    () async {
      FlutterSecureStorage.setMockInitialValues({key: 'existing-fixture'});
      final client = _Client();
      await HttpOverrides.runZoned(() async {
        final api = OculveApi(storage: storage);
        final session = SessionController(api);
        addTearDown(api.close);
        addTearDown(session.dispose);
        await api.restore();
        final login = session.login('CHALLENGED-CODE');
        final challenge = expectLater(
          login,
          throwsA(isA<SecondFactorRequired>()),
        );
        await Future<void>.delayed(Duration.zero);
        await client.auth.single.sent.future;
        client.auth.single.result.complete(
          _Response(
            {
              'requiresTwoFactor': true,
              'challengeToken': 'fixture-challenge',
              'methods': {'totp': true},
            },
            statusCode: 202,
            cookies: [Cookie('token', 'premature-fixture')],
          ),
        );
        await challenge;
        expect(client.other, isEmpty);
        expect(await storage.read(key: key) == 'existing-fixture', isTrue);
      }, createHttpClient: (_) => client);
    },
  );

  for (final path in [
    '/api/auth/register',
    '/api/auth/login/two-factor',
    '/api/auth/login/passkey',
  ]) {
    test('$path completion requires its own nonempty session cookie', () async {
      final client = _Client();
      await HttpOverrides.runZoned(() async {
        final api = OculveApi(storage: storage);
        addTearDown(api.close);
        final request = api.request(path, body: {});
        final failure = expectLater(request, throwsA(isA<ApiFailure>()));
        await Future<void>.delayed(Duration.zero);
        await client.auth.single.sent.future;
        client.auth.single.result.complete(_Response({}));
        await failure;
        expect(api.hasSession, isFalse);
      }, createHttpClient: (_) => client);
    });
  }
  for (final path in [
    '/api/auth/register',
    '/api/auth/login/two-factor',
    '/api/auth/login/passkey',
  ]) {
    test('new auth route $path owns the session over pending login', () async {
      final client = _Client();
      await HttpOverrides.runZoned(() async {
        final api = OculveApi(storage: storage);
        addTearDown(api.close);
        final old = api.request('/api/auth/login', body: {});
        final latest = api.request(path, body: {});
        await Future<void>.delayed(Duration.zero);
        await Future.wait(client.auth.map((request) => request.sent.future));
        client.auth[0].result.complete(
          _Response({}, cookies: [Cookie('token', 'older-fixture')]),
        );
        await old;
        client.auth[1].result.complete(
          _Response({}, cookies: [Cookie('token', 'new-fixture')]),
        );
        await latest;
        expect(await storage.read(key: key) == 'new-fixture', isTrue);
      }, createHttpClient: (_) => client);
    });
  }

  test(
    'obsolete registration cannot send after delayed identity headers',
    () async {
      final client = _Client();
      await HttpOverrides.runZoned(() async {
        final api = _DelayedRegistrationApi();
        final session = SessionController(api);
        addTearDown(api.close);
        addTearDown(session.dispose);
        final register = session.register('OBSOLETE-CODE');
        final login = session.login('LATEST-CODE');
        await Future<void>.delayed(Duration.zero);
        await client.auth.single.sent.future;
        client.auth.single.result.complete(
          _Response({}, cookies: [Cookie('token', 'new-fixture')]),
        );
        await login;
        api.headersGate.complete({});
        await Future<void>.delayed(Duration.zero);
        if (client.auth.length > 1) {
          client.auth.last.result.complete(_Response({}));
        }
        await register;
        expect(client.auth, hasLength(1));
        expect(session.state.valueOrNull?.authCode == 'new-fixture', isTrue);
      }, createHttpClient: (_) => client);
    },
  );

  test(
    'obsolete two-factor challenge is not delivered over a newer login',
    () async {
      final client = _Client();
      await HttpOverrides.runZoned(() async {
        final api = OculveApi(storage: storage);
        final session = SessionController(api);
        addTearDown(api.close);
        addTearDown(session.dispose);
        final old = session.login('OLD-CODE');
        final latest = session.login('LATEST-CODE');
        await Future<void>.delayed(Duration.zero);
        await Future.wait(client.auth.map((request) => request.sent.future));
        client.auth[1].result.complete(
          _Response({}, cookies: [Cookie('token', 'new-fixture')]),
        );
        await latest;
        client.auth[0].result.complete(
          _Response({
            'requiresTwoFactor': true,
            'challengeToken': 'old-fixture',
            'methods': {'totp': true},
          }),
        );
        await expectLater(old, completes);
        expect(session.state.valueOrNull?.authCode == 'new-fixture', isTrue);
      }, createHttpClient: (_) => client);
    },
  );

  test(
    'old session 401 cannot discard an in-flight new login cookie',
    () async {
      final client = _Client()..deferAccount = true;
      FlutterSecureStorage.setMockInitialValues({key: 'previous-fixture'});
      await HttpOverrides.runZoned(() async {
        final api = OculveApi(storage: storage);
        addTearDown(api.close);
        await api.restore();
        final login = api.request('/api/auth/login', body: {});
        final account = api.request('/api/user/me');
        final rejected = expectLater(account, throwsA(isA<ApiFailure>()));
        await Future<void>.delayed(Duration.zero);
        await Future.wait([
          client.auth.single.sent.future,
          client.other.single.sent.future,
        ]);
        client.other.single.result.complete(_Response({}, statusCode: 401));
        await rejected;
        expect(api.hasSession, isFalse);
        client.auth.single.result.complete(
          _Response({}, cookies: [Cookie('token', 'new-fixture')]),
        );
        await login;
        expect(api.hasSession, isTrue);
        expect(await storage.read(key: key) == 'new-fixture', isTrue);
      }, createHttpClient: (_) => client);
    },
  );

  test(
    'ordinary cookie rotation cannot block a newer authentication',
    () async {
      final client = _Client()..deferAccount = true;
      await HttpOverrides.runZoned(() async {
        final api = OculveApi(storage: storage);
        addTearDown(api.close);
        final login = api.request('/api/auth/login', body: {});
        final account = api.request('/api/user/me');
        await Future<void>.delayed(Duration.zero);
        await Future.wait([
          client.auth.single.sent.future,
          client.other.single.sent.future,
        ]);
        client.other.single.result.complete(
          _Response({}, cookies: [Cookie('token', 'rotation-fixture')]),
        );
        await account;
        client.auth.single.result.complete(
          _Response({}, cookies: [Cookie('token', 'new-fixture')]),
        );
        await login;
        expect(await storage.read(key: key) == 'new-fixture', isTrue);
      }, createHttpClient: (_) => client);
    },
  );

  test('a pending older logout does not clear the newer login', () async {
    final client = _Client();
    await HttpOverrides.runZoned(() async {
      final api = OculveApi(storage: storage);
      final session = SessionController(api);
      addTearDown(api.close);
      addTearDown(session.dispose);
      final logout = session.logout();
      await Future<void>.delayed(Duration.zero);
      final login = session.login('NEW-CODE');
      await Future<void>.delayed(Duration.zero);
      await Future.wait(client.auth.map((request) => request.sent.future));
      client.auth[1].result.complete(
        _Response({}, cookies: [Cookie('token', 'new-fixture')]),
      );
      await login;
      client.auth[0].result.complete(_Response({}));
      await logout;
      expect(session.state.valueOrNull?.authCode == 'new-fixture', isTrue);
      expect(await storage.read(key: key) == 'new-fixture', isTrue);
    }, createHttpClient: (_) => client);
  });

  test('logout from an older controller cannot clear a newer login', () async {
    final client = _Client();
    await HttpOverrides.runZoned(() async {
      final api = OculveApi(storage: storage);
      final older = SessionController(api);
      final newer = SessionController(api);
      addTearDown(api.close);
      addTearDown(older.dispose);
      addTearDown(newer.dispose);
      final logout = older.logout();
      await Future<void>.delayed(Duration.zero);
      final login = newer.login('NEW-CODE');
      await Future<void>.delayed(Duration.zero);
      await Future.wait(client.auth.map((request) => request.sent.future));
      client.auth[1].result.complete(
        _Response({}, cookies: [Cookie('token', 'new-fixture')]),
      );
      await login;
      client.auth[0].result.complete(_Response({}));
      await logout;
      expect(newer.state.valueOrNull?.authCode == 'new-fixture', isTrue);
      expect(await storage.read(key: key) == 'new-fixture', isTrue);
    }, createHttpClient: (_) => client);
  });

  test('failed logout still clears the current local session', () async {
    FlutterSecureStorage.setMockInitialValues({key: 'stored-fixture'});
    final client = _Client();
    await HttpOverrides.runZoned(() async {
      final api = OculveApi(storage: storage);
      final session = SessionController(api);
      addTearDown(api.close);
      addTearDown(session.dispose);
      await api.restore();
      final logout = session.logout();
      final failure = expectLater(logout, throwsA(isA<ApiFailure>()));
      await Future<void>.delayed(Duration.zero);
      await client.auth.single.sent.future;
      client.auth.single.result.complete(_Response({}, statusCode: 503));
      await failure;
      expect(api.hasSession, isFalse);
      expect(session.state.valueOrNull, isNull);
      expect(await storage.read(key: key), isNull);
    }, createHttpClient: (_) => client);
  });

  test('logout initiation invalidates an older pending login', () async {
    final client = _Client();
    await HttpOverrides.runZoned(() async {
      final api = OculveApi(storage: storage);
      final session = SessionController(api);
      addTearDown(api.close);
      addTearDown(session.dispose);
      final login = session.login('OLD-CODE');
      await Future<void>.delayed(Duration.zero);
      final logout = session.logout();
      await Future<void>.delayed(Duration.zero);
      await Future.wait(client.auth.map((request) => request.sent.future));
      client.auth[0].result.complete(
        _Response({}, cookies: [Cookie('token', 'old-fixture')]),
      );
      await login;
      expect(api.hasSession, isFalse);
      client.auth[1].result.complete(_Response({}));
      await logout;
      expect(session.state.valueOrNull, isNull);
      expect(await storage.read(key: key), isNull);
    }, createHttpClient: (_) => client);
  });

  test(
    'a created registration with missing acknowledgement retains the sign-in recovery path',
    () async {
      final client = _Client();
      await HttpOverrides.runZoned(() async {
        final api = _DelayedRegistrationApi()..headersGate.complete({});
        final session = SessionController(api);
        addTearDown(api.close);
        addTearDown(session.dispose);
        final register = session.register('CREATED-CODE');
        final failure = expectLater(
          register,
          throwsA(isA<RegistrationCreatedButNotReady>()),
        );
        await Future<void>.delayed(Duration.zero);
        await client.auth.single.sent.future;
        client.auth.single.result.complete(
          _Response({
            'user': {'authCode': 'CREATED-CODE'},
          }, statusCode: 201),
        );
        await failure;
        expect(api.hasSession, isFalse);
        expect(client.other, isEmpty);
      }, createHttpClient: (_) => client);
    },
  );

  test('explicit clear invalidates every pending authentication', () async {
    final client = _Client();
    await HttpOverrides.runZoned(() async {
      final api = OculveApi(storage: storage);
      addTearDown(api.close);
      final pending = api.request('/api/auth/login', body: {});
      await Future<void>.delayed(Duration.zero);
      await client.auth.single.sent.future;
      await api.clear();
      client.auth.single.result.complete(
        _Response({}, cookies: [Cookie('token', 'late-fixture')]),
      );
      await pending;
      expect(api.hasSession, isFalse);
      expect(await storage.read(key: key), isNull);
    }, createHttpClient: (_) => client);
  });
}
