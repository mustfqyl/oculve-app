#!/usr/bin/env bash
set -euo pipefail

# Recreate flutter_vless' macOS Network Extension wiring after `flutter pub get`.
# It intentionally runs before Xcode resolves Swift packages.
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

python3 - <<'PY'
from pathlib import Path

project = Path('macos/Runner.xcodeproj/project.pbxproj')
old = '../../../.pub-cache/hosted/pub.dev/flutter_vless_macos-1.1.6/macos/flutter_vless_macos'
new = 'Flutter/ephemeral/Packages/.packages/flutter_vless_macos-1.1.6'
project.write_text(project.read_text().replace(old, new))
PY

dart run flutter_vless:setup_macos_vpn \
  --bundle-id com.oculve.app \
  --group-id group.com.oculve.app

python3 - <<'PY'
from pathlib import Path

package = Path('macos/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift')
project = Path('macos/Runner.xcodeproj/project.pbxproj')

text = package.read_text()
if '.macOS("10.15")' in text:
    package.write_text(text.replace('.macOS("10.15")', '.macOS("13.0")', 1))
elif '.macOS("13.0")' not in text:
    raise SystemExit('Expected generated macOS platform declaration was not found.')
text = package.read_text()
lines = [
    line for line in text.splitlines()
    if 'flutter_vless_macos' not in line and 'flutter-vless-macos' not in line
]
package.write_text('\n'.join(lines) + '\n')

old = '../../../.pub-cache/hosted/pub.dev/flutter_vless_macos-1.1.6/macos/flutter_vless_macos'
new = 'Flutter/ephemeral/Packages/.packages/flutter_vless_macos-1.1.6'
text = project.read_text()
project.write_text(text.replace(old, new))
PY
