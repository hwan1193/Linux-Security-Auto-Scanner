#!/usr/bin/env bash
set -euo pipefail

say "[30] 패스워드 정책 / PAM / authselect (U-02 확장)"

# authselect (RHEL9 계열에서 중요)
if command -v authselect >/dev/null 2>&1; then
  authselect current > "$ARTIFACTS/authselect_current.txt" 2>/dev/null || true
  say "  [*] authselect current saved: $ARTIFACTS/authselect_current.txt"
fi

# login.defs
if [[ -f /etc/login.defs ]]; then
  say "  [*] /etc/login.defs"
  grep -E -i '^\s*(PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_MIN_LEN|PASS_WARN_AGE)\b' /etc/login.defs | grep -v '^\s*#' || true
fi

# pwquality
if [[ -f /etc/security/pwquality.conf ]]; then
  say "  [*] /etc/security/pwquality.conf"
  grep -E '^\s*(minlen|dcredit|ucredit|lcredit|ocredit|retry|maxrepeat|maxclassrepeat)\b' /etc/security/pwquality.conf | grep -v '^\s*#' || true
fi

# faillock
if [[ -f /etc/security/faillock.conf ]]; then
  say "  [*] /etc/security/faillock.conf"
  grep -E '^\s*(deny|unlock_time|fail_interval)\b' /etc/security/faillock.conf | grep -v '^\s*#' || true
fi

# PAM enforcement
for f in /etc/pam.d/system-auth /etc/pam.d/password-auth; do
  [[ -f "$f" ]] || continue
  say "  [*] $f (pwquality/pwhistory/faillock)"
  grep -nE 'pam_pwquality\.so|pam_pwhistory\.so|pam_faillock\.so' "$f" || true
done

# Quick sanity verdict (policy 기준은 조직마다 다르니 '주의' 중심)
if grep -Rqs 'pam_pwquality\.so' /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null; then
  good "PAM pwquality 적용 흔적 확인"
else
  warn "PAM pwquality 적용 흔적이 약함(수동 확인 필요)"
fi
