#!/usr/bin/env bash
set -euo pipefail

say "[50] SUID/SGID 파일 점검 (U-13)"

out_all="$ARTIFACTS/suid_sgid_all.txt"
out_sus="$ARTIFACTS/suid_sgid_suspicious.txt"

scan_paths=(/bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin /opt)
if [[ "${FULL_SUID_SCAN:-0}" == "1" ]]; then
  warn "FULL_SUID_SCAN=1 → / 전체 스캔(시간 오래 걸릴 수 있음)"
  scan_paths=(/)
fi

find "${scan_paths[@]}" -xdev -type f \( -perm -4000 -o -perm -2000 \) -print 2>/dev/null | sort -u > "$out_all" || true
cnt="$(wc -l < "$out_all" | tr -d ' ')"
say "  [*] SUID/SGID count: $cnt"
say "  [*] saved: $out_all"

# suspicious locations
grep -E '^(/tmp/|/var/tmp/|/dev/shm/|/home/|/var/www/)' "$out_all" > "$out_sus" || true
if [[ -s "$out_sus" ]]; then
  vuln "의심 경로에 SUID/SGID 파일 존재"
  head -n 20 "$out_sus" | sed 's/^/  - /'
  say "  [*] suspicious saved: $out_sus"
else
  good "의심 경로 SUID/SGID 파일 미탐지"
fi
