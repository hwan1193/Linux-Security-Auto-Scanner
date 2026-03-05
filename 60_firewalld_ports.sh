#!/usr/bin/env bash
set -euo pipefail

say "[60] 방화벽(firewalld) / 리슨 포트 점검"

# firewalld state
if command -v firewall-cmd >/dev/null 2>&1; then
  st="$(firewall-cmd --state 2>/dev/null || true)"
  if [[ "$st" == "running" ]]; then
    good "firewalld 실행 중"
    firewall-cmd --get-default-zone > "$ARTIFACTS/firewalld_default_zone.txt" 2>/dev/null || true
    firewall-cmd --list-all > "$ARTIFACTS/firewalld_list_all.txt" 2>/dev/null || true
    say "  [*] firewalld evidence saved: $ARTIFACTS/firewalld_list_all.txt"
  else
    warn "firewalld 상태 확인: ${st:-unknown}"
  fi
else
  warn "firewall-cmd 없음(firewalld 미설치 가능)"
fi

# Listening ports
if command -v ss >/dev/null 2>&1; then
  ss -lntup > "$ARTIFACTS/listening_ports_ss.txt" 2>/dev/null || true
  say "  [*] listening ports saved: $ARTIFACTS/listening_ports_ss.txt"
else
  warn "ss 명령 없음"
fi
