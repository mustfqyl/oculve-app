import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/vpn/profile.dart';
import 'package:oculve/core/vpn/server_address_resolver.dart';
import 'package:oculve/core/vpn/server_latency.dart';
import 'profile_test.dart' show testLink;

void main() {
  test('reads Happ address-resolution headers from the subscription', () {
    final settings = ServerAddressResolutionSettings.fromSubscription(
      headers: const {
        'server-address-resolve-enable': '1',
        'server-address-resolve-dns-domain':
            'https://resolver.example/dns-query',
        'server-address-resolve-dns-ip': '1.1.1.1',
      },
    );

    expect(settings, isNotNull);
    expect(settings!.dnsEndpoint.host, 'resolver.example');
    expect(settings.dnsEndpoint.path, '/dns-query');
    expect(settings.bootstrapAddress?.address, '1.1.1.1');
  });

  test('reads resolver metadata from Happ subscription body comments', () {
    final settings = ServerAddressResolutionSettings.fromSubscription(
      body: '''
#server-address-resolve-enable: true
#server-address-resolve-dns-domain: https://resolver.example/dns-query
#server-address-resolve-dns-ip: 2606:4700:4700::1111
vless://ignored
''',
    );

    expect(settings, isNotNull);
    expect(settings!.bootstrapAddress?.address, '2606:4700:4700::1111');
  });

  test('rejects insecure or malformed subscription resolver endpoints', () {
    expect(
      ServerAddressResolutionSettings.fromSubscription(
        headers: const {
          'server-address-resolve-enable': '1',
          'server-address-resolve-dns-domain':
              'http://resolver.example/dns-query',
        },
      ),
      isNull,
    );
    expect(
      ServerAddressResolutionSettings.fromSubscription(
        headers: const {
          'server-address-resolve-enable': '1',
          'server-address-resolve-dns-domain':
              'https://resolver.example/dns-query',
          'server-address-resolve-dns-ip': 'resolver.example',
        },
      ),
      isNull,
    );
  });

  test('uses subscription DoH answers for the real TCP ping target', () async {
    final profile = VpnProfile.parseSubscription(
      testLink.replaceFirst('127.0.0.1:443', 'node.example:443'),
      responseHeaders: const {
        'server-address-resolve-enable': '1',
        'server-address-resolve-dns-domain':
            'https://resolver.example/dns-query',
        'server-address-resolve-dns-ip': '1.1.1.1',
      },
    ).single;
    final queriedTypes = <int>[];
    String? probedAddress;
    String? diagnostic;
    final doh = DohServerAddressResolver(
      exchange: (endpoint, query, bootstrap) async {
        expect(endpoint.host, 'resolver.example');
        expect(bootstrap?.address, '1.1.1.1');
        final type = (query[query.length - 4] << 8) | query[query.length - 3];
        queriedTypes.add(type);
        return _dnsReply(
          query,
          answer: type == 1
              ? _addressRecord(1, InternetAddress('203.0.113.7').rawAddress)
              : null,
        );
      },
    );
    final latency = await ServerLatencyProbe(
      dohServerAddressResolver: doh,
      hostResolver: (_) async => const [],
      onDiagnostic: (value) => diagnostic = value,
      tcpRttSampler: (address, port) async {
        probedAddress = address.address;
        expect(port, 443);
        return 21;
      },
    ).measureTcpRtt(profile);

    expect(latency, 21);
    expect(queriedTypes.toSet(), {1, 28});
    expect(probedAddress, '203.0.113.7');
    expect(diagnostic, contains('node.example:443'));
    expect(diagnostic, contains('DNS: subscription DoH'));
    expect(diagnostic, contains('203.0.113.7: [21ms'));
    expect(diagnostic, contains('shown: 21ms'));
    expect(diagnostic, isNot(contains('11111111-1111-4111-8111')));
  });

  test(
    'TCP ping chooses a nearby system-DNS CDN edge over distant DoH edge',
    () async {
      final profile = VpnProfile.parseSubscription(
        testLink.replaceFirst('127.0.0.1:443', 'node.example:443'),
        responseHeaders: const {
          'server-address-resolve-enable': '1',
          'server-address-resolve-dns-domain':
              'https://resolver.example/dns-query',
        },
      ).single;
      final nearby = InternetAddress('203.0.113.8');
      final distant = InternetAddress('203.0.113.7');
      final probed = <String>[];
      final doh = DohServerAddressResolver(
        exchange: (_, query, _) async {
          final type = (query[query.length - 4] << 8) | query[query.length - 3];
          return _dnsReply(
            query,
            answer: type == 1 ? _addressRecord(1, distant.rawAddress) : null,
          );
        },
      );

      final latency = await ServerLatencyProbe(
        hostResolver: (_) async => [nearby],
        dohServerAddressResolver: doh,
        tcpRttSampler: (address, _) async {
          probed.add(address.address);
          return address == nearby ? 18 : 240;
        },
      ).measureTcpRtt(profile);

      expect(latency, 18);
      expect(probed.toSet(), {nearby.address, distant.address});
    },
  );

  test(
    'TCP ping compares the platform hostname dial with explicit DNS answers',
    () async {
      final profile = VpnProfile.parseSubscription(
        testLink.replaceFirst('127.0.0.1:443', 'node.example:443'),
        responseHeaders: const {
          'server-address-resolve-enable': '1',
          'server-address-resolve-dns-domain':
              'https://resolver.example/dns-query',
        },
      ).single;
      final directHostSamples = <int>[23, 24, 22, 23, 24];
      var directHostIndex = 0;
      String? directHost;
      String? diagnostic;
      final doh = DohServerAddressResolver(
        exchange: (_, query, _) async {
          final type = (query[query.length - 4] << 8) | query[query.length - 3];
          return _dnsReply(
            query,
            answer: type == 1
                ? _addressRecord(1, InternetAddress('203.0.113.7').rawAddress)
                : null,
          );
        },
      );

      final latency = await ServerLatencyProbe(
        hostResolver: (_) async => [InternetAddress('203.0.113.8')],
        dohServerAddressResolver: doh,
        tcpRttSampler: (_, _) async => 240,
        tcpHostRttSampler: (host, port) async {
          directHost = '$host:$port';
          return directHostSamples[directHostIndex++];
        },
        onDiagnostic: (value) => diagnostic = value,
      ).measureTcpRtt(profile);

      expect(latency, 22);
      expect(directHostIndex, 5);
      expect(directHost, 'node.example:443');
      expect(diagnostic, contains('native host dial: [23ms, 24ms, 22ms'));
      expect(diagnostic, contains('shown: 22ms'));
    },
  );

  test('validates answer IDs and ignores wrong resolver replies', () async {
    final settings = ServerAddressResolutionSettings.fromSubscription(
      headers: const {
        'server-address-resolve-enable': '1',
        'server-address-resolve-dns-domain':
            'https://resolver.example/dns-query',
      },
    )!;
    final resolver = DohServerAddressResolver(
      exchange: (_, query, _) async => _dnsReply(
        query,
        idOverride: 0,
        answer: _addressRecord(1, InternetAddress('203.0.113.9').rawAddress),
      ),
    );

    expect(await resolver.lookup('node.example', settings), isEmpty);
  });
}

List<int> _dnsReply(List<int> query, {List<int>? answer, int? idOverride}) {
  var questionEnd = 12;
  while (questionEnd < query.length && query[questionEnd] != 0) {
    questionEnd += query[questionEnd] + 1;
  }
  questionEnd += 5;
  final id = idOverride ?? ((query[0] << 8) | query[1]);
  return [
    id >> 8,
    id & 0xff,
    0x81,
    0x80,
    0x00,
    0x01,
    0x00,
    answer == null ? 0 : 1,
    0x00,
    0x00,
    0x00,
    0x00,
    ...query.sublist(12, questionEnd),
    ...?answer,
  ];
}

List<int> _addressRecord(int type, List<int> address) => [
  0xc0,
  0x0c,
  type >> 8,
  type & 0xff,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x3c,
  address.length >> 8,
  address.length & 0xff,
  ...address,
];
