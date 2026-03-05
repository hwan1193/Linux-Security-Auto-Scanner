#!/usr/bin/env bash
set -euo pipefail

say "[40] Anonymous FTP (U-62)"

cfg=""
for p in /etc/vsftpd/vsftpd.conf /etc/vsftpd.conf; do
  [[ -f "$p" ]] && cfg="$p" && break
done

if command -v systemctl >/dev/null 2>&1; then
  if systemctl list-unit-files | grep -q '^vsftpd\.service'; then
    st="$(systemctl is-active vsftpd 2>/dev/null || true)"
    say "  [*] vsftpd service state: ${st:-unknown}"
  else
    say "  [*] vsftpd.service 없음"
  fi
fi

if [[ -n "$cfg" ]]; then
  say "  [*] Config: $cfg"
  val="$(grep -E '^\s*anonymous_enable\s*=' "$cfg" | tail -n 1 | cut -d= -f2- | tr -d '[:space:]' || true)"
  if [[ -z "$val" ]]; then
    warn "anonymous_enable 설정을 찾지 못함(기본값/다른 include 가능)"
  elif [[ "$val" =~ ^(NO|no)$ ]]; then
    good "익명 FTP 차단(anonymous_enable=NO)"
  else
    vuln "익명 FTP 허용(anonymous_enable=$val)"
  fi
else
  good "vsftpd 설정 파일 미존재(미설치/미사용 가능)"
fi
