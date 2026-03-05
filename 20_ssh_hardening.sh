#!/usr/bin/env bash
set -euo pipefail

say "[20] SSH 하드닝 (U-01 포함)"

if ! command -v sshd >/dev/null 2>&1; then
  warn "sshd 미설치 가능. SSH 점검 스킵"
  exit 0
fi

# Effective config (supports include + Match)
EFF_FILE="$ARTIFACTS/sshd_effective.txt"
sshd -T -C user=root,host="$(hostname)",addr=127.0.0.1 > "$EFF_FILE" 2>/dev/null || true

if [[ -s "$EFF_FILE" ]]; then
  say "  [*] sshd effective config saved: $EFF_FILE"
else
  warn "sshd -T 결과를 만들지 못함. 설정 파일 기반 확인 필요"
fi

get_eff() {
  local k="$1"
  awk -v key="$k" '$1==key{print $2}' "$EFF_FILE" | tail -n 1
}

# Root login
prl="$(get_eff permitrootlogin || true)"
if [[ -n "$prl" ]]; then
  say "  [*] permitrootlogin=$prl"
  case "$prl" in
    no) good "Root SSH 로그인 차단(PermitRootLogin no)";;
    prohibit-password|without-password)
      warn "Root 키로그인은 허용($prl). 정책이 'no'면 취약 판정 필요";;
    yes) vuln "Root SSH 로그인 허용(permitrootlogin yes)";;
    *) warn "permitrootlogin 값 비표준: $prl";;
  esac
else
  warn "permitrootlogin 값을 확인 못함"
fi

# PasswordAuthentication
pa="$(get_eff passwordauthentication || true)"
if [[ "$pa" == "no" ]]; then
  good "PasswordAuthentication 비활성(no)"
elif [[ -n "$pa" ]]; then
  warn "PasswordAuthentication=$pa (키 기반 강제면 no 권장)"
fi

# PermitEmptyPasswords
pep="$(get_eff permitemptypasswords || true)"
if [[ "$pep" == "no" ]]; then
  good "빈 비밀번호 로그인 차단(permitEmptyPasswords no)"
elif [[ -n "$pep" ]]; then
  vuln "빈 비밀번호 로그인 허용 가능성(permitEmptyPasswords=$pep)"
fi

# MaxAuthTries
mat="$(get_eff maxauthtries || true)"
if [[ -n "$mat" ]]; then
  say "  [*] maxauthtries=$mat"
fi

# Evidence: show explicit settings if present
for f in /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf; do
  [[ -f "$f" ]] || continue
  grep -nE '^\s*(PermitRootLogin|PasswordAuthentication|PermitEmptyPasswords|MaxAuthTries)\s+' "$f" 2>/dev/null || true
done
