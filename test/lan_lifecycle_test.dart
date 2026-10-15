import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/connection/lan_proxy_service.dart';

void main() {
  test(
    'slow unauthenticated client cannot keep a handshake slot forever',
    () async {
      final service = LanProxyService();
      var endpoints = 0;
      await service.start(
        address: '127.0.0.1',
        port: 0,
        username: 'test',
        password: 'test-password-123',
        ready: () => true,
        allowLoopbackForTest: true,
        endpoint: () async {
          endpoints++;
          return const ProxyEndpoint(1, 'x', 'y');
        },
      );
      final client = await Socket.connect('127.0.0.1', service.port!);
      final closed = client.listen((_) {}).asFuture<void>();
      client.add([67]);
      final drip = Timer.periodic(
        const Duration(seconds: 3),
        (_) => client.add([32]),
      );
      try {
        await closed.timeout(const Duration(seconds: 12));
        expect(endpoints, 0);
        expect(service.running, isTrue);
      } finally {
        drip.cancel();
        client.destroy();
        await service.stop();
        service.dispose();
      }
    },
  );

  test(
    'disposing during LAN start cannot leave a listening proxy behind',
    () async {
      final service = LanProxyService();
      final start = service.start(
        address: '127.0.0.1',
        port: 0,
        username: 'test',
        password: 'test-password-123',
        ready: () => true,
        allowLoopbackForTest: true,
      );
      service.dispose();
      await start;
      final running = service.running;
      await service.stop();
      expect(running, isFalse);
    },
  );
}
