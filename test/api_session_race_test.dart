import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/network/oculve_api.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _Headers implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.cookies, {this.body});
  final Stream<List<int>>? body;
  @override
  final List<Cookie> cookies;
  @override
  int get statusCode => 200;
  @override
  final HttpHeaders headers = _Headers();
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => (body ?? Stream.value(utf8.encode('{}'))).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  final response = Completer<HttpClientResponse>();
  final sent = Completer<void>();
  bool aborted = false;
  @override
  void abort([Object? exception, StackTrace? stackTrace]) => aborted = true;
  @override
  final HttpHeaders headers = _Headers();
  @override
  final List<Cookie> cookies = [];
  @override
  Future<HttpClientResponse> close() {
    sent.complete();
    return response.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Client implements HttpClient {
  final request = _Request();
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => request;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _DelayedStorage implements FlutterSecureStorage {
  String? value;
  Completer<void>? readGate;
  Completer<void>? writeGate;
  final writeStarted = Completer<void>();

  Future<String?> _read() async {
    final snapshot = value;
    await readGate?.future;
    return snapshot;
  }

  Future<void> _write(String? next) async {
    if (!writeStarted.isCompleted) writeStarted.complete();
    await writeGate?.future;
    value = next;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #read:
        return _read();
      case #write:
        return _write(invocation.namedArguments[#value] as String?);
      case #delete:
        value = null;
        return Future<void>.value();
      default:
        return super.noSuchMethod(invocation);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = 'oculve.session.https://www.oculve.com';
  const storage = FlutterSecureStorage();

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

  test('late login response cannot persist a session after clear', () async {
    final client = _Client();
    await HttpOverrides.runZoned(() async {
      final api = OculveApi(storage: storage);
      addTearDown(api.close);
      final login = api.request('/api/auth/login', body: {'authCode': 'TEST'});
      await client.request.sent.future;
      await api.clear();
      client.request.response.complete(
        _Response([Cookie('token', 'late-token')]),
      );
      await login;
      expect(api.hasSession, isFalse);
      expect(await storage.read(key: key), isNull);
    }, createHttpClient: (_) => client);
  });

  test(
    'clear waits for an older secure-storage write before deleting',
    () async {
      final client = _Client();
      final delayedStorage = _DelayedStorage()..writeGate = Completer<void>();
      await HttpOverrides.runZoned(() async {
        final api = OculveApi(storage: delayedStorage);
        addTearDown(api.close);
        final login = api.request(
          '/api/auth/login',
          body: {'authCode': 'TEST'},
        );
        await client.request.sent.future;
        client.request.response.complete(
          _Response([Cookie('token', 'old-token')]),
        );
        await delayedStorage.writeStarted.future;
        final clear = api.clear();
        delayedStorage.writeGate!.complete();
        await Future.wait([login, clear]);
        expect(api.hasSession, isFalse);
        expect(delayedStorage.value, isNull);
        await api.restore();
        expect(api.hasSession, isFalse);
      }, createHttpClient: (_) => client);
    },
  );

  test('slow body has a total deadline and cancels its stream', () async {
    final client = _Client();
    var cancelled = false;
    final body = StreamController<List<int>>(
      onCancel: () {
        cancelled = true;
      },
    );
    await HttpOverrides.runZoned(() async {
      final api = OculveApi(storage: storage);
      addTearDown(api.close);
      final pending = api.request('/api/user/me');
      final check = expectLater(
        pending.timeout(const Duration(seconds: 24)),
        throwsA(isA<ApiFailure>()),
      );
      await client.request.sent.future;
      client.request.response.complete(_Response([], body: body.stream));
      body.add(utf8.encode('{'));
      final drip = Timer.periodic(
        const Duration(seconds: 5),
        (_) => body.add([32]),
      );
      try {
        await check;
        expect(cancelled, isTrue);
        expect(client.request.aborted, isTrue);
      } finally {
        drip.cancel();
        await body.close();
      }
    }, createHttpClient: (_) => client);
  });

  test(
    'oversized body cancels its stream before retaining more bytes',
    () async {
      final client = _Client();
      var cancelled = false;
      final body = StreamController<List<int>>(
        onCancel: () {
          cancelled = true;
        },
      );
      await HttpOverrides.runZoned(() async {
        final api = OculveApi(storage: storage);
        addTearDown(api.close);
        final pending = api.request('/api/user/me');
        final check = expectLater(pending, throwsA(isA<ApiFailure>()));
        await client.request.sent.future;
        client.request.response.complete(_Response([], body: body.stream));
        body.add(List<int>.filled(2 * 1024 * 1024 + 1, 32));
        await check;
        expect(cancelled, isTrue);
        expect(client.request.aborted, isTrue);
        await body.close();
      }, createHttpClient: (_) => client);
    },
  );

  test('a delayed secure-storage restore cannot undo clear', () async {
    final delayedStorage = _DelayedStorage()
      ..value = 'old-token'
      ..readGate = Completer<void>();
    final api = OculveApi(storage: delayedStorage);
    addTearDown(api.close);
    final restore = api.restore();
    await Future<void>.delayed(Duration.zero);
    await api.clear();
    delayedStorage.readGate!.complete();
    await restore;
    expect(api.hasSession, isFalse);
  });
}
