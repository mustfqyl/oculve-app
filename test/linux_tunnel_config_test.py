"""Pure checks for the privileged Linux helper's routing boundary."""
from importlib.machinery import SourceFileLoader
from pathlib import Path
import unittest
import math


HELPER = SourceFileLoader(
    'oculve_tunnel',
    str(Path(__file__).resolve().parents[1] / 'native/linux/oculve-tunnel'),
).load_module()


class LinuxTunnelConfigTest(unittest.TestCase):
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
        self.assertEqual(config['outbounds'][-1]['protocol'], 'freedom')
        self.assertEqual(
            config['outbounds'][-1]['streamSettings']['sockopt']['interface'],
            'eth0',
        )
        self.assertEqual(
            config['routing']['rules'][1]['domain'], ['domain:example.com'],
        )
        self.assertTrue(config['inbounds'][0]['sniffing']['routeOnly'])
        self.assertEqual(
            config['routing']['rules'][0]['ip'], ['::/0'],
        )
        self.assertEqual(config['dns']['servers'], ['tcp://9.9.9.9'])

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
