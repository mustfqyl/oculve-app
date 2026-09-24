import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:oculve/core/vpn/profile.dart';

const testLink =
    'vless://11111111-1111-4111-8111-111111111111@127.0.0.1:443?encryption=none&security=reality&sni=example.com&fp=chrome&pbk=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA&sid=0123456789abcdef&type=tcp&flow=xtls-rprx-vision#Test%20location';
void main() {
  test('Reality TCP profile preserves transport credentials and Vision', () {
    final profile = VpnProfile.parseSubscription(testLink).single;
    final config = jsonDecode(profile.config);
    final node = config['outbounds'][0];
    expect(profile.name, 'Test location');
    expect(node['protocol'], 'vless');
    expect(
      node['settings']['vnext'][0]['users'][0]['flow'],
      'xtls-rprx-vision',
    );
    expect(
      node['streamSettings']['realitySettings']['serverName'],
      'example.com',
    );
    expect(config['inbounds'][0]['listen'], '127.0.0.1');
    expect(config['outbounds'].length, 1);
  });
  test('base64 subscription deduplicates profiles', () {
    final encoded = base64Encode(utf8.encode('$testLink\n$testLink'));
    expect(VpnProfile.parseSubscription(encoded), hasLength(1));
  });
  test('accepts Happ Xray JSON arrays', () {
    final config =
        jsonDecode(VpnProfile.parseSubscription(testLink).single.config)
            as Map<String, dynamic>;
    config['remarks'] = '🇹🇷 Istanbul';
    final profile = VpnProfile.parseSubscription(jsonEncode([config])).single;

    expect(profile.name, 'Istanbul');
    expect(profile.flag, '🇹🇷');
    expect(profile.config, contains('"security":"reality"'));
  });

  test('subscription import preserves a valid Xray core version guard', () {
    final source =
        jsonDecode(VpnProfile.parseSubscription(testLink).single.config)
              as Map<String, dynamic>
          ..['version'] = {'min': '26.9.9', 'max': '27.0.0'};
    final profile = VpnProfile.parseSubscription(jsonEncode([source])).single;
    final config = jsonDecode(profile.config) as Map<String, dynamic>;

    expect(config['version'], {'min': '26.9.9', 'max': '27.0.0'});
  });

  test('subscription import rejects malformed Xray version guards', () {
    final base =
        jsonDecode(VpnProfile.parseSubscription(testLink).single.config)
            as Map<String, dynamic>;
    for (final guard in [
      '26.9.9',
      {'min': '26.9'},
      {'max': 26},
      {'min': '26.9.9', 'current': '26.9.9'},
      {'min': '27.0.0', 'max': '26.9.9'},
    ]) {
      final source = Map<String, dynamic>.from(base)..['version'] = guard;
      expect(
        () => VpnProfile.parseSubscription(jsonEncode([source])),
        throwsFormatException,
        reason: '$guard',
      );
    }
  });
  test('imports TLS and supported non-TCP VLESS transports unchanged', () {
    final tls = VpnProfile.parseSubscription(
      testLink.replaceAll('security=reality', 'security=tls'),
    ).single;
    expect(
      jsonDecode(tls.config)['outbounds'][0]['streamSettings']['security'],
      'tls',
    );

    final websocket = VpnProfile.parseSubscription(
      testLink.replaceAll('type=tcp', 'type=ws'),
    ).single;
    expect(
      jsonDecode(websocket.config)['outbounds'][0]['streamSettings']['network'],
      'ws',
    );
  });

  test(
    'imports Xray remote-proxy outbounds without retaining server listeners',
    () {
      final nodes = [
        {
          'protocol': 'vmess',
          'settings': {
            'vnext': [
              {'address': 'vmess.example', 'port': 443, 'users': []},
            ],
          },
        },
        {
          'protocol': 'trojan',
          'settings': {
            'servers': [
              {'address': 'trojan.example', 'port': 443, 'password': 'secret'},
            ],
          },
        },
        {
          'protocol': 'shadowsocks',
          'settings': {
            'servers': [
              {
                'address': 'ss.example',
                'port': 8388,
                'method': 'chacha20-poly1305',
                'password': 'secret',
              },
            ],
          },
        },
        {
          'protocol': 'socks',
          'settings': {
            'servers': [
              {'address': 'socks.example', 'port': 1080},
            ],
          },
        },
        {
          'protocol': 'http',
          'settings': {
            'servers': [
              {'address': 'http.example', 'port': 8080},
            ],
          },
        },
        {
          'protocol': 'hysteria',
          'settings': {
            'version': 2,
            'address': 'hysteria.example',
            'port': 443,
          },
          'streamSettings': {
            'network': 'hysteria',
            'security': 'tls',
            'tlsSettings': {'serverName': 'hysteria.example'},
            'hysteriaSettings': {'version': 2, 'auth': 'secret'},
          },
        },
        {
          'protocol': 'wireguard',
          'settings': {
            'secretKey': 'secret',
            'address': ['10.0.0.2/32'],
            'peers': [
              {'publicKey': 'public', 'endpoint': 'wg.example:51820'},
            ],
          },
        },
      ];
      final body = jsonEncode([
        for (final node in nodes)
          {
            'remarks': node['protocol'],
            'inbounds': [
              {'protocol': 'http', 'listen': '0.0.0.0', 'port': 9000},
            ],
            'outbounds': [node],
          },
      ]);

      final profiles = VpnProfile.parseSubscription(body);
      expect(profiles.map((profile) => profile.name), [
        'vmess',
        'trojan',
        'shadowsocks',
        'socks',
        'http',
        'hysteria',
        'wireguard',
      ]);
      for (var index = 0; index < nodes.length; index++) {
        final config =
            jsonDecode(profiles[index].config) as Map<String, dynamic>;
        expect(
          config['outbounds'].single['protocol'],
          nodes[index]['protocol'],
        );
        expect(config['inbounds'].single['listen'], '127.0.0.1');
        expect(config.containsKey('api'), isFalse);
      }
    },
  );
  test('subscription cannot inject local listeners, direct routes or APIs', () {
    final original = jsonDecode(
      VpnProfile.parseSubscription(testLink).single.config,
    );
    original['inbounds'] = [
      {'protocol': 'http', 'listen': '0.0.0.0', 'port': 9999},
    ];
    original['api'] = {
      'tag': 'api',
      'services': ['HandlerService'],
    };
    original['routing'] = {
      'rules': [
        {'type': 'field', 'network': 'tcp,udp', 'outboundTag': 'direct'},
      ],
    };
    original['outbounds'].add({'protocol': 'freedom', 'tag': 'direct'});
    final safe = jsonDecode(
      VpnProfile.parseSubscription(jsonEncode(original)).single.config,
    );
    expect(safe.containsKey('api'), false);
    expect(safe.containsKey('routing'), false);
    expect(safe['outbounds'], hasLength(1));
    expect(safe['inbounds'][0]['listen'], '127.0.0.1');
  });
}
