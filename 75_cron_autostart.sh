\
#!/usr/bin/env bash
set -euo pipefail

say "[75] 크론/자동실행 점검 (cron + systemd timers)"

CRON_FILE="$ARTIFACTS/cron_system_list.txt"
ROOT_CRONTAB="$ARTIFACTS/cron_root_crontab.txt"
TIMERS_FILE="$ARTIFACTS/systemd_timers.txt"
WW_FILE="$ARTIFACTS/cron_world_writable_hits.txt"

: > "$CRON_FILE"
: > "$ROOT_CRONTAB"
: > "$TIMERS_FILE"
: > "$WW_FILE"

# Evidence: cron directories/files
for p in /etc/crontab /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /var/spool/cron /var/spool/cron/crontabs; do
  if [[ -e "$p" ]]; then
    echo "### $p" >> "$CRON_FILE"
    ls -al "$p" >> "$CRON_FILE" 2>/dev/null || true
    echo "" >> "$CRON_FILE"
  fi
done

info "cron path listing saved: $CRON_FILE"

# Root crontab
if command -v crontab >/dev/null 2>&1; then
  crontab -l -u root > "$ROOT_CRONTAB" 2>/dev/null || echo "(no crontab for root)" > "$ROOT_CRONTAB"
  info "root crontab saved: $ROOT_CRONTAB"
else
  warn "crontab 명령 없음"
fi

# systemd timers
if command -v systemctl >/dev/null 2>&1; then
  systemctl list-timers --all > "$TIMERS_FILE" 2>/dev/null || true
  info "systemd timers saved: $TIMERS_FILE"
fi

# World-writable check (very risky)
scan_paths=()
for d in /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /var/spool/cron /var/spool/cron/crontabs; do
  [[ -e "$d" ]] && scan_paths+=("$d")
done

if [[ "${#scan_paths[@]}" -gt 0 ]]; then
  find "${scan_paths[@]}" -xdev -type f -perm -0002 -print 2>/dev/null | sort -u > "$WW_FILE" || true
  if [[ -s "$WW_FILE" ]]; then
    vuln "크론 경로에 world-writable 파일 존재 (즉시 수정 필요)"
    head -n 20 "$WW_FILE" | sed 's/^/  - /'
  else
    good "크론 경로 world-writable 파일 미탐지"
  fi
else
  warn "크론 관련 경로를 찾지 못함(환경 확인 필요)"
fi

