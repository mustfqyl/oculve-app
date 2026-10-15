import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/vpn/server_address_resolver.dart';

class _Headers implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _SlowResponse extends Stream<List<int>> implements HttpClientResponse {
  final body = StreamController<List<int>>();
  @override
  int get statusCode => 200;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => body.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.response);
  final _SlowResponse response;
  @override
  final HttpHeaders headers = _Headers();
  @override
  Future<HttpClientResponse> close() async => response;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Client implements HttpClient {
  final response = _SlowResponse();
  bool closed = false;
  @override
  Future<HttpClientRequest> postUrl(Uri uri) async => _Request(response);
  @override
  void close({bool force = false}) {
    closed = true;
    unawaited(response.body.close());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('DoH total timeout closes both underlying slow HTTP clients', () async {
    final clients = <_Client>[];
    await HttpOverrides.runZoned(
      () async {
        final result = DohServerAddressResolver().lookup(
          'server.example',
          ServerAddressResolutionSettings(
            dnsEndpoint: Uri.parse('https://dns.example/query'),
          ),
        );
        final check = expectLater(result, throwsA(isA<TimeoutException>()));
        await Future<void>.delayed(Duration.zero);
        expect(clients, hasLength(2));
        final drip = Timer.periodic(const Duration(seconds: 1), (_) {
          for (final client in clients.where((client) => !client.closed)) {
            client.response.body.add([0]);
          }
        });
        try {
          await check;
          await Future<void>.delayed(Duration.zero);
          expect(clients.every((client) => client.closed), isTrue);
        } finally {
          drip.cancel();
          for (final client in clients) {
            client.close(force: true);
          }
        }
      },
      createHttpClient: (_) {
        final client = _Client();
        clients.add(client);
        return client;
      },
    );
  });
}
