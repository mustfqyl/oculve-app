# iOS Configuration

To complete the iOS setup, you **MUST** perform the following manual steps in Xcode:

1.  **Open Workspace**: Open `apps/mobile_flutter/ios/Runner.xcworkspace`.
2.  **Add Target**: File -> New -> Target -> Network Extension.
    -   Name: `NetworkExtension`
    -   Language: Swift
    -   Provider Type: Packet Tunnel
3.  **Delete Generated Files**: Remove the automatically created `PacketTunnelProvider.swift` in the *new target group*.
4.  **Add Source**: Drag and drop `apps/mobile_flutter/ios/NetworkExtension/PacketTunnelProvider.swift` into the `NetworkExtension` group in Xcode. Ensure "Target Membership" checks `NetworkExtension`.
5.  **Entitlements**:
    -   Add "App Groups" capability to BOTH `Runner` and `NetworkExtension` targets. Use group ID `group.com.securevpn`.
    -   Add "Network Extension" capability to `Runner` target with "Packet Tunnel".
6.  **Frameworks**:
    -   Link `SingBox.xcframework` (download from releases) to `NetworkExtension` target.
    -   Ensure "Embed & Sign" is selected.
7.  **Bundle ID**: ensure `protocolConfiguration.providerBundleIdentifier` in `SingboxNativePlugin.swift` matches the bundle ID of your extension target.

**Note**: The Flutter plugin assumes the extension bundle ID is `$(PRODUCT_BUNDLE_IDENTIFIER).NetworkExtension`. Adjust if necessary.
