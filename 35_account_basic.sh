#!/usr/bin/env bash
set -euo pipefail

say "[35] 계정 기본 점검 (UID0 / 빈 패스워드 / sudo NOPASSWD)"

UID0_OUT="$ARTIFACTS/uid0_accounts.txt"
EMPTY_OUT="$ARTIFACTS/empty_password_users.txt"
SUDO_OUT="$ARTIFACTS/sudo_nopasswd_hits.txt"

: > "$UID0_OUT"
: > "$EMPTY_OUT"
: > "$SUDO_OUT"

# 1) UID 0 계정 점검
awk -F: '($3==0){print $1":"$3":"$7}' /etc/passwd > "$UID0_OUT" 2>/dev/null || true

uid0_count="$(wc -l < "$UID0_OUT" | tr -d ' ')"

if [[ "$uid0_count" == "1" ]] && grep -q '^root:0:' "$UID0_OUT"; then
  good_k "uid0_accounts" "UID 0 계정이 root 1개만 존재"
else
  vuln_k "uid0_accounts" "UID 0 계정 추가 존재 가능성 확인 필요"
fi

info "uid0 list saved: $UID0_OUT"

# 2) 빈 패스워드 계정 점검
if [[ -r /etc/shadow ]]; then
  awk -F: '($2==""){print $1 " EMPTY-PASS"}' /etc/shadow > "$EMPTY_OUT" 2>/dev/null || true
  empty_count="$(wc -l < "$EMPTY_OUT" | tr -d ' ')"

  if [[ "$empty_count" == "0" ]]; then
    good_k "empty_password_accounts" "빈 패스워드 계정 없음"
  else
    vuln_k "empty_password_accounts" "빈 패스워드 계정 존재 가능성 확인 필요"
  fi
else
  warn_k "empty_password_accounts" "/etc/shadow 읽기 불가(root 권한 필요 가능)"
fi

info "empty password saved: $EMPTY_OUT"

# 3) sudo NOPASSWD 점검
# 주석 제외, 실제 설정만 탐지
grep -RInE '^[[:space:]]*[^#].*\bNOPASSWD\b' /etc/sudoers /etc/sudoers.d 2>/dev/null > "$SUDO_OUT" || true

sudo_count="$(wc -l < "$SUDO_OUT" | tr -d ' ')"

if [[ "$sudo_count" == "0" ]]; then
  good_k "sudo_nopasswd" "sudo NOPASSWD 설정 미탐지"
else
  warn_k "sudo_nopasswd" "sudo NOPASSWD 설정 발견(정책에 따라 리스크). 확인 필요"
  sed 's/^/  - /' "$SUDO_OUT" || true
fi

info "sudo nopasswd evidence: $SUDO_OUT"
