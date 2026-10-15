#!/usr/bin/env python3
"""Fetch pinned upstream runtimes, verify SHA-256, extract only required files."""
import argparse
import hashlib
import io
import json
import platform as host_platform
from pathlib import Path
import shutil
import subprocess
import sys
import urllib.request
import zipfile

root = Path(__file__).resolve().parents[1]
lock = json.loads((root / 'tool/runtime-lock.json').read_text())
parser = argparse.ArgumentParser()
parser.add_argument('platform', choices=['windows', 'linux'])
args = parser.parse_args()
if args.platform == 'linux' and (
    sys.platform != 'linux'
    or host_platform.machine().lower() not in ('x86_64', 'amd64')
):
    raise SystemExit(
        'Preparing the Linux VPN runtime requires a Linux x86_64 host; '
        'ByeDPI is built with the host compiler.'
    )
out = root / args.platform / 'xray'
out.mkdir(parents=True, exist_ok=True)
byedpi_license = root / 'vendor' / 'byedpi' / 'upstream' / 'LICENSE'
if not byedpi_license.is_file(): raise SystemExit('ByeDPI license file is missing')
shutil.copy2(byedpi_license, out / 'byedpi-LICENSE')
artifacts = ['xray-' + args.platform] + (['tun2socks-windows', 'wintun'] if args.platform == 'windows' else [])
for name in artifacts:
    item = lock[name]
    data = urllib.request.urlopen(item['url'], timeout=120).read()
    if hashlib.sha256(data).hexdigest() != item['sha256']:
        raise SystemExit(f'Checksum mismatch: {name}')
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        for file in archive.namelist():
            basename = Path(file).name
            target = None
            if basename in ('xray', 'xray.exe', 'geoip.dat', 'geosite.dat'):
                target = basename
            elif basename == 'tun2socks-windows-amd64.exe':
                target = 'tun2socks.exe'
            elif file == 'wintun/bin/amd64/wintun.dll':
                target = 'wintun.dll'
            elif basename.lower().startswith(('license', 'copying')):
                target = name + '-' + basename
            if target:
                (out / target).write_bytes(archive.read(file))
                if target == 'xray': (out / target).chmod(0o755)
    print(f'Verified {name}')
required = ['xray.exe', 'tun2socks.exe', 'wintun.dll'] if args.platform == 'windows' else ['xray']
if args.platform == 'linux':
    source = root / 'vendor' / 'byedpi' / 'upstream'
    subprocess.run(['make', 'clean', 'all'], cwd=source, check=True)
    binary = source / 'ciadpi'
    if not binary.is_file(): raise SystemExit('ByeDPI build did not produce a runtime')
    shutil.copy2(binary, out / 'byedpi')
    (out / 'byedpi').chmod(0o755)
    subprocess.run(['make', 'clean'], cwd=source, check=True)
    required.append('byedpi')
if args.platform == 'windows':
    source = root / 'vendor' / 'byedpi' / 'upstream'
    compiler = 'gcc' if sys.platform == 'win32' else 'x86_64-w64-mingw32-gcc'
    subprocess.run(['make', 'clean', 'windows', 'CC=' + compiler], cwd=source, check=True)
    binary = source / 'ciadpi.exe'
    if not binary.is_file(): raise SystemExit('ByeDPI Windows build did not produce a runtime')
    shutil.copy2(binary, out / 'byedpi.exe')
    subprocess.run(['make', 'clean'], cwd=source, check=True)
    required.append('byedpi.exe')
for file in required:
    if not (out / file).is_file(): raise SystemExit(f'Missing runtime file: {file}')
