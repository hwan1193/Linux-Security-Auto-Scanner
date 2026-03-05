#!/usr/bin/env bash
set -euo pipefail

say "[35] 계정 기본 점검 (UID0 / 빈 패스워드 / sudo NOPASSWD)"

# UID 0 accounts
uid0="$ARTIFACTS/uid0_accounts.txt"
awk -F: '($3==0){print $1":"$0}' /etc/passwd > "$uid0" || true
cnt="$(wc -l < "$uid0" | tr -d ' ')"
if [[ "$cnt" == "1" ]]; then
  good "UID 0 계정이 root 1개만 존재"
else
  vuln "UID 0 계정이 여러개 존재 가능($cnt). 확인 필요"
  head -n 20 "$uid0" | sed 's/^/  - /'
fi
say "  [*] uid0 list saved: $uid0"

# Empty password fields (requires /etc/shadow read; usually root)
if [[ -r /etc/shadow ]]; then
  empt="$ARTIFACTS/empty_password_users.txt"
  awk -F: '($2=="" || $2=="!"){next} ($2=="*"){next} { }' /etc/shadow >/dev/null 2>&1 || true

  # truly empty hash: second field empty
  awk -F: '($2==""){print $1}' /etc/shadow > "$empt" || true
  if [[ -s "$empt" ]]; then
    vuln "빈 패스워드 계정 존재"
    cat "$empt" | sed 's/^/  - /'
  else
    good "빈 패스워드 계정 없음"
  fi
  say "  [*] empty password saved: $empt"
else
  warn "/etc/shadow 읽기 불가(권한). root로 실행 권장"
fi

# sudo NOPASSWD
if [[ -d /etc/sudoers.d || -f /etc/sudoers ]]; then
  nop="$ARTIFACTS/sudo_nopasswd_hits.txt"
  { grep -RIn --color=never 'NOPASSWD' /etc/sudoers /etc/sudoers.d 2>/dev/null || true; } > "$nop"
  if [[ -s "$nop" ]]; then
    warn "sudo NOPASSWD 설정 발견(정책에 따라 리스크). 확인 필요"
    head -n 20 "$nop" | sed 's/^/  - /'
  else
    good "sudo NOPASSWD 설정 미탐지"
  fi
  say "  [*] sudo nopasswd evidence: $nop"
fi
