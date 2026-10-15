#!/usr/bin/env bash
# Exercise production polling methods with an in-memory provider reply boundary.
# No NetworkExtension, Keychain, system proxy or host network changes.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$root/build/apple_traffic_polling_probe"
mkdir -p "$work"
python3 - "$root" "$work" "${1:-}" <<'PY'
from pathlib import Path
import subprocess
import sys
root, work = map(Path, sys.argv[1:3])
baseline = sys.argv[3] == '--baseline'
fixture = r'''
import Foundation
import os
let pluginLog = Logger(subsystem: "oculve.poll.fixture", category: "poll")
func pluginDebug(_ message: String) {}
enum NativeLogPrivacy {
    static func operationError(_ error: Error) -> NSError { error as NSError }
}
enum Status: Int { case invalid, disconnected, connected, reasserting }
actor Replies {
    var count = 0
    var waiting: [CheckedContinuation<Data?, Never>] = []
    func request() async -> Data? {
        count += 1
        return await withCheckedContinuation { waiting.append($0) }
    }
    func finish() {
        let pending = waiting; waiting = []
        for reply in pending { reply.resume(returning: Data("100,200".utf8)) }
    }
}
final class PacketTunnelManager {
    var status: Status? = .connected
    var connectedDate: Date? = Date()
    var isRecoveryEnabled = true
    let replies = Replies()
    func refreshForwardingState() async {}
    func sendProviderMessage(data: Data) async throws -> Data? { await replies.request() }
}
final class ProxyRunner {
    var isRunning = false
    var connectedDate: Date? = Date()
    func queryTrafficStats() -> (upload: Int64, download: Int64) { (0, 0) }
}
final class PollProbe {
    var timer: Timer?
    var trafficPollTask: Task<Void, Never>?
    var trafficPollRevision = 0
    let proxyOnlyRunner = ProxyRunner()
    let packetTunnelManager: PacketTunnelManager? = PacketTunnelManager()
    var eventSink: Any?
    var totalUpload = 0, totalDownload = 0, uploadSpeed = 0, downloadSpeed = 0
    var lastTrafficSampleTime = ProcessInfo.processInfo.systemUptime
    var lastTrafficLogDate = Date.distantPast
    var lastProviderDebugLogDate = Date.distantPast
    var lastNetworkSnapshotLogDate = Date.distantPast
    var lastAppNetworkProbeDate = Date.distantPast
    var didScheduleConnectedDiagnostics = false
    func emitStatus(duration: Int, state: String, reason: String) {}
    func currentRuntimeState() -> String { "CONNECTED" }
    func currentWireState() -> String { "CONNECTED" }
    func currentDurationSeconds() -> Int { 0 }
    func logSystemNetworkSnapshot(reason: String, force: Bool = false) {}
    func logProviderDebugSnapshot() {}
    func start() { startTimer() }
    func stop() { stopTimer() }
    func tick() { timer?.fire() }
'''
main = r'''
}
@main struct Main {
    @MainActor static func main() async throws {
        let probe = PollProbe()
        probe.start()
        try await Task.sleep(nanoseconds: 30_000_000)
        probe.tick()
        try await Task.sleep(nanoseconds: 30_000_000)
        probe.tick()
        try await Task.sleep(nanoseconds: 30_000_000)
        let queries = await probe.packetTunnelManager!.replies.count
        probe.stop()
        try await Task.sleep(nanoseconds: 30_000_000)
        await probe.packetTunnelManager!.replies.finish()
        try await Task.sleep(nanoseconds: 30_000_000)
        let slow = PollProbe()
        slow.start()
        slow.tick()
        try await Task.sleep(nanoseconds: 2_100_000_000)
        await slow.packetTunnelManager!.replies.finish()
        try await Task.sleep(nanoseconds: 30_000_000)
        precondition(slow.totalUpload == 100)
        precondition(slow.uploadSpeed >= 0 && slow.uploadSpeed <= 60, "A slow reply must report bytes per actual second")
        slow.stop()
        print("QUERIES=\(queries);UPLOAD=\(probe.totalUpload)")
    }
}
'''
paths = {
 'ios': root/'ios/flutter_vless/Sources/flutter_vless/FlutterVlessPlugin.swift',
 'macos': root/'packages/flutter_vless_macos/macos/flutter_vless_macos/Sources/flutter_vless_macos/FlutterVlessPlugin.swift',
}
for platform, path in paths.items():
    if baseline:
        source = subprocess.check_output(['git', 'show', f'HEAD:{path.relative_to(root.parent.parent)}'], cwd=root.parent.parent, text=True)
    else:
        source = path.read_text()
    start = source.index('    private func startTimer(')
    stop = source.index('    private func currentDurationSeconds()', start)
    swift = work/f'{platform}.swift'
    swift.write_text(fixture + source[start:stop] + main)
    binary = work/platform
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library', str(swift), '-o', str(binary)], check=True)
    result = subprocess.check_output([str(binary)], text=True).strip()
    print(platform, result, flush=True)
    if not baseline:
        assert result == 'QUERIES=1;UPLOAD=0', result
PY
