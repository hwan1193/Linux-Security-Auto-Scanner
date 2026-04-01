#!/usr/bin/env bash
set -euo pipefail

say "[70] SELinux 상태 점검"

SELINUX_OUT="$ARTIFACTS/selinux_config.txt"
: > "$SELINUX_OUT"

if command -v getenforce >/dev/null 2>&1; then
  se_status="$(getenforce 2>/dev/null || true)"
  echo "getenforce=$se_status" > "$SELINUX_OUT"
  info "getenforce: $se_status"

  case "$se_status" in
    Enforcing)
      good_k "selinux_status" "SELinux Enforcing"
      ;;
    Permissive)
      warn_k "selinux_status" "SELinux Permissive"
      ;;
    Disabled)
      vuln_k "selinux_status" "SELinux Disabled"
      ;;
    *)
      warn_k "selinux_status" "SELinux 상태 확인 불명확: $se_status"
      ;;
  esac
else
  warn_k "selinux_status" "getenforce 명령 없음. SELinux 상태 확인 필요"
fi

if [[ -f /etc/selinux/config ]]; then
  cat /etc/selinux/config >> "$SELINUX_OUT" 2>/dev/null || true
fi

info "selinux config saved: $SELINUX_OUT"
