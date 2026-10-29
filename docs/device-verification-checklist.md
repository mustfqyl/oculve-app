# Device verification checklist (Android / iOS / macOS)

Purpose: manual, on-device verification of VPN behaviour that build and unit tests cannot prove. Nothing in this list has been run yet; every item starts as **not executed**. Record outcomes in `docs/device-verification-result-template.md` (one copy per run).

**CONNECTED means forwarding readiness only. It does not mean censorship was bypassed.** A passing item here proves the stated measurable criterion on the stated device and build, nothing more.

Static trace references (`#N`) point to `docs/device-static-trace.md` (source reading only, nothing was compiled or run). Trace file:line references may drift; re-check before relying on them.

## Conventions

- Evidence tags: **D** = on-device evidence (screen recording, screenshot, device log); **L** = leak capture (pcap / tcpdump output).
- Platform columns: **A** Android, **I** iOS, **M** macOS. `—` = not applicable.
- Use a signed build on a physical device (iOS/macOS VPN cannot be verified in the simulator). Note the build SHA.
- Capture setup:
  - macOS: `sudo tcpdump -i en0 -w <file>.pcap` (use the active physical interface; confirm with `route get default` before connecting).
  - iOS: `rvictl -s <UDID>` then `sudo tcpdump -i rvi0 -w <file>.pcap`; remove with `rvictl -x <UDID>`. rvi0 sees device traffic on the physical path; confirm in the pcap that tunnel-internal addresses (198.18.0.0/15, fd00:198:18::/64) are not mistaken for physical traffic.
  - Android: no on-device tcpdump without root. Preferred: Wi-Fi hotspot/router mirror or a laptop-shared network capturing at the gateway (`tcpdump -i <iface> host <phone-ip>`). Alternative (rooted/emulated only, mark as such): `adb shell tcpdump -i wlan0`. State the method used in the result.
- "Server IP" = the entry server's resolved address(es) for the profile under test. "Zero packets other than server IP" means a display filter such as `not host <server-ip>` returns 0 packets, excluding ARP/DHCP/NDP link housekeeping and mDNS to local-only addresses (list any excluded ones in the notes).
- Pass requires the criterion to be met and the evidence attached. Anything not measured is **not run**, never pass.

## Checklist

| ID | Scenario | Steps | Pass / fail criterion (measurable) | Evidence | Platforms | Trace |
|---|---|---|---|---|---|---|
| V-01 | Connect | 1. Fresh launch, signed in, valid profile. 2. Tap connect. 3. Time from tap to CONNECTED. 4. Open an IP-check page and one ordinary HTTPS site. | Pass: CONNECTED reached, observed exit IP equals the server's expected exit IP, site loads; time-to-CONNECTED recorded (no hard limit; record it). Fail: error, stuck state, or exit IP equals the physical-network IP. | D (recording + IP-check screenshot) | A I M | #12, #14 |
| V-02 | Disconnect | 1. From CONNECTED, tap disconnect. 2. Check IP page. 3. Android: VPN key icon gone; Apple: VPN status off in system settings. | Pass: UI shows disconnected within 10 s, exit IP equals the physical IP, system VPN indicator off, and no auto-reconnect within 2 min (on-demand disabled after explicit stop). Fail: any reconnect, or indicator still on. | D | A I M | #6, #11 |
| V-03 | Error: wrong credentials | 1. Sign out. 2. Sign in with a wrong password / invalid passkey. 3. Try to connect. | Pass: error message shown, no tunnel started, no VPN indicator, no profile saved. Fail: a tunnel starts or a stale profile connects. | D | A I M | — |
| V-04 | Error: no network | 1. Enable airplane mode. 2. Tap connect. 3. Disable airplane mode and tap connect again. | Pass: first attempt ends in a visible error (no indefinite spinner; record time-to-error), no crash; second attempt reaches CONNECTED. Fail: hang over 90 s, crash, or second attempt cannot connect without app restart. | D | A I M | #9 |
| V-05 | Server switch: physical-interface silence | 1. Connect to server A. 2. Start capture on the physical interface. 3. Switch to server B (valid). 4. Wait for CONNECTED. 5. Stop capture. | Pass: between the switch tap and CONNECTED on B, 0 packets on the physical interface to any destination other than the server A/B IPs (see conventions). Exit IP is B's. Fail: any other destination, including DNS or app traffic. | L (pcap) + D (timestamps of tap and CONNECTED) | A I M | #5, #8 |
| V-06 | iOS protected switch (`oculve_replace` path) | 1. Build with Step 1 changes (record SHA). 2. Connect on iOS device. 3. Switch server so the `oculve_replace` path runs (confirm via native stage diagnostics/log). 4. Repeat 5 times alternating A→B→A. 5. Capture via `rvictl` throughout. | Pass: 5/5 switches reach CONNECTED on the intended server; 0 non-server-IP packets on the physical path during every switch window; no extension crash. Fail: any failed switch, leak, or crash. This path has never run on a device, so a failure is a finding, not a flake. | L (pcap) + D (log showing `oculve_replace` used) | I | #7, #8 |
| V-07 | Switch to invalid server, rollback | 1. Connect to server A. 2. Switch to a deliberately invalid server (unreachable host or malformed config). 3. Observe state. 4. Change network (toggle Wi-Fi off/on) and observe which server is reconnected. 5. Capture physical interface throughout. | Pass: user sees an error; the tunnel stays up or fails closed (no plain traffic); after the network change the client reconnects to a known-good server (A), not the invalid one; 0 non-server-IP packets. Fail: stuck on invalid config, reconnect targets the rejected config, or any leak. Android sub-check: TUN stays open (#5 says TUN is preserved but config is not rolled back) — record whether traffic flows via A or is blocked. | L + D | A I M | #5 (A), #8 (I M) |
| V-08 | Switch stop failure, watchdog recovery | 1. Connect. 2. Induce "could not stop" during a protected switch (e.g. switch while the extension is busy/under packet load; record how it was induced). 3. Confirm the "could not stop" log line. 4. Wait 5 min with the device awake, no sleep/wake, no network change. | Pass: within 5 min the tunnel recovers to CONNECTED automatically or the UI shows a clear disconnected/error state with no leak. Fail: tunnel stays in a non-CONNECTED state with no recovery and no error after 5 min (trace #7 predicts watchdog stays suspended; this item exists to confirm or refute that). If the stop failure cannot be induced, mark **not run** with the reason. | D (log + timeline) + L | I M | #7 |
| V-09 | DNS leak | 1. Connect. 2. Capture the physical interface. 3. Browse 10 distinct fresh domains (cache-cleared). 4. Run a DNS leak test page. 5. Android: also capture during the connect phase. | Pass: 0 UDP/53 and 0 TCP/53 packets (and no DoH/DoT to resolvers) on the physical interface during browsing; leak test shows only the VPN-side resolver. Apple virtual DNS 198.18.0.2 is tunnel-internal and must not appear on the physical path. Android connect phase: only the server hostname is queried on the physical network. Fail: any other DNS query on the physical path. | L | A I M | #12, #14 |
| V-10 | IPv6 leak | 1. Connect on a network with working IPv6 (verify first without VPN). 2. Open an IPv6-only site and an IPv6 test page. 3. Capture physical interface filtered `ip6`. | Pass: no IPv6 packets leave the physical interface other than link-local housekeeping (NDP/RA); IPv6-only site fails or is blocked rather than loading directly; IPv6 test page shows no physical IPv6 address. Fail: any global IPv6 traffic to non-server addresses. If the network lacks IPv6, mark **not run**. | L | A I M | #3, #13 |
| V-11 | WebRTC leak | 1. Connect. 2. Open a WebRTC leak test in the platform browser. | Pass: no candidate shows the physical public or local-LAN IP; only the VPN exit address or none. Fail: physical IP exposed. | D (screenshot) | A I M | — |
| V-12 | Kill switch: Android lockdown ON | 1. Settings > VPN > Oculve: enable Always-on and "Block connections without VPN". 2. Connect. 3. Kill the service process (`adb shell am kill` / `adb shell pkill -f RunSoLibXrayDaemon`; check the real process name with `ps`). 4. During recovery, run continuous pings/HTTP to an external host and capture at the gateway. | Pass: 0 packets reach the physical interface (other than server IP) from process kill until CONNECTED returns; the service restarts. Fail: any plain traffic. Related existing test: `SessionSystemPolicyDeviceTest.kt` (not yet run). | L + D | A | #1, #2 |
| V-13 | Kill switch: Android lockdown OFF | Same as V-12 with Always-on off (default). | Result is **informational**, not pass/fail: record whether traffic leaks during the process-death window and for how long. If it leaks, the UI must not claim leak protection in this state. Fail only if UI claims protection that the capture contradicts. | L + D | A | #1, #2 |
| V-14 | Kill switch: Apple extension killed | 1. Connect (includeAllNetworks=true profile). 2. Kill the packet-tunnel extension process (Xcode Debug > Attach, or `kill` of the `XrayTunnel` pid on macOS). 3. Capture physical interface and run continuous HTTP for 2 min. | Pass: 0 non-server-IP packets between the kill and recovery; the OS restarts the tunnel (on-demand) or blocks traffic; reconnect to CONNECTED within 2 min. Fail: any plain traffic, or no recovery. OS behaviour on extension crash is unverified (trace #6); this item is the first verification. | L + D | I M | #6, #11 |
| V-15 | Apple on-demand setup race | 1. Disconnect. 2. Start connect and kill the extension during the window between route install and on-demand enablement (tight timing; retry up to 10 times, log each). 3. Observe whether on-demand is active afterwards. | Pass: in every attempt, either the tunnel reaches CONNECTED or traffic stays blocked and the app shows a recoverable state. Fail: tunnel gone, on-demand absent, and traffic flows plain. If the window cannot be hit in 10 attempts, mark **not run**. | L + D | I M | #11 |
| V-16 | Sleep / wake | 1. Connect. 2. Sleep the device 5 min (macOS: lid close or `pmset sleepnow`; iOS: lock screen). 3. Wake. 4. Capture physical interface across the whole cycle. | Pass: CONNECTED again within 30 s of wake without user action (record actual time); 0 non-server-IP packets from wake until CONNECTED; exit IP is the VPN's. Fail: manual action needed, or leak. | L + D | I M | #10 |
| V-17 | Wi-Fi to cellular and back | 1. Connect on Wi-Fi. 2. Disable Wi-Fi (cellular takes over); time until CONNECTED/traffic flows. 3. Re-enable Wi-Fi; time again. 4. Repeat 3 times each direction. macOS: use a USB/Wi-Fi tethered pair as the second path. | Pass: median time to restored traffic recorded for each direction; every run returns to CONNECTED without manual action within 120 s (threshold chosen from trace #9 worst case of 60 s x 3 failures; tighten once data exists); 0 non-server-IP packets during transitions. Fail: any run exceeds 120 s, needs manual action, or leaks. | D (timestamps) + L | A I M | #9 |
| V-18 | Excluded apps | 1. Settings: mark one app as excluded. 2. Connect. 3. In the excluded app and an included app, open an IP-check page. 4. Read the UI wording for exclusions. | Pass: excluded app shows the physical IP and the included app shows the VPN IP; UI states that excluded apps bypass the VPN. Fail: either IP is wrong, or the UI does not disclose the bypass. Apple has no equivalent setting: mark **not applicable** unless the app exposes one. | D (screenshots) + L | A | #4 |
| V-19 | iOS extension memory peak (baseline for Step 7b) | 1. Connect on a physical iOS device. 2. Attach Instruments (Allocations/Memory) or Xcode memory gauge to the `XrayTunnel` extension. 3. Run: idle 5 min; 4K video stream 10 min; heavy parallel browsing 5 min; one protected switch (V-06); sleep/wake. 4. Record peak resident/footprint MB per phase. | Report only: peak footprint MB per phase, device model, iOS version (Network Extension memory limit is OS/device dependent; record the jetsam threshold observed, if any). Fail: extension terminated by the OS (jetsam) in any phase. This sets the baseline for Step 7b; no threshold is assumed here. | D (Instruments trace / screenshot) | I | — |

## Trace coverage

Every trace item is linked to at least one test:

| Trace | Test items |
|---|---|
| #1 Android process death | V-12, V-13 |
| #2 Android lockdown | V-12, V-13 |
| #3 Android IPv6 | V-10 |
| #4 Excluded apps | V-18 |
| #5 Android live switch, no rollback | V-05, V-07 |
| #6 Apple includeAllNetworks / crash behaviour | V-02, V-14 |
| #7 Apple protected-switch stop failure | V-06, V-08 |
| #8 Apple replace, no rollback | V-05, V-06, V-07 |
| #9 Network change timing | V-04, V-17 |
| #10 Sleep / wake | V-16 |
| #11 On-demand setup order | V-02, V-14, V-15 |
| #12 Apple DNS | V-01, V-09 |
| #13 Apple IPv6 | V-10 |
| #14 Android DNS | V-01, V-09 |

## Out of scope

Windows and Linux (paused). Live production verification, store release, and censorship-bypass effectiveness are separate evidence and are not established by this list.
