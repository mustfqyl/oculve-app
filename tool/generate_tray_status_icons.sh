#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
template="$repo_root/assets/tray_icon_status_template.svg"
temporary_svg="${TMPDIR:-/tmp}/oculve-tray-status-$$.svg"
trap 'rm -f "$temporary_svg"' EXIT

render_icon() {
  name=$1
  dot_r=$2
  dot_color=$3
  dot_op=$4
  glow_r=$5
  glow_op=$6
  sed \
    -e "s/__DOT_RADIUS__/$dot_r/g" \
    -e "s/__DOT_COLOR__/$dot_color/g" \
    -e "s/__DOT_OPACITY__/$dot_op/g" \
    -e "s/__GLOW_RADIUS__/$glow_r/g" \
    -e "s/__GLOW_OPACITY__/$glow_op/g" \
    "$template" > "$temporary_svg"
  sips -s format png "$temporary_svg" --out "$repo_root/assets/tray_icon_$name.png" >/dev/null
}

render_icon idle 0 '#48d6a0' 0 0 0
render_icon connected_0 2.80 '#48d6a0' 0.65 5.00 0.15
render_icon connected_1 2.88 '#48d6a0' 0.67 5.13 0.17
render_icon connected_2 3.10 '#48d6a0' 0.74 5.50 0.21
render_icon connected_3 3.40 '#48d6a0' 0.83 6.00 0.28
render_icon connected_4 3.70 '#48d6a0' 0.91 6.50 0.34
render_icon connected_5 3.92 '#48d6a0' 0.98 6.87 0.38
render_icon connected_6 4.00 '#48d6a0' 1.00 7.00 0.40
render_icon connected_7 3.92 '#48d6a0' 0.98 6.87 0.38
render_icon connected_8 3.70 '#48d6a0' 0.91 6.50 0.34
render_icon connected_9 3.40 '#48d6a0' 0.83 6.00 0.28
render_icon connected_10 3.10 '#48d6a0' 0.74 5.50 0.21
render_icon connected_11 2.88 '#48d6a0' 0.67 5.13 0.17
render_icon error 3.50 '#f04452' 1.00 6.00 0.30

# Copy platform specific icons
cp "$repo_root/assets/tray_icon_idle.png" "$repo_root/assets/tray_icon_macos.png"
cp "$repo_root/assets/tray_icon_idle.png" "$repo_root/assets/tray_icon_linux.png"

