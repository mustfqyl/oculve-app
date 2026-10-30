"""`python3 -m dpi_sim` (run from test/): prints the matrix tables and the JSON result."""

import json
import sys
import tempfile
from pathlib import Path

from .core import ALLOWED_SNI, BLOCKED_SNI, Unavailable, format_table, run_matrix


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="oculve-dpi-sim-") as work:
        try:
            result = run_matrix(Path(work))
        except Unavailable as error:
            print(f"skipped: {error}", file=sys.stderr)
            return 2
    print(format_table(result, BLOCKED_SNI))
    print()
    print(format_table(result, ALLOWED_SNI))
    print()
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
