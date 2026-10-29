# Device verification result

> **CONNECTED means forwarding readiness only. It does not mean censorship was bypassed.**
> Results below prove only what was measured on this device and build. Unmeasured items must be `not run`, never `pass`.

Copy this file per run (for example `build/device-results/<date>-<device>.md`). Do not commit pcaps containing personal traffic.

## Run info

| Field | Value |
|---|---|
| Date | |
| Tester | |
| Platform (Android / iOS / macOS) | |
| Device model | |
| OS version | |
| Build SHA (`git rev-parse HEAD`) | |
| Working tree clean? (`git status`) | |
| Build type (debug / release) | |
| Signing / provisioning (team, profile name, expiry; Android: keystore / debug) | |
| Server profile(s) used (name only, no credentials) | |
| Server IP(s) (for capture filters) | |
| Network(s) (Wi-Fi / cellular / carrier; IPv6 available?) | |
| Capture method (macOS tcpdump en0 / iOS rvictl / Android gateway or other) | |
| Always-on / lockdown state (Android) | |

## Evidence tags

- **D** = on-device evidence (recording, screenshot, device log)
- **L** = leak capture (pcap / tcpdump output)

## Results

Result: `pass` / `fail` / `not run`. A `fail` needs a note and a reference to the evidence. `n/a` only where the checklist says so.

| ID | Scenario | Result | Evidence tag(s) | Evidence file(s) | Measured value(s) | Notes |
|---|---|---|---|---|---|---|
| V-01 | Connect | | | | time-to-CONNECTED: | |
| V-02 | Disconnect | | | | | |
| V-03 | Wrong credentials | | | | | |
| V-04 | No network | | | | time-to-error: | |
| V-05 | Server switch, physical-interface silence | | | | non-server packets: | |
| V-06 | iOS protected switch (`oculve_replace`) | | | | switches ok / 5: leaks: | |
| V-07 | Invalid server switch, rollback | | | | server after net change: | |
| V-08 | Switch stop failure, watchdog recovery | | | | recovery time / none: | |
| V-09 | DNS leak | | | | physical :53 packets: | |
| V-10 | IPv6 leak | | | | global v6 packets: | |
| V-11 | WebRTC leak | | | | | |
| V-12 | Android lockdown ON, process kill | | | | leaked packets: | |
| V-13 | Android lockdown OFF, process kill (informational) | | | | leak window (s): | |
| V-14 | Apple extension killed | | | | leaked packets / recovery (s): | |
| V-15 | Apple on-demand setup race | | | | attempts / hit: | |
| V-16 | Sleep / wake | | | | wake-to-CONNECTED (s): | |
| V-17 | Wi-Fi to cellular and back | | | | median s (W→C / C→W): | |
| V-18 | Excluded apps | | | | | |
| V-19 | iOS extension memory peak | | | | peak MB per phase: | |

## Findings

List each `fail` with: item ID, observed behaviour, linked static trace item (`#N`), evidence file, suggested follow-up.

## Not established by this run

Unless explicitly measured above, this run does not establish: other devices or OS versions, other builds, live production servers, long-duration stability, or censorship-bypass effectiveness.
