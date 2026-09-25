# Oculve

Oculve is the customer VPN client for the existing Oculve portal and PasarGuard deployment. Users sign in with their portal access code, choose a location, and connect without copying a subscription URL.

The client accepts only VLESS + Reality + TCP/RAW profiles from the authenticated Oculve subscription. It discards subscription-supplied inbounds, routing, DNS, logging, and management APIs before starting Xray.

Connection settings are grouped into DNS and IP, split tunneling, advanced compatibility, and diagnostics. The client supports DNS provider and address-family choices, a validated list of sites to route directly, plus optional TLS fingerprint and ClientHello fragmentation controls for troubleshooting. These changes take effect after reconnect. The installed core version and bounded native diagnostics are visible in the app. Domain rules are verified against a real Xray process; the Linux helper reconstructs them from a small allowlisted request and binds direct sockets to the physical interface. DNS forwarding, split routing, and kill-switch behavior still need validation on each release platform before making broader guarantees.

The production API origin is `https://www.oculve.com`; the apex domain redirects
there, and the native client intentionally does not forward a session through a redirect.

## Current platform status

| Platform | Runtime path | Release prerequisite |
| --- | --- | --- |
| Android | Xray + Android VPN service | Android SDK and a signed release key |
| iOS | Xray Packet Tunnel extension | Paid Apple Developer membership, an App ID with Network Extension and App Groups |
| macOS | Xray Packet Tunnel extension | Apple signing plus the same capabilities |
| Windows | `flutter_vless` Xray/Wintun backend | Run `python3 tool/prepare_desktop.py windows` before building |
| Linux | Root-owned native Xray TUN helper | Run `python3 tool/prepare_desktop.py linux` then `sudo native/linux/install.sh` |

## Build from source

Install the Flutter stable SDK first. Platform builds also need their native toolchains:

- Android: Android SDK and JDK 17.
- Windows: Windows 10/11, Visual Studio 2022 with the Desktop development with C++ workload, and CMake.
- macOS/iOS: Xcode and CocoaPods. A signed device VPN additionally needs Apple Developer provisioning for Network Extensions and App Groups.
- Linux: GTK development packages, CMake, and Polkit for the managed TUN helper.

From the project root, fetch Flutter dependencies:

    flutter pub get

Android debug APK:

    flutter build apk --debug

Windows builds need the checksum-verified Xray, tun2socks, and Wintun runtime files before CMake configuration:

    python3 tool/prepare_desktop.py windows
    flutter build windows --debug

Release APKs and app bundles require a private release key. Provide it through
the `OCULVE_ANDROID_KEYSTORE`, `OCULVE_ANDROID_STORE_PASSWORD`,
`OCULVE_ANDROID_KEY_ALIAS`, and `OCULVE_ANDROID_KEY_PASSWORD` environment
variables when running Gradle. The keystore stays outside the repository, and
release packaging stops if those values are missing; debug builds need no key.

macOS packet-tunnel setup:

    flutter build macos --debug --config-only
    ./tool/prepare_macos_vpn.sh
    xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner -configuration Debug -derivedDataPath build/macos-unsigned CODE_SIGNING_ALLOWED=NO build

The app bundle ID is **com.oculve.app**; the packet-tunnel extension uses **com.oculve.app.XrayTunnel**, and both use the **group.com.oculve.app** App Group. Set matching identifiers and capabilities in the Apple Developer portal before signing a device build.

Linux runtime setup:

    python3 tool/prepare_desktop.py linux
    sudo native/linux/install.sh

The downloaded Windows and Linux runtime artifacts are intentionally excluded from Git and can be reproduced from the pinned checksums in tool/runtime-lock.json.

## Oculve API contract

The app uses the portal endpoints already present in the Oculve repository:

1. `POST /api/auth/login` with `{ "authCode": "XXXX-XXXX-XXXX" }`
2. `POST /api/auth/login/two-factor` when the first response requires it
3. `GET /api/user/me` for plan status and the private subscription URL
4. The returned subscription URL for the server list

The session is stored in the OS secure store. The application sends the session cookie only to the configured Oculve origin; it never forwards it to the subscription server or follows redirects while authenticated.

Access and TOTP recovery codes can be exported from the account flow. Desktop uses a native Save dialog; Android and iOS use the system share sheet. A generated mobile sharing file is removed when the share sheet closes. Saving a newly generated access code is still explicitly confirmed before account creation.

The default API origin is `https://www.oculve.com`. For a staging build use `--dart-define=OCULVE_API_ORIGIN=https://staging.example.com`.

## Cloudflare requirement

The native app must be able to reach the account and subscription endpoints without a browser challenge. If a WAF rule blocks native requests, scope any exception to the app API routes and keep Oculve's own rate limiting enabled.

## Verification

```sh
flutter analyze
XRAY_TEST_BINARY=/path/to/xray flutter test
```

The integration test creates a local VLESS + Reality + TCP/Vision server with the real Xray executable, verifies an HTTPS request through the tunnel, and checks that the latency indicator succeeds only after an HTTPS response through Xray. A separate test checks that an open TCP port without Reality does not show signal. The tests do not use an Oculve customer credential.

The routing integration test confirms that a selected domain reaches the internet through Xray's direct outbound while another domain still uses the selected (test-blocked) proxy outbound. Run `python3 -m unittest discover -s test -p '*_test.py'` for the Linux helper's privileged-request and physical-interface rules.

After `flutter pub get`, prepare the macOS packet-tunnel target before opening
the workspace in Xcode:

```sh
./tool/prepare_macos_vpn.sh
```

The script creates the extension and applies the macOS 13 requirement of the
Xray runtime to Flutter's generated Swift package.

Before preparing an iOS build, generate the Xcode project configuration and
align Flutter's Swift package with the Xray plugin's iOS 15 minimum:

    flutter build ios --simulator --debug --config-only
    ./tool/prepare_ios_vpn.sh

An unsigned simulator build verifies compilation, but a signed device VPN
requires Apple Developer Network Extension and App Group capabilities.

An unsigned macOS build can be compiled with:

```sh
xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner \
  -configuration Debug -derivedDataPath build/macos-unsigned \
  CODE_SIGNING_ALLOWED=NO build
```
