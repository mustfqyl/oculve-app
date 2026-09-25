#!/usr/bin/env python3
"""Remove Flutter's duplicate macOS plugin package reference after generation."""

from pathlib import Path


package = (
    Path(__file__).resolve().parents[1]
    / "macos/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"
)
if not package.is_file():
    raise SystemExit(f"Generated Swift package was not found: {package}")

contents = package.read_text()
if '.macOS("10.15")' in contents:
    contents = contents.replace('.macOS("10.15")', '.macOS("13.0")', 1)
elif '.macOS("13.0")' not in contents:
    raise SystemExit("Expected macOS platform declaration was not found.")

lines = [
    line
    for line in contents.splitlines()
    if "flutter_vless_macos" not in line and "flutter-vless-macos" not in line
]
package.write_text("\n".join(lines) + "\n")
