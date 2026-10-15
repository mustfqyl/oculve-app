#!/usr/bin/env bash
# Real production Swift framing against slow-drip loopback peers.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$root/build/apple_socket_deadlines"
if [[ "${1:-}" == --baseline ]]; then work="$work-baseline"; fi
mkdir -p "$work"
python3 - "$root" "$work" "${1:-}" <<'PY'
from pathlib import Path
import socket, subprocess, sys, threading, time
root, work = map(Path, sys.argv[1:3])
baseline = sys.argv[3] == '--baseline'
main = r'''
import Foundation
import Darwin
let port = Int(CommandLine.arguments[2])!
let start = DispatchTime.now().uptimeNanoseconds
do {
    let fd: Int32
    if CommandLine.arguments[1] == "socks" {
        fd = try LocalSOCKS5Client.openConnection(proxyPort: port, credentials: nil,
            host: "deadline.invalid", port: 80, timeout: 0.15)
    } else {
        fd = try LocalHTTPProxyClient.openConnection(proxyPort: port, credentials: nil,
            host: "deadline.invalid", port: 80, timeout: 0.15)
    }
    close(fd)
    print("SUCCEEDED")
} catch { print("TIMED_OUT") }
print("ELAPSED_MS=\((DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)")
'''
(work/'main.swift').write_text(main)
folders = {
 'ios': root/'ios/flutter_vless/Sources/flutter_vless_privacy',
 'macos': root/'packages/flutter_vless_macos/macos/flutter_vless_macos/Sources/flutter_vless_macos_privacy',
}
for platform, folder in folders.items():
    compiled = []
    for name in ['LocalProxyAccessPolicy.swift', 'LocalSOCKS5Client.swift', 'LocalHTTPProxyClient.swift', 'LocalProxyDelayClient.swift']:
        target = work/f'{platform}-{name}'
        if baseline:
            source = subprocess.check_output(['git', 'show', f'HEAD:{(folder/name).relative_to(root.parent.parent)}'], cwd=root.parent.parent, text=True)
        else:
            source = (folder/name).read_text()
        target.write_text(source); compiled.append(str(target))
    binary = work/platform
    subprocess.run(['xcrun', 'swiftc', '-O', *compiled, str(work/'main.swift'), '-o', str(binary)], check=True)
    for protocol in ['socks', 'http']:
        listener = socket.socket()
        listener.bind(('127.0.0.1', 0)); listener.listen(1); listener.settimeout(3)
        def peer():
            try:
                client, _ = listener.accept()
                with client:
                    client.settimeout(3)
                    def readn(count):
                        data = b''
                        while len(data) < count:
                            chunk = client.recv(count-len(data))
                            if not chunk: raise EOFError()
                            data += chunk
                        return data
                    if protocol == 'socks':
                        assert readn(3) == bytes([5, 1, 0])
                        client.sendall(bytes([5, 0]))
                        assert readn(4) == bytes([5, 1, 0, 3])
                        size = readn(1)[0]; readn(size + 2)
                        reply = bytes([5, 0, 0, 1, 127, 0, 0, 1, 1, 1])
                    else:
                        request = b''
                        while not request.endswith(b'\r\n\r\n'): request += readn(1)
                        reply = b'HTTP/1.1 200 Connection Established\r\n\r\n'
                    for byte in reply:
                        time.sleep(.03); client.sendall(bytes([byte]))
            except (OSError, EOFError): pass
        thread = threading.Thread(target=peer, daemon=True); thread.start()
        try:
            result = subprocess.check_output([str(binary), protocol, str(listener.getsockname()[1])], text=True, timeout=3).strip()
            print(platform, protocol, result.replace('\n', ' '), flush=True)
            if not baseline:
                assert result.startswith('TIMED_OUT'), result
                assert int(result.split('ELAPSED_MS=')[1]) < 1000, result
        finally:
            listener.close(); thread.join(3)
PY
