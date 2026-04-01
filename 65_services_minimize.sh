#!/usr/bin/env bash
set -euo pipefail

say "[65] 불필요 서비스 활성화 여부 점검 (enabled/active)"

ENABLED_OUT="$ARTIFACTS/enabled_units.txt"
ACTIVE_OUT="$ARTIFACTS/active_units.txt"

: > "$ENABLED_OUT"
: > "$ACTIVE_OUT"

systemctl list-unit-files --state=enabled > "$ENABLED_OUT" 2>/dev/null || true
systemctl list-units --type=service --state=running > "$ACTIVE_OUT" 2>/dev/null || true

info "enabled units saved: $ENABLED_OUT"
info "active units saved:  $ACTIVE_OUT"

# 1) rpcbind 확인
if grep -q '^rpcbind\.service' "$ENABLED_OUT" || grep -q '^rpcbind\.socket' "$ENABLED_OUT"; then
  warn_k "rpcbind_enabled" "서비스 활성화 확인: rpcbind.socket (운영 필요성 검토). 미사용 시 disable 권장"
else
  good_k "rpcbind_enabled" "rpcbind 비활성 또는 미사용"
fi

# 2) 전체 enabled 서비스 목록 존재 여부
if [[ -s "$ENABLED_OUT" ]]; then
  good_k "enabled_services_review" "서비스 점검 완료 (증적: enabled/active 목록 저장)"
else
  warn_k "enabled_services_review" "enabled 서비스 목록을 가져오지 못함"
fi
