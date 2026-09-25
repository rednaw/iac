#!/usr/bin/env python3
"""Fail if fail2ban <HOST> patterns would hit 'redefinition of group name'.

fail2ban expands each <HOST> to a regex with named groups (ip4, ip6, …).
Two <HOST> tokens in one compiled pattern crash fail2ban on start
(see .cursor/plans/rotate/abuseipdb.md). Each ignoreregex/failregex line
must contain at most one <HOST>; multi-line options are checked separately.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILTER_DIR = ROOT / "ansible/roles/platform/files"
JAIL_TEMPLATE = ROOT / "ansible/roles/platform/templates/fail2ban-traefik.conf.j2"

# Minimal stand-in for fail2ban's <HOST> expansion (named groups are what matter).
HOST_EXPANSION = (
    r"(?:\[?(?:(?:::f{4,6}:)?(?P<ip4>(?:\d{1,3}\.){3}\d{1,3})"
    r"|(?P<ip6>(?:[0-9a-fA-F]{1,4}::?|::){1,7}(?:[0-9a-fA-F]{1,4}|(?<=:):)))\]?"
    r"|(?P<dns>[\w\-.^_]*\w))"
)


def expand_host(pattern: str) -> str:
    return pattern.replace("<HOST>", HOST_EXPANSION)


def option_values(text: str, option: str) -> list[str]:
    """Collect fail2ban-style multi-line option values (continuation lines)."""
    values: list[str] = []
    current: list[str] | None = None
    prefix = f"{option} ="
    for raw in text.splitlines():
        line = raw.rstrip()
        if not line or line.lstrip().startswith("#") or line.lstrip().startswith(";"):
            continue
        if line.startswith(prefix) or line.startswith(f"{option}="):
            if current:
                values.append("\n".join(current))
            _, _, rest = line.partition("=")
            current = [rest.strip()]
            continue
        if current is not None and (raw.startswith(" ") or raw.startswith("\t")):
            current.append(line.strip())
            continue
        if current is not None:
            values.append("\n".join(current))
            current = None
    if current is not None:
        values.append("\n".join(current))

    # One option block may list several regexes separated by newlines.
    patterns: list[str] = []
    for block in values:
        for part in block.splitlines():
            part = part.strip()
            if part:
                patterns.append(part)
    return patterns


def check_pattern(path: Path, kind: str, pattern: str) -> list[str]:
    errors: list[str] = []
    hosts = pattern.count("<HOST>")
    if hosts > 1:
        errors.append(f"{path}: {kind} has {hosts} <HOST> tokens in one pattern: {pattern!r}")
    try:
        re.compile(expand_host(pattern))
    except re.error as exc:
        errors.append(f"{path}: {kind} does not compile after <HOST> expand: {pattern!r} ({exc})")
    return errors


def main() -> int:
    errors: list[str] = []
    for path in sorted(FILTER_DIR.glob("fail2ban-filter-*.conf")):
        text = path.read_text()
        for kind in ("failregex", "ignoreregex"):
            for pattern in option_values(text, kind):
                errors.extend(check_pattern(path, kind, pattern))

    if JAIL_TEMPLATE.is_file():
        text = JAIL_TEMPLATE.read_text()
        for kind in ("failregex", "ignoreregex"):
            for pattern in option_values(text, kind):
                errors.extend(check_pattern(JAIL_TEMPLATE, kind, pattern))

    if errors:
        print("❌ fail2ban <HOST> regex check failed:", file=sys.stderr)
        for err in errors:
            print(f"  {err}", file=sys.stderr)
        return 1

    print("✅ fail2ban <HOST> regex check passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
