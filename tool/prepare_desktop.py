#!/usr/bin/env python3
"""Fetch pinned upstream runtimes, verify SHA-256, extract only required files."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import urllib.request
import zipfile

root = Path(__file__).resolve().parents[1]
lock = json.loads((root / 'tool/runtime-lock.json').read_text())
parser = argparse.ArgumentParser()
parser.add_argument('platform', choices=['windows', 'linux'])
args = parser.parse_args()
out = root / args.platform / 'xray'
out.mkdir(parents=True, exist_ok=True)
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
for file in required:
    if not (out / file).is_file(): raise SystemExit(f'Missing runtime file: {file}')
