# Oculve compatibility patch

Based on the BSD-licensed `passkeys_darwin` 0.4.5 from pub.dev. Original Dart
and authentication implementation files are unchanged.

The plugin registration class is `OculvePasskeysPlugin`, which delegates to the
upstream class only on macOS 13.5+ and iOS 16+. Older supported Oculve systems
keep TOTP; they do not require a raised application deployment target and do
not attempt to load an unavailable passkey implementation. The Dart availability
probe safely treats an unregistered native channel as unavailable.

`pubspec.yaml` removes the upstream workspace-only resolution declaration and
uses the compatibility registration class for both Apple platforms. Preserve
this wrapper when upgrading the upstream implementation.
