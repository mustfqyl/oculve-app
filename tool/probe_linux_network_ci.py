#!/usr/bin/env python3
"""Read-only capability probe for isolated Linux tunnel CI hosts."""
import os
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    checks = {
        'root': os.geteuid() == 0,
        'iproute2': shutil.which('ip') is not None,
        'nftables': shutil.which('nft') is not None,
        'tun_device': Path('/dev/net/tun').is_char_device(),
        'cgroup_v2': Path('/sys/fs/cgroup/cgroup.controllers').is_file(),
        'cgroup_writable': os.access('/sys/fs/cgroup', os.W_OK),
    }
    unshare = shutil.which('unshare')
    if unshare:
        result = subprocess.run(
            [unshare, '--net', 'true'], capture_output=True, timeout=5,
        )
        checks['network_namespace'] = result.returncode == 0
    else:
        checks['network_namespace'] = False
    nft = shutil.which('nft')
    if nft:
        result = subprocess.run([nft, 'list', 'ruleset'], capture_output=True, timeout=5)
        checks['nft_read_access'] = result.returncode == 0
    else:
        checks['nft_read_access'] = False

    available = all(checks.values())
    lines = ['Linux isolated-tunnel capability probe:']
    lines.extend(f'- {name}: {"available" if value else "missing"}'
                 for name, value in checks.items())
    lines.append(
        'Result: isolated OS-tunnel tests can run.' if available else
        'Result: do not run kernel/network tests on this host; use a disposable privileged VM or runner.'
    )
    report = '\n'.join(lines) + '\n'
    print(report, end='')
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as stream:
            stream.write(report)
    output = os.environ.get('GITHUB_OUTPUT')
    if output:
        with open(output, 'a', encoding='utf-8') as stream:
            stream.write(f'available={str(available).lower()}\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
