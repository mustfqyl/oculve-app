# macOS setup

Oculve uses Xray through a macOS Packet Tunnel extension. The project already contains the XrayTunnel target and provider source; do not add a second Network Extension target.

## Prepare the Flutter and Xcode projects

From the repository root, run:

    flutter pub get
    flutter build macos --debug --config-only
    ./tool/prepare_macos_vpn.sh
    cd macos
    pod install
    open Runner.xcworkspace

The preparation script creates the extension wiring and aligns Flutter's generated Swift package with the Xray runtime's macOS 13 minimum. Run it again after flutter pub get regenerates those files.

## Signing and capabilities

Use these identifiers:

- App: **com.oculve.app**
- Packet Tunnel: **com.oculve.app.XrayTunnel**
- App Group: **group.com.oculve.app**

A signed system VPN requires Apple Developer provisioning with Network Extension and App Groups enabled. Assign the App Group to both Runner and XrayTunnel, and make sure the extension identifier matches the app's extension bundle identifier.

## Build

Select the Runner scheme and configure the Apple Development team and provisioning profiles to run the signed app. An unsigned local debug build can be compiled with:

    xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner -configuration Debug -derivedDataPath build/macos-unsigned CODE_SIGNING_ALLOWED=NO build
