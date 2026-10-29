"""Source contract for the flutter_vless method dispatchers on every platform."""

from collections import Counter
from pathlib import Path
import re
import unittest


PKG = Path(__file__).resolve().parents[1] / "vendor/flutter_vless"
SOURCES = {
    "android": PKG / "packages/flutter_vless_android/android/src/main/kotlin/com/github/tfox/flutter_vless/FlutterVlessPlugin.kt",
    "ios": PKG / "ios/flutter_vless/Sources/flutter_vless/FlutterVlessPlugin.swift",
    "macos": PKG / "packages/flutter_vless_macos/macos/flutter_vless_macos/Sources/flutter_vless_macos/FlutterVlessPlugin.swift",
    "windows": PKG / "packages/flutter_vless_windows/windows/flutter_vless_plugin.cpp",
}

COMMON = {
    "getConnectedServerDelay", "getCoreVersion", "getProviderDebugSnapshot",
    "getSecurityCapabilities", "getServerDelay", "initializeVless",
    "replaceVless", "requestPermission", "startVless", "stopVless",
}
MACOS_ONLY = {"getLocalProxyEndpoint", "getTrafficProtection"}
METHODS = {
    "android": COMMON,
    "ios": COMMON,
    "macos": COMMON | MACOS_ONLY,
    "windows": COMMON,
}
CAPABILITY_KEYS = {
    "android": {"protectedServerSwitch", "androidProxyDns", "iosKeychainReference"},
    "ios": {"protectedServerSwitch", "iosKeychainReference", "androidProxyDns"},
    "macos": {"protectedServerSwitch", "iosKeychainReference", "androidProxyDns"},
    "windows": {"protectedServerSwitch"},
}

# Dispatch lines: `"a", "b" ->` (Kotlin), `case "a", "b":` (Swift) and
# `if/else if (... method_name() == "a")` (C++).
KOTLIN = re.compile(r'^\s*("[A-Za-z]+"(?:\s*,\s*"[A-Za-z]+")*)\s*->')
SWIFT = re.compile(r'^\s*case\s+("[A-Za-z]+"(?:\s*,\s*"[A-Za-z]+")*)\s*:')
CPP = re.compile(r'^\s*(?:\}\s*)?(?:else\s+)?if\s*\(.*method_name\(\)')


def dispatched(platform, text):
    names = []
    for line in text.splitlines():
        if platform == "android":
            m = KOTLIN.match(line)
        elif platform in ("ios", "macos"):
            m = SWIFT.match(line)
        else:
            m = line if CPP.match(line) else None
        if m:
            source = m if platform == "windows" else m.group(1)
            names += re.findall(r'"([A-Za-z]+)"', source)
    return names


def capability_keys(platform, text):
    if platform == "android":
        line = re.search(r'"getSecurityCapabilities" ->.*', text).group(0)
        return set(re.findall(r'"(\w+)" to ', line))
    if platform == "windows":
        body = text.split('== "getSecurityCapabilities"', 1)[1].split("} else if", 1)[0]
        return set(re.findall(r'EncodableValue\("(\w+)"\), flutter::EncodableValue', body))
    body = re.search(r'case "getSecurityCapabilities":\s*result\(\[(.*?)\]\)', text, re.S).group(1)
    return set(re.findall(r'"(\w+)":', body))


class FlutterVlessDispatchContractTest(unittest.TestCase):
    def test_no_method_is_dispatched_twice(self):
        for platform, path in SOURCES.items():
            with self.subTest(platform=platform):
                names = dispatched(platform, path.read_text())
                self.assertTrue(names)
                self.assertEqual([n for n, c in Counter(names).items() if c > 1], [])

    def test_each_platform_dispatches_exactly_its_allowlist(self):
        for platform, path in SOURCES.items():
            with self.subTest(platform=platform):
                self.assertEqual(set(dispatched(platform, path.read_text())), METHODS[platform])

    def test_traffic_protection_and_local_proxy_are_macos_only(self):
        for platform in ("android", "ios", "windows"):
            text = SOURCES[platform].read_text()
            for name in MACOS_ONLY:
                self.assertNotIn(f'"{name}"', text, f"{platform} exposes {name}")

    def test_security_capability_keys_match_allowlist(self):
        for platform, path in SOURCES.items():
            with self.subTest(platform=platform):
                self.assertEqual(capability_keys(platform, path.read_text()), CAPABILITY_KEYS[platform])

    def test_detector_flags_duplicates_and_unexpected_methods(self):
        swift = 'case "a":\n  x\ncase "b", "a":\n  y\n'
        self.assertEqual(dispatched("ios", swift), ["a", "b", "a"])
        kotlin = '            "a" -> x\n            "b", "c" -> {\n'
        self.assertEqual(dispatched("android", kotlin), ["a", "b", "c"])
        cpp = '  if (m.method_name() == "a") {\n  } else if (m.method_name().compare("b") == 0) {\n'
        self.assertEqual(dispatched("windows", cpp), ["a", "b"])


if __name__ == "__main__":
    unittest.main()
