# DPI Bypass strategy selection

DPI Bypass remains a client-owned local SOCKS outbound selected by Xray. It introduces no additional TUN or routing stack.

## Automatic (engine profile 4)

The bundled ByeDPI engine first sends its built-in decoy ClientHello at TTL 8, then attempts the real destination. If a TLS ClientHello receives no server response for five seconds, the engine retries the actual destination with four strategy groups: split `1+s`; split `1+s` plus disorder `3+s`; disorder `1+s`; disorder `1+s` plus split `3+s`. TCP resets, upstream connection failures, and invalid TLS responses also advance to the next group. ByeDPI learns groups in its own destination cache. This does not detect every possible censorship mechanism or guarantee that every target opens.

Google/Cloudflare HTTPS probes remain forwarding/readiness checks only. Native runtimes no longer run a global profile-selection loop or save a profile based on those probes. CONNECTED indicates forwarding readiness, not a claim that censorship was defeated.

## Manual profiles

User-facing Split, Split & reorder, Reorder, and Reorder & split map to pinned engine profiles 0–3. Labels describe the method, not a guaranteed strength ranking. The runtime never substitutes another profile because a generic connectivity check passes or fails. Choice is persisted under `connection.dpi.strategy.v1`; absent/invalid values default to automatic. Changes apply after reconnection.

`oculveDpiProfile` is private client metadata in the generated configuration. Apple and Windows consume and remove it before starting Xray; Android uses the existing channel profile argument and strips metadata; Linux reconstructs Xray configuration from its validated request and uses the same profile argument. Managed loopback port, socket protection, physical interface binding, DNS and existing routing stay in the platform runtimes.

## Retry

Retry restarts an active DPI session through the existing disconnect/connect flow, destroying the engine's in-memory learned groups. It preserves a manually selected profile. When disconnected there is no running engine cache to clear. The control is disabled while connecting/disconnecting; it does not create a connection if another server is selected. Restoring connection defaults returns strategy selection to Automatic.

## Validation

Flutter tests cover persisted settings, cyclic selection in English/Turkish/Spanish, native profile arguments and existing connection flows. ByeDPI engine tests start/stop all five modes. Android instrumentation verifies that the real JNI engine retries against a local TLS endpoint that remains silent; this is a controlled fixture, not ISP censorship proof. Pure Linux configuration tests and an Apple runtime harness validate strategy/metadata boundaries. Full Android VPN routing, Windows native execution, signed Apple Packet Tunnel networking, and real blocked-site behavior require platform/live-network validation.
