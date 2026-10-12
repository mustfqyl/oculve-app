# DPI Bypass strategy selection

DPI Bypass remains a client-owned local SOCKS outbound selected by Xray. It introduces no additional TUN or routing stack.

## Automatic (engine profile 4)

The bundled ByeDPI engine starts with an unchanged destination connection. Four strategy groups follow, each triggered by `--auto torst,ssl_err`: split `1+s`; split `1+s` plus disorder `3+s`; disorder `1+s`; disorder `1+s` plus split `3+s`. ByeDPI retries the actual destination on the supported timeout/reset/TLS failure signals, and learns groups in its own destination cache. This does not detect every possible censorship mechanism or guarantee that every target opens.

Google/Cloudflare HTTPS probes remain forwarding/readiness checks only. Native runtimes no longer run a global profile-selection loop or save a profile based on those probes. CONNECTED indicates forwarding readiness, not a claim that censorship was defeated.

## Manual profiles

User-facing Split, Split & reorder, Reorder, and Reorder & split map to pinned engine profiles 0–3. Labels describe the method, not a guaranteed strength ranking. The runtime never substitutes another profile because a generic connectivity check passes or fails. Choice is persisted under `connection.dpi.strategy.v1`; absent/invalid values default to automatic. Changes apply after reconnection.

`oculveDpiProfile` is private client metadata in the generated configuration. Apple and Windows consume and remove it before starting Xray; Android uses the existing channel profile argument and strips metadata; Linux reconstructs Xray configuration from its validated request and uses the same profile argument. Managed loopback port, socket protection, physical interface binding, DNS and existing routing stay in the platform runtimes.

## Retry

Retry restarts an active DPI session through the existing disconnect/connect flow, destroying the engine's in-memory learned groups. It preserves a manually selected profile. When disconnected there is no running engine cache to clear. The control is disabled while connecting/disconnecting; it does not create a connection if another server is selected. Restoring connection defaults returns strategy selection to Automatic.

## Validation

Flutter tests cover persisted settings, cyclic selection in English/Turkish/Spanish, native profile arguments and existing connection flows. ByeDPI engine tests start/stop all five modes. A real local TLS test injects an initial connection reset and verifies automatic retry completes certificate-checked HTTPS to that same destination. This is a controlled failure test, not ISP censorship proof. Pure Linux configuration tests and an Apple runtime harness validate strategy/metadata boundaries. Android and Windows full native execution, signed Apple Packet Tunnel networking, and real blocked-site behavior require platform/live-network validation.
