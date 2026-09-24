#!/usr/bin/env bash
set -euo pipefail

# Flutter regenerates this Swift package after pub get. Keep its deployment
# target aligned with the bundled Xray plugin before Xcode resolves packages.
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$project_root" <<'PY'
from pathlib import Path
import sys

package = Path(sys.argv[1]) / 'ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift'
if not package.exists():
    raise SystemExit('Flutter Swift package is missing. Run flutter pub get first.')

source = package.read_text()
if '.iOS("13.0")' in source:
    package.write_text(source.replace('.iOS("13.0")', '.iOS("15.0")', 1))
elif '.iOS("15.0")' not in source:
    raise SystemExit('Unexpected Flutter Swift package iOS version.')
PY
