#!/usr/bin/env bash
# Long-lived actual Xray start/stop and localhost transfer resource observation.
# Requires test_macos_privacy_runtime.sh's already compiled support modules.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$root/build/macos_privacy_runtime_probe"
source="$root/packages/flutter_vless_macos/macos/flutter_vless_macos/Sources"
[[ -f "$work/modules/support.o" && -f "$work/main.swift" ]] || {
    echo 'Run test_macos_privacy_runtime.sh to prepare the real runtime fixture first.' >&2
    exit 1
}
python3 - "$work" <<'PY'
from pathlib import Path
import sys
work = Path(sys.argv[1])
source = (work/'main.swift').read_text()
entry = 'Task { await runModes() }; dispatchMain()'
assert entry in source
probe = r'''
func residentBytes() -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    return result == KERN_SUCCESS ? UInt64(info.resident_size) : 0
}
func openDescriptorCount() -> Int {
    (0..<2048).reduce(0) { $0 + (fcntl(Int32($1), F_GETFD) >= 0 ? 1 : 0) }
}
func runSoak() async {
    setbuf(stdout, nil)
    let cycles = Int(ProcessInfo.processInfo.environment["OCULVE_SOAK_CYCLES"] ?? "1000") ?? 1000
    let origin = LocalProbeOrigin(port: 18096)
    defer { origin.stop() }
    let raw: [String: Any] = [
        "inbounds": [["protocol": "socks", "listen": "127.0.0.1", "port": 18095]],
        "outbounds": [["protocol": "freedom", "tag": "direct",
                       "settings": ["redirect": "127.0.0.1:18096"]]],
        "log": ["loglevel": "none"]
    ]
    let runner = ProxyOnlyRunner()
    do {
        let config = try JSONSerialization.data(withJSONObject: raw)
        print("SOAK_BEGIN cycles=\(cycles) runtime=\(XRayGetVersion()) rss=\(residentBytes()) fds=\(openDescriptorCount())")
        for cycle in 1...max(1, cycles) {
            try runner.start(configData: config, geoAssetsDirectory: nil)
            do {
                let fd = try LocalSOCKS5Client.openConnection(proxyPort: 18095, credentials: nil,
                    host: "soak.invalid", port: 80)
                defer { close(fd) }
                guard LocalSOCKS5Client.sendAll(fd: fd, bytes: Array(
                    "GET / HTTP/1.1\r\nHost: soak.invalid\r\nConnection: close\r\n\r\n".utf8)),
                    let reply = LocalSOCKS5Client.receiveExactly(fd: fd, count: 12),
                    String(decoding: reply, as: UTF8.self).contains("204") else {
                    throw NSError(domain: "Soak", code: 1)
                }
                var transferred = false
                for _ in 0..<10 {
                    let stats = runner.queryTrafficStats()
                    if stats.upload > 0 && stats.download > 0 { transferred = true; break }
                    try await Task.sleep(nanoseconds: 50_000_000)
                }
                guard transferred else { throw NSError(domain: "Soak", code: 2) }
            }
            runner.stop()
            if cycle % 50 == 0 || cycle == cycles {
                print("SOAK_SAMPLE cycles=\(cycle) rss=\(residentBytes()) fds=\(openDescriptorCount()) requests=\(origin.state().0)")
            }
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        precondition(!origin.state().1, "Proxy credentials must not reach origin")
        print("SOAK_PASS cycles=\(cycles) rss=\(residentBytes()) fds=\(openDescriptorCount())")
        exit(0)
    } catch {
        runner.stop()
        print("SOAK_FAIL")
        exit(1)
    }
}
Task { await runSoak() }; dispatchMain()
'''
(work/'soak_source').mkdir(exist_ok=True)
(work/'soak_source/main.swift').write_text(source.replace(entry, probe))
PY
sdk="$(xcrun --sdk macosx --show-sdk-path)"
byedpi="$(swift build --package-path "$root/../byedpi" --build-system native --scratch-path "$work/byedpi" -c release --show-bin-path)"
objects=("$byedpi/ByeDpiEngine.build/"*.o)
xcrun swiftc -O -target "$(uname -m)-apple-macos13.0" -sdk "$sdk" \
    -I "$work/modules" -I "$byedpi/ByeDpiEngine.build" -I "$source/CXRay/include" \
    -framework AppKit -framework SystemConfiguration -framework NetworkExtension -lresolv \
    "$work/soak_source/main.swift" "$source/flutter_vless_macos/BoundedNativeLogStore.swift" \
    "$work/modules/privacy.o" "$work/modules/support.o" "${objects[@]}" \
    "$root/packages/flutter_vless_macos/macos/XRay.xcframework/macos-arm64_x86_64/libXRay.a" \
    -o "$work/soak"
"$work/soak"
