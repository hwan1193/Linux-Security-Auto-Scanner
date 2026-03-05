#!/usr/bin/env bash
set -euo pipefail

say "[70] SELinux 상태 점검"

if command -v getenforce >/dev/null 2>&1; then
  mode="$(getenforce 2>/dev/null || true)"
  say "  [*] getenforce: $mode"
  if [[ "$mode" == "Enforcing" ]]; then
    good "SELinux Enforcing"
  elif [[ "$mode" == "Permissive" ]]; then
    warn "SELinux Permissive(정책상 Enforcing 권장)"
  elif [[ "$mode" == "Disabled" ]]; then
    warn "SELinux Disabled(정책상 리스크)"
  fi
else
  warn "getenforce 없음"
fi

if [[ -f /etc/selinux/config ]]; then
  cp -a /etc/selinux/config "$ARTIFACTS/selinux_config.txt" 2>/dev/null || true
  say "  [*] selinux config saved: $ARTIFACTS/selinux_config.txt"
fi
