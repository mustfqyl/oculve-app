# Connection settings implementation QA — 2026-10-11

Approved visual reference: `/Users/mustfq/.codex/generated_images/01a1288e-408b-7821-b298-390c785b4f7c/exec-728e3b76-0c89-4967-be05-208bd07044e5.png`.

Implementation retains the existing Flutter app, Outfit typography, charcoal/navy background, muted labels, rounded groups and quiet hover controls. The old large accordion cards were replaced by compact rows. Custom HTTPS DNS is revealed only when Custom is selected; website bypass rules and TLS fragment ranges use dedicated pages. Startup remains in the main settings group.

User-approved additional scope: login startup, interrupted-session retries, system-managed macOS traffic protection, authenticated LAN HTTP/SOCKS5 proxy sharing, and redacted diagnostic export. Automatic connection at launch and a new preferred-server setting were not added.

## Visual inspection

Actual widget renders at the existing 320 × 568 desktop viewport, with production font assets, were inspected alongside the approved reference. English light/dark render files: `/tmp/oculve-connection-preview/connection-settings-dark.png` and `connection-settings-light.png`. These are Flutter widget renders, not native application screenshots. New detail screens were checked at the same compact size in English, Turkish and Spanish. Long button labels wrap in the LAN screen. Error overlays retain the underlying layout.

Intentional differences from the reference: additional requested sections require scrolling; fragmentation is only actionable for compatible VLESS Reality/TCP profiles; macOS uses IPv4 because the existing tunnel blocks IPv6. The UI states that limitation rather than presenting ineffective modes. Existing product background and header sizing are retained.

## Behavioral verification

197 Flutter tests passed, with 17 existing optional external-Xray integration checks skipped. Twelve Foundation/macOS DNS-policy tests passed in an isolated package using the repository policy sources, bypassing a stale full-plugin Swift-package artifact cache. Targeted compact-screen and interaction tests passed again after the final static IPv4-row change.

Real loopback socket tests exercise password-authenticated HTTP CONNECT, HTTP absolute-form requests and SOCKS5, authenticated upstream session negotiation, domain forwarding without local resolution, rejection of unauthenticated requests, private-interface restrictions and service shutdown. Retry tests verify resumption after interruption, disabling retries and manual-stop cancellation. Startup channel tests verify OS pending-approval and disable states. DNS persistence, safe URL validation, range validation and report redaction are covered.

The macOS Debug app and Packet Tunnel extension compile with code signing disabled and deployment target 13.0. Analyzer reports one preexisting unused authentication helper; new files and modified connection code introduce no analyzer issues.

## Remaining live verification boundary

The unsigned build does not establish signed NetworkExtension operation, traffic leak behavior during real outages, actual second-device LAN traffic through a live VPN, or launch after a real macOS login. Those behaviors need the signed app and real device/session verification. No startup registration or LAN port was enabled as part of this implementation. LAN proxy sharing is TCP-only and binds a selected private IPv4 interface while the VPN is ready; it does not create a Wi-Fi hotspot. Custom DNS uses protected DoH for A records; IPv6 and non-address DNS types return empty answers under the macOS tunnel policy.
