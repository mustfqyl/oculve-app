"""Pure checks for the privileged Linux helper's routing boundary."""
from importlib.machinery import SourceFileLoader
from pathlib import Path
import unittest
import math
from unittest.mock import patch
import io
import json
import subprocess


HELPER = SourceFileLoader(
    'oculve_tunnel',
    str(Path(__file__).resolve().parents[1] / 'native/linux/oculve-tunnel'),
).load_module()


class LinuxTunnelConfigTest(unittest.TestCase):
    def test_https_dns_stays_on_selected_proxy_and_virtual_dns(self):
        cfg = HELPER.build_dpi_config('eth0', [], 'https://cloudflare-dns.com/dns-query', 12345)
        self.assertEqual(cfg['dns']['servers'], ['https://cloudflare-dns.com/dns-query'])
        self.assertTrue(cfg['dns']['disableFallback'])
        redirect = next(out for out in cfg['outbounds'] if out['tag'] == 'oculve-doh-bootstrap')
        self.assertEqual(redirect['settings']['redirect'], '1.1.1.1:443')
        self.assertEqual(redirect['streamSettings']['sockopt']['dialerProxy'], 'byedpi')
        relay = next(out for out in cfg['outbounds'] if out['tag'] == 'oculve-system-dns')
        self.assertEqual(relay['settings']['rules'][1]['action'], 'hijack')
        self.assertEqual(cfg['routing']['rules'][0]['outboundTag'], 'oculve-doh-bootstrap')
        with self.assertRaises(ValueError): HELPER.dns_endpoint('https://attacker.example/dns')

    def test_switch_filter_has_no_root_or_established_flow_bypass(self):
        rules = HELPER.switch_filter(Path('/sys/fs/cgroup/oculve-123'))
        self.assertIn('policy drop', rules)
        self.assertIn('socket cgroupv2 level 1 "oculve-123" accept', rules)
        self.assertIn('meta nfproto ipv6 drop', rules)
        self.assertNotIn('skuid 0', rules)
        self.assertNotIn('ct state established', rules)
        self.assertNotIn('flush ruleset', rules)
        with self.assertRaises(ValueError): HELPER.switch_filter(Path('root; accept'))

    def test_existing_guard_chain_is_refreshed_without_replacing_table(self):
        rules = HELPER.switch_filter(
            Path('/sys/fs/cgroup/oculve-456'), chain_exists=True,
        )
        self.assertIn('flush chain inet oculve_switch output', rules)
        self.assertNotIn('add table inet oculve_switch', rules)
        self.assertNotIn('add chain inet oculve_switch output', rules)
        self.assertIn('socket cgroupv2 level 1 "oculve-456" accept', rules)
        partial = HELPER.switch_filter(
            Path('/sys/fs/cgroup/oculve-457'), table_exists=True,
        )
        self.assertNotIn('add table inet oculve_switch', partial)
        self.assertIn('add chain inet oculve_switch output', partial)

    def test_supervisor_keeps_guard_after_runtime_failure_until_explicit_stop(self):
        class Selector:
            def register(self, *_args): pass
            def select(self, _timeout): return [object()]
            def close(self): pass

        old = (HELPER.guard_active, HELPER.stopping, HELPER.explicit_stop,
               HELPER.next_request)
        HELPER.guard_active = True
        HELPER.stopping = False
        HELPER.explicit_stop = False
        HELPER.next_request = None
        stream = type('Input', (), {'buffer': io.BytesIO(b'stop\n')})()
        try:
            with patch.object(HELPER, 'main', side_effect=RuntimeError('worker failed')), \
                 patch.object(HELPER.selectors, 'DefaultSelector', return_value=Selector()), \
                 patch.object(HELPER.sys, 'stdin', stream), \
                 patch.object(HELPER, 'cleanup_dpi_attempt') as cleanup, \
                 patch.object(HELPER, 'event'):
                HELPER.supervise()
            cleanup.assert_called_once()
            self.assertTrue(HELPER.guard_active)
            self.assertTrue(HELPER.explicit_stop)
        finally:
            (HELPER.guard_active, HELPER.stopping, HELPER.explicit_stop,
             HELPER.next_request) = old

    def test_filter_failure_rejects_switch_before_worker_cleanup(self):
        stream = type('Input', (), {'buffer': io.BytesIO(json.dumps({'dpiBypass': True}).encode() + b'\n')})()
        with patch.object(HELPER.sys, 'stdin', stream), patch.object(HELPER, 'arm_switch_guard', side_effect=RuntimeError()), patch.object(HELPER, 'cleanup_dpi_attempt') as cleanup, patch.object(HELPER, 'event'):
            self.assertEqual(HELPER.receive_command(), 'rejected')
            cleanup.assert_not_called()
            self.assertIsNone(HELPER.next_request)

    def test_dpi_automatic_groups_and_pinned_manual_strategies(self):
        automatic = HELPER.dpi_strategy_args(4)
        self.assertEqual(automatic.count('--auto'), 4)
        self.assertEqual(automatic.count('torst,ssl_err'), 4)
        for profile in range(4):
            self.assertNotIn('--auto', HELPER.dpi_strategy_args(profile))
        for profile in (-1, 5, True, '4'):
            with self.assertRaises(ValueError):
                HELPER.dpi_strategy_args(profile)

    def test_only_plain_domains_are_accepted(self):
        self.assertEqual(
            HELPER.validate_bypass_domains(['example.com', 'example.com']),
            ['example.com'],
        )
        for value in ('*.example.com', 'example.com;echo bad', 'localhost',
                      'EXAMPLE.COM', '1.2.3.4'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                HELPER.validate_bypass_domains([value])
        with self.assertRaises(ValueError):
            HELPER.validate_bypass_domains(['example.com'] * 33)

    def test_bypass_binds_direct_socket_to_physical_interface(self):
        config = HELPER.build_config(
            {'tag': 'proxy', 'protocol': 'vless'}, 'eth0', ['example.com'], '9.9.9.9',
        )
        self.assertEqual(config['log']['loglevel'], 'warning')
        self.assertEqual(config['log']['access'], 'none')
        self.assertEqual(config['log']['error'], 'none')
        self.assertEqual(next(item for item in config['outbounds'] if item['tag'] == 'direct')['protocol'], 'freedom')
        self.assertEqual(
            next(item for item in config['outbounds'] if item['tag'] == 'direct')['streamSettings']['sockopt']['interface'],
            'eth0',
        )
        self.assertEqual(
            config['routing']['rules'][2]['domain'], ['domain:example.com'],
        )
        self.assertTrue(config['inbounds'][0]['sniffing']['routeOnly'])
        self.assertEqual(
            config['routing']['rules'][1]['ip'], ['::/0'],
        )
        self.assertEqual(config['dns']['servers'], ['tcp://9.9.9.9'])

    def test_dpi_mode_uses_only_local_bydpi_direct_and_block_outbounds(self):
        config = HELPER.build_dpi_config('wlan0', [], '9.9.9.9', 43127)
        outbounds = {item['tag']: item for item in config['outbounds']}
        self.assertEqual(set(outbounds), {'byedpi', 'direct', 'block', 'oculve-system-dns'})
        self.assertNotIn('vless', [item['protocol'] for item in config['outbounds']])
        self.assertEqual(
            outbounds['byedpi']['settings']['servers'],
            [{'address': '127.0.0.1', 'port': 43127}],
        )
        self.assertEqual(
            outbounds['direct']['streamSettings']['sockopt']['interface'], 'wlan0',
        )
        self.assertEqual(config['inbounds'][0]['settings']['name'], 'oculve0')
        self.assertEqual(config['routing']['rules'][1]['outboundTag'], 'block')

    def test_dpi_routing_rules_map_existing_actions_to_xray_outbounds(self):
        rules = [
            {'type': 'field', 'domain': ['domain:gstatic.com'], 'outboundTag': 'direct'},
            {'type': 'field', 'domain': ['domain:discord.com'], 'outboundTag': 'proxy'},
            {'type': 'field', 'process': ['RobloxPlayerBeta.exe'], 'outboundTag': 'direct'},
            {'type': 'field', 'ip': ['geoip:private'], 'outboundTag': 'block'},
        ]
        config = HELPER.build_dpi_config('en0', [], '1.1.1.1', 45001, rules)
        self.assertEqual(
            [rule['outboundTag'] for rule in config['routing']['rules'] if rule['outboundTag'] != 'oculve-system-dns'],
            ['block', 'byedpi', 'byedpi', 'direct', 'byedpi', 'direct', 'block'],
        )
        self.assertEqual(
            config['routing']['rules'][2]['domain'], ['full:www.gstatic.com'],
        )
        self.assertEqual(
            config['routing']['rules'][3]['domain'], ['full:cp.cloudflare.com'],
        )
        self.assertLess(
            config['routing']['rules'].index(next(
                rule for rule in config['routing']['rules'] if 'full:www.gstatic.com' in rule.get('domain', [])
            )),
            config['routing']['rules'].index(next(
                rule for rule in config['routing']['rules'] if 'domain:gstatic.com' in rule.get('domain', [])
            )),
        )
        self.assertEqual(config['routing']['domainStrategy'], 'IPIfNonMatch')

    def test_dpi_mode_rejects_missing_or_remote_proxy_endpoints(self):
        for value in (0, -1, 65536, True, '1080'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                HELPER.build_dpi_config('eth0', [], '9.9.9.9', value)
        for target in ('vpn', 'node', None):
            with self.subTest(target=target), self.assertRaises(ValueError):
                HELPER.validate_routing_rules([
                    {'type': 'field', 'domain': ['domain:example.com'], 'outboundTag': target},
                ], 'byedpi')

    def test_xray_log_level_is_allowlisted_without_enabling_file_sinks(self):
        for level in ('debug', 'info', 'warning', 'error', 'none'):
            with self.subTest(level=level):
                config = HELPER.build_config(
                    {'tag': 'proxy', 'protocol': 'vless'}, 'eth0', [], '9.9.9.9', level,
                )
                self.assertEqual(config['log']['loglevel'], level)
                self.assertEqual(config['log']['access'], 'none')
                self.assertEqual(config['log']['error'], 'none')
        for level in (None, '', 'DEBUG', 'verbose', 3):
            with self.subTest(level=level), self.assertRaises(ValueError):
                HELPER.validate_log_level(level)

    def test_xray_core_version_guard_is_validated_and_forwarded(self):
        guard = {'min': '26.9.9', 'max': '27.0.0'}
        self.assertEqual(HELPER.validate_version_guard(guard), guard)
        config = HELPER.build_config(
            {'tag': 'proxy', 'protocol': 'vless'}, 'eth0', [], '9.9.9.9',
            version=guard,
        )
        self.assertEqual(config['version'], guard)
        self.assertIsNone(HELPER.validate_version_guard(None))
        self.assertIsNone(HELPER.validate_version_guard({'min': '', 'max': ''}))
        for value in (
            {'min': '26.9'},
            {'minimum': '26.9.9'},
            {'min': '27.0.0', 'max': '26.9.9'},
            {'max': 26},
        ):
            with self.subTest(value=value), self.assertRaises(ValueError):
                HELPER.validate_version_guard(value)

    def test_mux_is_allowlisted_and_vision_incompatibility_is_rejected(self):
        disabled = {
            'enabled': False,
            'concurrency': 8,
            'xudpConcurrency': -1,
            'xudpProxyUDP443': 'skip',
        }
        self.assertEqual(HELPER.validate_mux(disabled, 'xtls-rprx-vision'), disabled)
        enabled = {**disabled, 'enabled': True, 'xudpConcurrency': 16}
        with self.assertRaises(ValueError):
            HELPER.validate_mux(enabled, 'xtls-rprx-vision')
        with self.assertRaises(ValueError):
            HELPER.validate_mux({**enabled, 'file': '/tmp/config'}, '')
        with self.assertRaises(ValueError):
            HELPER.validate_mux({**enabled, 'concurrency': 129}, '')

    def test_tcp_socket_settings_are_allowlisted_and_bounded(self):
        settings = {
            'tcpFastOpen': True,
            'tcpKeepAliveIdle': 120,
            'tcpKeepAliveInterval': 30,
        }
        self.assertEqual(HELPER.validate_tcp_sockopt(settings), settings)
        for invalid in (
            {'tcpFastOpen': 1},
            {'tcpKeepAliveIdle': True},
            {'tcpKeepAliveInterval': 86401},
            {'mark': 1},
        ):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                HELPER.validate_tcp_sockopt(invalid)

    def test_vless_transport_settings_are_preserved_for_supported_networks(self):
        cases = [
            ('tcp', 'reality', {'tcpSettings': {'header': {'type': 'none'}}}),
            ('xhttp', 'reality', {
                'xhttpSettings': {
                    'path': '/edge', 'mode': 'auto',
                    'extra': {'xmux': {'maxConcurrency': '4-8'}},
                },
            }),
            ('grpc', 'tls', {
                'grpcSettings': {'serviceName': 'edge', 'multiMode': True},
                'tlsSettings': {
                    'serverName': 'cdn.example',
                    'enableSessionResumption': True,
                },
            }),
        ]
        for network, security, extra in cases:
            with self.subTest(network=network, security=security):
                stream = {'network': network, 'security': security, **extra}
                if security == 'reality':
                    stream['realitySettings'] = {
                        'serverName': 'cdn.example', 'publicKey': 'key',
                        'shortId': 'a1b2', 'fingerprint': 'chrome',
                    }
                validated = HELPER.validate_transport_settings(
                    stream, network, security,
                )
                for key, value in extra.items():
                    self.assertEqual(validated[key], value)

    def test_plain_tcp_transport_and_tls_defaults_are_preserved(self):
        stream = HELPER.validate_transport_settings(
            {
                'network': 'tcp', 'security': 'none',
                'tcpSettings': {'header': {'type': 'none'}},
                'sockopt': {'tcpFastOpen': True, 'tcpKeepAliveIdle': 30},
            }, 'tcp', 'none',
        )
        self.assertEqual(stream['network'], 'tcp')
        self.assertEqual(stream['security'], 'none')
        self.assertEqual(stream['tcpSettings'], {'header': {'type': 'none'}})
        self.assertEqual(
            stream['sockopt'],
            {'tcpFastOpen': True, 'tcpKeepAliveIdle': 30},
        )

    def test_transport_validation_rejects_privileged_files_and_unknown_fields(self):
        with self.assertRaises(ValueError):
            HELPER.validate_transport_settings(
                {
                    'network': 'tcp', 'security': 'tls',
                    'tlsSettings': {'masterKeyLog': '/tmp/session.keys'},
                }, 'tcp', 'tls',
            )
        with self.assertRaises(ValueError):
            HELPER.validate_transport_settings(
                {
                    'network': 'xhttp', 'security': 'reality',
                    'xhttpSettings': {'path': '/', 'dialerProxy': 'direct'},
                    'realitySettings': {'serverName': 'cdn.example'},
                }, 'xhttp', 'reality',
            )
        with self.assertRaises(ValueError):
            HELPER.validate_transport_settings(
                {
                    'network': 'tcp', 'security': 'reality',
                    'realitySettings': {'serverName': 'cdn.example'},
                    'untrustedTopLevel': True,
                }, 'tcp', 'reality',
            )

    def test_transport_settings_reject_non_finite_numbers(self):
        with self.assertRaises(ValueError):
            HELPER.validate_transport_settings(
                {
                    'network': 'xhttp', 'security': 'reality',
                    'xhttpSettings': {'extra': {'ratio': math.nan}},
                    'realitySettings': {'serverName': 'cdn.example'},
                }, 'xhttp', 'reality',
            )

    def test_nested_transport_cannot_override_root_network_or_listeners(self):
        for forbidden in ('interface', 'listen', 'outbounds', 'routing', 'mark'):
            with self.subTest(setting=forbidden), self.assertRaises(ValueError):
                HELPER.validate_transport_settings(
                    {
                        'network': 'xhttp', 'security': 'reality',
                        'xhttpSettings': {'extra': {forbidden: 'lo'}},
                        'realitySettings': {'serverName': 'cdn.example'},
                    }, 'xhttp', 'reality',
                )

    def test_vless_vision_udp443_multiplexing_is_rejected(self):
        mux = {
            'enabled': True,
            'concurrency': 8,
            'xudpConcurrency': -1,
            'xudpProxyUDP443': 'skip',
        }
        with self.assertRaises(ValueError):
            HELPER.validate_mux(mux, 'xtls-rprx-vision-udp443')


if __name__ == '__main__':
    unittest.main()
