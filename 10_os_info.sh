#!/usr/bin/env bash
set -euo pipefail

say "[10] OS / Kernel / Host 기본정보"

if [[ -f /etc/os-release ]]; then
  say "  [*] /etc/os-release"
  grep -E '^(NAME|VERSION|PRETTY_NAME|ID|VERSION_ID)=' /etc/os-release || true
fi

say "  [*] hostname: $(hostname)"
command -v uptime >/dev/null 2>&1 && say "  [*] uptime: $(uptime -p 2>/dev/null || true)"
command -v uname  >/dev/null 2>&1 && say "  [*] kernel: $(uname -r)"

if command -v ip >/dev/null 2>&1; then
  ip -br a > "$ARTIFACTS/ip_addr.txt" 2>/dev/null || true
  say "  [*] ip addr saved: $ARTIFACTS/ip_addr.txt"
fi
