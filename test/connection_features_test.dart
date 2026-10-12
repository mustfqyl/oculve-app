import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oculve/core/connection/lan_proxy_service.dart';
import 'package:oculve/core/connection/diagnostic_report.dart';
import 'package:oculve/core/vpn/xray_preferences.dart';

class Bytes {
  Bytes(Socket socket) : chunks = StreamIterator(socket);
  final StreamIterator<List<int>> chunks;
  List<int> pending = [];
  Future<List<int>> take(int count) async {
    while (pending.length < count) {
      if (!await chunks.moveNext().timeout(const Duration(seconds: 3))) {
        throw StateError('Closed');
      }
      pending.addAll(chunks.current);
    }
    final result = pending.sublist(0, count);
    pending = pending.sublist(count);
    return result;
  }

  Future<String> headers() async {
    final data = <int>[];
    while (!latin1.decode(data).endsWith('\r\n\r\n')) {
      data.addAll(await take(1));
    }
    return latin1.decode(data);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('custom encrypted DNS persists and rejects unsafe endpoints', () async {
    SharedPreferences.setMockInitialValues({});
    const url = 'https://dns.example.net:8443/custom-query';
    await XrayPreferences.setUserDnsSettings(
      const XrayDnsSettings(servers: [url]),
    );
    expect((await XrayPreferences.userDnsSettings()).servers, [url]);
    for (final bad in [
      'http://dns.test/query',
      'https://user:secret@dns.test/query',
      'https://dns.test/query#fragment',
      'https://dns.test:99999/query',
      'https://dns.test',
    ]) {
      expect(
        () =>
            XrayPreferences.setUserDnsSettings(XrayDnsSettings(servers: [bad])),
        throwsFormatException,
      );
    }
  });
  test(
    'fragment ranges reach config and invalid input preserves last settings',
    () async {
      SharedPreferences.setMockInitialValues({});
      await XrayPreferences.setTlsHelloFragmentation(true);
      await XrayPreferences.setFragmentRanges(
        length: '50-120',
        delay: '0-5',
        splits: '2-4',
      );
      expect(
        (await XrayPreferences.userFinalMaskSettings()).json,
        contains('50-120'),
      );
      expect(
        () => XrayPreferences.setFragmentRanges(
          length: '200-100',
          delay: '0',
          splits: '2',
        ),
        throwsFormatException,
      );
      expect((await XrayPreferences.fragmentRanges())['length'], '50-120');
    },
  );
  test(
    'report drops raw secrets, server addresses and unrecognized version strings',
    () {
      final report = diagnosticReport(
        state: 'secret-account',
        events: [
          '2026-10-11T12:00:00Z connected',
          '2026-10-11T12:00:01Z password=private-secret 192.168.1.2 destination.example',
          '2026-10-11T12:00:02Z automatic reconnect attempt 2',
        ],
        pingChecks: 2,
        sharing: true,
        reconnect: true,
        coreVersion: 'private-secret',
      );
      expect(report, contains('connected'));
      expect(report, contains('automatic reconnect attempt 2'));
      for (final secret in [
        'private-secret',
        'secret-account',
        '192.168.1.2',
        'destination.example',
      ]) {
        expect(report, isNot(contains(secret)));
      }
    },
  );
  test('LAN binds private interfaces only', () async {
    final service = LanProxyService();
    addTearDown(service.dispose);
    for (final ip in ['0.0.0.0', '8.8.8.8', '172.32.0.1', '127.0.0.1']) {
      expect(
        () => service.start(
          address: ip,
          port: 0,
          username: 'test',
          password: 'test-password-123',
          ready: () => true,
        ),
        throwsStateError,
      );
    }
    expect(LanProxyService.isPrivateAddress('172.16.0.1'), isTrue);
    expect(LanProxyService.isPrivateAddress('192.168.1.42'), isTrue);
  });
  for (final protocol in ['SOCKS', 'CONNECT', 'HTTP']) {
    test(
      '$protocol authenticates both hops and sends domains through managed VPN proxy',
      () async {
        final upstream = await ServerSocket.bind('127.0.0.1', 0);
        final service = LanProxyService();
        final serverDone = Completer<void>();
        final sockets = <Socket>[];
        upstream.listen((socket) async {
          sockets.add(socket);
          try {
            final bytes = Bytes(socket);
            expect(await bytes.take(3), [5, 1, 2]);
            socket.add([5, 2]);
            expect(await bytes.take(2), [1, 7]);
            expect(utf8.decode(await bytes.take(7)), 'session');
            final length = (await bytes.take(1)).single;
            expect(utf8.decode(await bytes.take(length)), 'session-secret');
            socket.add([1, 0]);
            expect(await bytes.take(4), [5, 1, 0, 3]);
            final hostLength = (await bytes.take(1)).single;
            expect(
              utf8.decode(await bytes.take(hostLength)),
              'destination.invalid',
            );
            expect(
              await bytes.take(2),
              protocol == 'HTTP' ? [0, 80] : [1, 187],
            );
            socket.add([5, 0, 0, 1, 127, 0, 0, 1, 0, 0]);
            if (protocol == 'HTTP') {
              final request = await bytes.headers();
              expect(request, startsWith('GET /page?q=1 HTTP/1.1\r\n'));
              expect(
                request.toLowerCase(),
                isNot(contains('proxy-authorization')),
              );
            } else {
              expect(utf8.decode(await bytes.take(4)), 'ping');
            }
            socket.add(utf8.encode('pong'));
            await socket.flush();
            serverDone.complete();
          } catch (e, st) {
            serverDone.completeError(e, st);
          }
        });
        await service.start(
          address: '127.0.0.1',
          port: 0,
          username: 'test',
          password: 'test-password-123',
          ready: () => true,
          allowLoopbackForTest: true,
          endpoint: () async =>
              ProxyEndpoint(upstream.port, 'session', 'session-secret'),
        );
        final client = await Socket.connect('127.0.0.1', service.port!);
        sockets.add(client);
        addTearDown(() async {
          await service.stop();
          service.dispose();
          for (final socket in sockets) {
            socket.destroy();
          }
          await upstream.close();
        });
        final response = Bytes(client);
        if (protocol == 'SOCKS') {
          client.add([5, 1, 2]);
          expect(await response.take(2), [5, 2]);
          final password = utf8.encode('test-password-123');
          client.add([
            1,
            4,
            ...utf8.encode('test'),
            password.length,
            ...password,
          ]);
          expect(await response.take(2), [1, 0]);
          final host = utf8.encode('destination.invalid');
          client.add([5, 1, 0, 3, host.length, ...host, 1, 187]);
          expect((await response.take(10)).take(2), [5, 0]);
          client.add(utf8.encode('ping'));
        } else {
          final auth = base64.encode(utf8.encode('test:test-password-123'));
          client.add(
            latin1.encode(
              protocol == 'CONNECT'
                  ? 'CONNECT destination.invalid:443 HTTP/1.1\r\nProxy-Authorization: Basic $auth\r\n\r\n'
                  : 'GET http://destination.invalid/page?q=1 HTTP/1.1\r\nHost: destination.invalid\r\nProxy-Authorization: Basic $auth\r\n\r\n',
            ),
          );
          if (protocol == 'CONNECT') {
            expect(await response.headers(), startsWith('HTTP/1.1 200'));
            client.add(utf8.encode('ping'));
          }
        }
        expect(utf8.decode(await response.take(4)), 'pong');
        await serverDone.future;
        await service.stop();
        expect(service.running, isFalse);
      },
    );
  }
  test('unauthenticated clients never contact VPN endpoint', () async {
    final service = LanProxyService();
    int calls = 0;
    await service.start(
      address: '127.0.0.1',
      port: 0,
      username: 'test',
      password: 'test-password-123',
      ready: () => true,
      allowLoopbackForTest: true,
      endpoint: () async {
        calls++;
        return const ProxyEndpoint(1, 'x', 'y');
      },
    );
    final client = await Socket.connect('127.0.0.1', service.port!);
    final bytes = Bytes(client);
    client.add(latin1.encode('CONNECT example.invalid:443 HTTP/1.1\r\n\r\n'));
    expect(
      await bytes.headers(),
      contains('407 Proxy Authentication Required'),
    );
    expect(calls, 0);
    client.destroy();
    await service.stop();
    service.dispose();
  });
}
