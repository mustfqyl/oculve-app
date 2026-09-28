#!/bin/sh
set -eu
# Run from the repository root after tool/prepare_desktop.py linux.
# Keep the privileged helper and runtime root-owned and non-writable by users.
[ "$(id -u)" = 0 ] || { echo 'Run this installer with sudo.' >&2; exit 1; }
[ -f linux/xray/xray ] && [ -f linux/xray/byedpi ] || { echo 'Prepare the Linux runtime first.' >&2; exit 1; }
install -d -o root -g root -m 755 /usr/lib/oculve
install -d -o root -g root -m 700 /var/lib/oculve
install -o root -g root -m 755 native/linux/oculve-tunnel /usr/lib/oculve/oculve-tunnel
install -o root -g root -m 755 linux/xray/xray /usr/lib/oculve/xray
install -o root -g root -m 755 linux/xray/byedpi /usr/lib/oculve/byedpi
install -o root -g root -m 644 native/linux/com.oculve.client.policy /usr/share/polkit-1/actions/com.oculve.client.policy
