#!/bin/sh
# Builds ciadpi from a copy of vendor/byedpi/upstream and prints the offline DPI profile matrix.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT/test"
exec python3 -m dpi_sim "$@"
