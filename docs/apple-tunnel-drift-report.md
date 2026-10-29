# Apple tunnel drift report (PLAN step 7a)

Evidence type: S (static reading by the architect agent). The agent had no shell, so `diff`/`cmp` were NOT run; "identical" below is a reading result and is re-checked mechanically by `test/apple_tunnel_drift_test.py`. Nothing here is device-verified. Classes: K = intentional platform difference, D = drift, H = defect.

Paths: iOS sources `vendor/flutter_vless/ios/flutter_vless/Sources/...`; macOS sources `vendor/flutter_vless/packages/flutter_vless_macos/macos/flutter_vless_macos/Sources/...`.

## Shared files

| File | Lines iOS/mac | Identical | Difference | Class |
|---|---|---|---|---|
| TunnelRuntimeSupport, TunnelHEVLogPolicy, TunnelOnDemandPolicy, TunnelSecretStore, LocalSOCKS5Client, LocalHTTPProxyClient, LocalProxyDelayClient, BoundedNativeLogStore, NativeOperationQueue | equal | yes | none | - |
| TunnelConfigKeys, TunnelIPv6Policy | 80/80, 50/50 | import name only | `flutter_vless_privacy` vs `flutter_vless_macos_privacy` | K |
| NativeDiagnostics | 109/115 | no | macOS has 6 extra "System proxy ..." events | K |
| TunnelDpiRuntime | 142/170 | no | macOS passes the utun fd to Xray `tun` inbound in DPI mode (no HEV) | K |
| TunnelXrayConfigPreparer | 386/314 | no | different failure codes, sync vs async (25 s bound, 64 host limit) resolver, `switchRejection` richer on iOS | D |
| TunnelDNSPolicy | 258/210 | no | iOS adds the DoH IP to `addresses` (:108); macOS does not | D + H (iOS) |
| LocalProxyAccessPolicy | 159/158 | no | macOS requires `inbounds.count == 1`; iOS tolerates extra inbounds (e.g. dokodemo-door) | D (security relevant) |
| XrayPrivacyConfig | 119/121 | no | macOS strips top-level `api` and forces `stats = {}`; iOS keeps `api` | D, H candidate (iOS) |

macOS-only (K): TunnelEndpointResolver, TunnelPacketBridge, DesktopBypassPolicy.

## Providers
`ios/XrayTunnel/PacketTunnelProvider.swift` (~1010 lines) vs vendor macOS `FlutterVlessPacketTunnelProvider.swift` (~1020); `macos/XrayTunnel/PacketTunnelProvider.swift` is a 3-line subclass. Skeleton and function order match.

- K: imports/`open class`, `#available` (iOS 16.4 / macOS 13.3), `bypassSubnets` (iOS rejects, macOS applies), packet bridge and DPI TUN fd, `oculve_local_proxy` message returns local SOCKS credentials on macOS only (security note).
- H (macOS): `beginStartup()` runs after the DPI interface wait and has no `isStartupStopped` check, so a Stop arriving during the wait is lost; iOS checks before and after.
- D: endpoint resolution strategy and error logging, replace-time resolution (`try?` vs `try`), NWPathMonitor revalidation (iOS only on interface-name change), dead-HEV restart timing.

### Static-trace #7 (same on both platforms)
Replace calls `stopTunnelWatchdog` (iOS :421 / mac :439), which sets `watchdogSuspended`, stops timer and path monitor and clears `watchdogInboundPort` (iOS :720-732 / mac :778-790); then `guard stopped` throws (iOS :426 / mac :444). Restore exists only in the route-install catch (iOS :440 / mac :458). Correction to the trace: sleep/wake does not recover either, because `performTunnelHealthCheck` returns false while `watchdogInboundPort == nil`; the tunnel can stay `reasserting` until the system or on-demand restarts it. On macOS the packet bridge also stays paused (:350).

### Static-trace #8 (same on both platforms)
Plugin saves the new Keychain reference before the provider answers (iOS :1026-1050 / mac :1412-1436); on `rejected`/timeout it throws `invalidProfile` without restoring the old reference, so the next on-demand or cold start uses the rejected config.

## Defect candidates (not fixed; tunnel behaviour, needs your decision and device verification)
1. iOS DoH IP added to the tunnel-excluded `addresses` (TunnelDNSPolicy :108): app traffic to that IP may bypass the VPN. Align with macOS and add a test.
2. iOS XrayPrivacyConfig keeps `api`: an imported config's management listener could stay alive. Align with macOS.
3. LocalProxyAccessPolicy single-inbound rule differs; check existing configs before unifying.
4. macOS `beginStartup` ordering (lost Stop during DPI wait).
5. #7 on both: on `guard stopped` failure restart the watchdog and schedule recovery; resume bridge on macOS.
6. #8 on both: keep the old `providerConfiguration`, restore it on reject/timeout, delete the new reference.
7. Align NativeDiagnostics event set; port StartupFailure codes to macOS preparer.

## Recommendation for 7b
Do not merge the two provider trees now. 11 files are already identical; a drift check protects them cheaply. SPM product/module names differ, `prepare_*_vpn.sh` writes `Package.swift`/`project.pbxproj`, and the Xray (gomobile `XRay` vs `CXRay`) and HEV bridges differ. A merge could break both Apple builds and regressions would not show without signed-device tests. Fix defects 1-7 first, behind the device checklist (`docs/device-verification-checklist.md`).
