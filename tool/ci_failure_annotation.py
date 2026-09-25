#!/usr/bin/env python3
"""Expose a short, redacted tail of a failed CI command as a check annotation."""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path


ANSI_ESCAPE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
GITHUB_TOKEN = re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b")


def redact(text: str) -> str:
    for name, value in os.environ.items():
        if value and len(value) >= 8 and re.search(
            r"token|secret|password|credential|private.?key", name, re.IGNORECASE
        ):
            text = text.replace(value, "[REDACTED]")
    return GITHUB_TOKEN.sub("[REDACTED]", ANSI_ESCAPE.sub("", text))


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: ci_failure_annotation.py <log-path> <step-name>", file=sys.stderr)
        return 2

    log_path = Path(sys.argv[1])
    title = sys.argv[2]
    with log_path.open("rb") as log:
        log.seek(0, os.SEEK_END)
        size = log.tell()
        log.seek(max(0, size - 60_000))
        excerpt = log.read().decode("utf-8", errors="replace")
    excerpt = redact(excerpt).strip() or "The command failed without producing output."
    if size > 60_000:
        excerpt = "[Earlier output omitted.]\n" + excerpt

    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with Path(summary_path).open("a", encoding="utf-8") as summary:
            summary.write(f"### {title} failed\n\n```text\n{excerpt}\n```\n")

    annotation = excerpt[-2_800:]
    if len(excerpt) > len(annotation):
        annotation = "[Earlier output omitted.]\n" + annotation
    safe_title = title.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    safe_message = annotation.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    print(f"::error title={safe_title}::{safe_message}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
