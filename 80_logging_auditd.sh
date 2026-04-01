#!/usr/bin/env bash
set -euo pipefail

say "[80] 로그/감사(auditd/rsyslog) 점검"

AUDIT_RULES_OUT="$ARTIFACTS/audit_rules_concat.rules"
: > "$AUDIT_RULES_OUT"

# 1) auditd 서비스 확인
if systemctl list-unit-files 2>/dev/null | grep -q '^auditd\.service'; then
  if systemctl is-active auditd >/dev/null 2>&1; then
    good_k "auditd_present" "auditd.service 활성"
  else
    warn_k "auditd_present" "auditd.service 설치되어 있으나 비활성"
  fi
else
  warn_k "auditd_present" "auditd.service 없음(미설치 가능)"
fi

# 2) audit rule 수집
if [[ -d /etc/audit/rules.d ]]; then
  cat /etc/audit/rules.d/*.rules >> "$AUDIT_RULES_OUT" 2>/dev/null || true
fi

if [[ -f /etc/audit/audit.rules ]]; then
  cat /etc/audit/audit.rules >> "$AUDIT_RULES_OUT" 2>/dev/null || true
fi

info "audit rules saved: $AUDIT_RULES_OUT"

# 3) audit rule 존재 여부
if [[ -s "$AUDIT_RULES_OUT" ]]; then
  good_k "audit_rules_present" "audit rules 존재"
else
  warn_k "audit_rules_present" "audit rules 미확인"
fi
