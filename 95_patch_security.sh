\
#!/usr/bin/env bash
set -euo pipefail

say "[95] 패치/보안업데이트 상태 점검 (dnf security advisory)"

OUT="$ARTIFACTS/patch_security_status.txt"
: > "$OUT"

if ! command -v dnf >/dev/null 2>&1; then
  warn "dnf 없음. 패치 점검 스킵"
  exit 0
fi

echo "### dnf version" >> "$OUT"
dnf --version >> "$OUT" 2>/dev/null || true
echo "" >> "$OUT"

# Last dnf log timestamp (evidence)
if [[ -f /var/log/dnf.log ]]; then
  echo "### /var/log/dnf.log mtime" >> "$OUT"
  stat -c '%y %n' /var/log/dnf.log >> "$OUT" 2>/dev/null || true
  echo "" >> "$OUT"
fi

# Security advisories (available)
SEC_FILE="$ARTIFACTS/dnf_updateinfo_security.txt"
: > "$SEC_FILE"

if dnf -q updateinfo >/dev/null 2>&1; then
  # plugin/metadata ok
  dnf -q updateinfo list security --available > "$SEC_FILE" 2>/dev/null || true
elif dnf -q updateinfo list >/dev/null 2>&1; then
  dnf -q updateinfo list security --available > "$SEC_FILE" 2>/dev/null || true
else
  warn "dnf updateinfo 미지원(플러그인/메타데이터 부족 가능). 수동 확인 필요"
fi

info "security advisory saved: $SEC_FILE"

# 판단(너무 공격적이면 안 됨 → warn 레벨)
if [[ -s "$SEC_FILE" ]]; then
  # filter out header lines if any
  lines=$(grep -Ev '^(Last metadata expiration check|Loaded plugins|Available|Updates)' "$SEC_FILE" | wc -l | tr -d ' ')
  if [[ "${lines:-0}" -gt 0 ]]; then
    warn "적용 가능한 보안 업데이트 항목이 있을 수 있음. 패치 윈도우 내 검토 권장"
  else
    good "보안 업데이트 목록이 비어있음(또는 메타데이터 헤더만 존재)"
  fi
else
  warn "보안 업데이트 정보를 가져오지 못했거나(레포/메타데이터) 항목이 없음"
fi

# Optional: reboot required check (if tool exists)
if command -v needs-restarting >/dev/null 2>&1; then
  if needs-restarting -r >/dev/null 2>&1; then
    good "reboot required 아님"
  else
    warn "reboot 필요 상태일 수 있음(needs-restarting -r). 점검 권장"
  fi
fi

