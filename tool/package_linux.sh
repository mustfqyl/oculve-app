#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
bundle_dir=${OCULVE_LINUX_BUNDLE_DIR:-"$repo_root/build/linux/x64/release/bundle"}
runtime_dir=${OCULVE_LINUX_RUNTIME_DIR:-"$repo_root/linux/xray"}
archive=${OCULVE_LINUX_PACKAGE_OUTPUT:-"$repo_root/dist/Oculve-Linux-Test.tar.gz"}

for bundle_file in oculve lib/libflutter_linux_gtk.so lib/libapp.so; do
  if [ ! -s "$bundle_dir/$bundle_file" ]; then
    echo "Linux release bundle is missing $bundle_file in $bundle_dir" >&2
    exit 1
  fi
done
if [ ! -x "$bundle_dir/oculve" ] || [ ! -d "$bundle_dir/data/flutter_assets" ]; then
  echo "Linux release bundle is incomplete: $bundle_dir" >&2
  exit 1
fi
for runtime in xray byedpi; do
  if [ ! -x "$runtime_dir/$runtime" ]; then
    echo "Prepared Linux runtime is missing or not executable: $runtime_dir/$runtime" >&2
    exit 1
  fi
done
if [ ! -s "$runtime_dir/byedpi-LICENSE" ]; then
  echo "ByeDPI license file is missing from $runtime_dir" >&2
  exit 1
fi
for support_file in \
  native/linux/oculve-tunnel \
  native/linux/com.oculve.client.policy \
  native/linux/install.sh; do
  if [ ! -f "$repo_root/$support_file" ]; then
    echo "Linux VPN support file is missing: $support_file" >&2
    exit 1
  fi
done

archive_dir=$(dirname -- "$archive")
mkdir -p "$archive_dir"
work_dir=$(mktemp -d)
output_name=$(basename -- "$archive")
temporary_archive="$archive_dir/.${output_name}.tmp.$$"
trap 'rm -rf "$work_dir"; rm -f "$temporary_archive"' EXIT HUP INT TERM
package_dir="$work_dir/oculve-linux"
mkdir -p "$package_dir/app" "$package_dir/linux/xray" "$package_dir/native/linux"
cp -a "$bundle_dir/." "$package_dir/app/"
cp -a "$runtime_dir/." "$package_dir/linux/xray/"
cp -p \
  "$repo_root/native/linux/oculve-tunnel" \
  "$repo_root/native/linux/com.oculve.client.policy" \
  "$repo_root/native/linux/install.sh" \
  "$package_dir/native/linux/"

cat > "$package_dir/README.txt" <<'EOF'
Oculve Linux x64 test build

Run the desktop client with ./app/oculve.

Before connecting, install the system VPN helper once from this folder:
  sudo ./native/linux/install.sh

The helper installer adds the root-owned tunnel runtime and Polkit action.
The app itself remains a normal unprivileged desktop process. GTK 3 and
Polkit must be available on the system.

This is an unsigned test build. A live Linux VPN session and IP/DNS leak test
have not been performed.
EOF

tar -czf "$temporary_archive" -C "$work_dir" oculve-linux

listing="$work_dir/archive-list.txt"
tar -tzf "$temporary_archive" > "$listing"
for required in \
  oculve-linux/app/oculve \
  oculve-linux/app/lib/libflutter_linux_gtk.so \
  oculve-linux/app/lib/libapp.so \
  oculve-linux/app/data/flutter_assets \
  oculve-linux/linux/xray/xray \
  oculve-linux/linux/xray/byedpi \
  oculve-linux/linux/xray/byedpi-LICENSE \
  oculve-linux/native/linux/oculve-tunnel \
  oculve-linux/native/linux/com.oculve.client.policy \
  oculve-linux/native/linux/install.sh \
  oculve-linux/README.txt; do
  if ! grep -Fxq "$required" "$listing" &&
      ! grep -Fqx "$required/" "$listing"; then
    echo "Linux package is missing required content: $required" >&2
    exit 1
  fi
done

mv -f "$temporary_archive" "$archive"
echo "Portable Linux test package created: $archive"
