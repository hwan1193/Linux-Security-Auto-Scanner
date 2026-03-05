#!/usr/bin/env bash
set -euo pipefail

say "[90] 시간 동기화(chrony) 점검"

if command -v timedatectl >/dev/null 2>&1; then
  timedatectl status > "$ARTIFACTS/timedatectl_status.txt" 2>/dev/null || true
  say "  [*] timedatectl saved: $ARTIFACTS/timedatectl_status.txt"
fi

if command -v systemctl >/dev/null 2>&1; then
  if systemctl list-unit-files | grep -q '^chronyd\.service'; then
    st="$(systemctl is-active chronyd 2>/dev/null || true)"
    [[ "$st" == "active" ]] && good "chronyd 활성" || warn "chronyd 상태: ${st:-unknown}"
  fi
fi

if command -v chronyc >/dev/null 2>&1; then
  chronyc sources -v > "$ARTIFACTS/chrony_sources.txt" 2>/dev/null || true
  say "  [*] chrony sources saved: $ARTIFACTS/chrony_sources.txt"
fi

if [[ -f /etc/chrony.conf ]]; then
  cp -a /etc/chrony.conf "$ARTIFACTS/chrony.conf" 2>/dev/null || true
fi
