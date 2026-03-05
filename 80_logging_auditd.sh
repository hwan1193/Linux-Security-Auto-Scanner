#!/usr/bin/env bash
set -euo pipefail

say "[80] 로그/감사(auditd/rsyslog) 점검"

# rsyslog
if command -v systemctl >/dev/null 2>&1; then
  if systemctl list-unit-files | grep -q '^rsyslog\.service'; then
    st="$(systemctl is-active rsyslog 2>/dev/null || true)"
    [[ "$st" == "active" ]] && good "rsyslog 활성" || warn "rsyslog 상태: ${st:-unknown}"
  fi
  if systemctl list-unit-files | grep -q '^auditd\.service'; then
    st="$(systemctl is-active auditd 2>/dev/null || true)"
    [[ "$st" == "active" ]] && good "auditd 활성" || warn "auditd 상태: ${st:-unknown}"
  else
    warn "auditd.service 없음(미설치 가능)"
  fi
fi

# audit rules evidence
if [[ -d /etc/audit/rules.d ]]; then
  ls -al /etc/audit/rules.d > "$ARTIFACTS/audit_rules_ls.txt" 2>/dev/null || true
  cat /etc/audit/rules.d/*.rules > "$ARTIFACTS/audit_rules_concat.rules" 2>/dev/null || true
  say "  [*] audit rules saved: $ARTIFACTS/audit_rules_concat.rules"
fi
