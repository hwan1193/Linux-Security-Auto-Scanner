\
#!/usr/bin/env bash
set -euo pipefail

say "[65] 불필요 서비스 활성화 여부 점검 (enabled/active)"

EN_FILE="$ARTIFACTS/enabled_units.txt"
AC_FILE="$ARTIFACTS/active_units.txt"

: > "$EN_FILE"
: > "$AC_FILE"

if ! command -v systemctl >/dev/null 2>&1; then
  warn "systemctl 없음. 서비스 점검 스킵"
  exit 0
fi

# Evidence
systemctl list-unit-files --type=service --state=enabled > "$EN_FILE" 2>/dev/null || true
systemctl list-unit-files --type=socket  --state=enabled >> "$EN_FILE" 2>/dev/null || true
systemctl list-units --type=service --state=running > "$AC_FILE" 2>/dev/null || true
systemctl list-units --type=socket  --state=running >> "$AC_FILE" 2>/dev/null || true

info "enabled units saved: $EN_FILE"
info "active units saved:  $AC_FILE"

# Risky units (common)
RISK_VULN=(
  telnet.socket
  rsh.socket
  rlogin.socket
  rexec.socket
  tftp.service
  tftp.socket
  xinetd.service
)
RISK_WARN=(
  rpcbind.service
  rpcbind.socket
  avahi-daemon.service
  cups.service
  nfs-server.service
  smb.service
  nmb.service
  snmpd.service
  vsftpd.service
)

is_enabled() { systemctl is-enabled "$1" >/dev/null 2>&1; }
is_active()  { systemctl is-active "$1"  >/dev/null 2>&1; }

for u in "${RISK_VULN[@]}"; do
  if systemctl list-unit-files | awk '{print $1}' | grep -qx "$u"; then
    if is_enabled "$u" || is_active "$u"; then
      vuln "고위험 서비스 활성화 발견: $u (enabled/active). 미사용 시 disable 권장"
    fi
  fi
done

for u in "${RISK_WARN[@]}"; do
  if systemctl list-unit-files | awk '{print $1}' | grep -qx "$u"; then
    if is_enabled "$u" || is_active "$u"; then
      warn "서비스 활성화 확인: $u (운영 필요성 검토). 미사용 시 disable 권장"
    fi
  fi
done

good "서비스 점검 완료 (증적: enabled/active 목록 저장)"
