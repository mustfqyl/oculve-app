# iOS setup

Oculve uses Xray through an iOS Packet Tunnel extension. The project already contains the XrayTunnel target and its provider source; do not add a second Network Extension target.

## Prepare the Flutter and Xcode projects

From the repository root, run:

    flutter pub get
    flutter build ios --simulator --debug --config-only
    ./tool/prepare_ios_vpn.sh
    cd ios
    pod install
    open Runner.xcworkspace

The preparation script updates Flutter's generated Swift package to the Xray runtime's iOS 15 minimum. Run it again after flutter pub get regenerates those files.

## Signing and capabilities

Use these identifiers:

- App: **com.oculve.app**
- Packet Tunnel: **com.oculve.app.XrayTunnel**
- App Group: **group.com.oculve.app**

A device VPN build requires a paid Apple Developer membership and matching provisioning profiles. Enable the Network Extension capability with Packet Tunnel for the XrayTunnel target. Enable the App Groups capability for both Runner and XrayTunnel, using the App Group above. Keep the bundle IDs and entitlements consistent with the project files.

## Build

Select the Runner scheme, configure the Apple Development team and provisioning profiles, then build for a connected iPhone. Simulator builds can check app compilation, but they do not validate a signed, device-level VPN tunnel.
