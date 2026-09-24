#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
template="$repo_root/assets/tray_icon_status_template.svg"
temporary_svg="${TMPDIR:-/tmp}/oculve-tray-status-$$.svg"
trap 'rm -f "$temporary_svg"' EXIT

render_icon() {
  name=$1
  radius=$2
  color=$3
  opacity=$4
  sed \
    -e "s/__DOT_RADIUS__/$radius/g" \
    -e "s/__DOT_COLOR__/$color/g" \
    -e "s/__DOT_OPACITY__/$opacity/g" \
    "$template" > "$temporary_svg"
  sips -s format png "$temporary_svg" --out "$repo_root/assets/tray_icon_$name.png" >/dev/null
}

render_icon idle 0 '#48d6a0' 0
render_icon connected_0 4.0 '#48d6a0' 0.58
render_icon connected_1 4.8 '#48d6a0' 0.64
render_icon connected_2 5.6 '#48d6a0' 0.70
render_icon connected_3 6.4 '#48d6a0' 0.78
render_icon connected_4 7.2 '#48d6a0' 0.88
render_icon connected_5 8.0 '#48d6a0' 1.00
render_icon connected_6 7.2 '#48d6a0' 0.94
render_icon connected_7 6.4 '#48d6a0' 0.86
render_icon connected_8 5.6 '#48d6a0' 0.78
render_icon connected_9 4.8 '#48d6a0' 0.70
render_icon connected_10 4.0 '#48d6a0' 0.64
render_icon connected_11 4.0 '#48d6a0' 0.60
render_icon error 7 '#f04452' 1
