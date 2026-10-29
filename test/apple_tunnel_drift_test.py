"""Guards the Swift sources shared by the iOS and macOS flutter_vless trees."""

from pathlib import Path
import tempfile
import unittest


PKG = Path(__file__).resolve().parents[1] / "vendor/flutter_vless"
IOS = PKG / "ios/flutter_vless/Sources"
MACOS = PKG / "packages/flutter_vless_macos/macos/flutter_vless_macos/Sources"

# (ios dir, macos dir) per module; file names are identical on both sides.
CORE = ("flutter_vless", "flutter_vless_macos")
PRIVACY = ("flutter_vless_privacy", "flutter_vless_macos_privacy")
TUNNEL = ("flutter_vless_tunnel_support", "flutter_vless_macos_tunnel_support")

# Must stay byte-identical in both trees.
IDENTICAL = [
    (CORE, "BoundedNativeLogStore"),
    (CORE, "NativeOperationQueue"),
    (PRIVACY, "LocalSOCKS5Client"),
    (PRIVACY, "LocalHTTPProxyClient"),
    (PRIVACY, "LocalProxyDelayClient"),
    (PRIVACY, "TunnelSecretStore"),
    (TUNNEL, "TunnelRuntimeSupport"),
    (TUNNEL, "TunnelHEVLogPolicy"),
    (TUNNEL, "TunnelOnDemandPolicy"),
]

# Identical except the privacy module import name.
IMPORT_NORMALIZED = [
    (TUNNEL, "TunnelConfigKeys"),
    (TUNNEL, "TunnelIPv6Policy"),
]

# Deliberately different per platform; only existence is enforced.
DIVERGENT = [
    (TUNNEL, "TunnelDpiRuntime"),  # iOS NWPathMonitor vs macOS interface handling
    (TUNNEL, "TunnelXrayConfigPreparer"),  # platform-specific config rules
    (TUNNEL, "TunnelDNSPolicy"),  # platform DNS servers
    (PRIVACY, "LocalProxyAccessPolicy"),  # macOS exposes a local endpoint
    (PRIVACY, "XrayPrivacyConfig"),  # platform-specific inbound/outbound setup
    (PRIVACY, "NativeDiagnostics"),  # platform-specific stage reporting
]

# Exist only on macOS (iOS uses NEPacketTunnelFlow / system routing instead).
MACOS_ONLY = [
    (TUNNEL, "TunnelEndpointResolver"),
    (TUNNEL, "TunnelPacketBridge"),
    (PRIVACY, "DesktopBypassPolicy"),
]

PACKET_TUNNEL_PROVIDERS = [
    PKG / "ios/flutter_vless/Sources/flutter_vless_tunnel_support/TunnelSupport.swift",
    MACOS / "flutter_vless_macos_tunnel_support/FlutterVlessPacketTunnelProvider.swift",
]


def ios_path(pair, name):
    return IOS / pair[0] / f"{name}.swift"


def macos_path(pair, name):
    return MACOS / pair[1] / f"{name}.swift"


def normalize(text):
    return text.replace("flutter_vless_macos_privacy", "flutter_vless_privacy")


def differs(left, right, transform=lambda text: text):
    return transform(left.read_bytes().decode()) != transform(right.read_bytes().decode())


class AppleTunnelDriftTest(unittest.TestCase):
    def test_identical_sources_match_byte_for_byte(self):
        for pair, name in IDENTICAL:
            with self.subTest(name=name):
                left, right = ios_path(pair, name), macos_path(pair, name)
                self.assertTrue(left.exists(), left)
                self.assertTrue(right.exists(), right)
                self.assertEqual(left.read_bytes(), right.read_bytes(), f"{name} drifted")

    def test_import_normalized_sources_match(self):
        for pair, name in IMPORT_NORMALIZED:
            with self.subTest(name=name):
                left, right = ios_path(pair, name), macos_path(pair, name)
                self.assertFalse(differs(left, right, normalize), f"{name} drifted")

    def test_divergent_sources_exist_on_both_platforms(self):
        for pair, name in DIVERGENT:
            with self.subTest(name=name):
                self.assertTrue(ios_path(pair, name).exists())
                self.assertTrue(macos_path(pair, name).exists())

    def test_macos_only_sources_exist(self):
        for pair, name in MACOS_ONLY:
            with self.subTest(name=name):
                self.assertTrue(macos_path(pair, name).exists())

    def test_packet_tunnel_providers_exist(self):
        for path in PACKET_TUNNEL_PROVIDERS:
            with self.subTest(path=path.name):
                self.assertTrue(path.exists(), path)

    def test_comparison_detects_difference(self):
        with tempfile.TemporaryDirectory() as tmp:
            a, b = Path(tmp, "a.swift"), Path(tmp, "b.swift")
            a.write_text("import flutter_vless_privacy\nlet x = 1\n")
            b.write_text("import flutter_vless_macos_privacy\nlet x = 2\n")
            self.assertTrue(differs(a, b))
            self.assertTrue(differs(a, b, normalize))
            b.write_text("import flutter_vless_macos_privacy\nlet x = 1\n")
            self.assertTrue(differs(a, b))
            self.assertFalse(differs(a, b, normalize))


if __name__ == "__main__":
    unittest.main()
