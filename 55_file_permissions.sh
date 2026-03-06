\
#!/usr/bin/env bash
set -euo pipefail

say "[55] 핵심 파일/디렉토리 권한 점검 (파일 권한/소유자)"

OUT_FILE="$ARTIFACTS/file_permissions.txt"
: > "$OUT_FILE"

check_file() {
  local f="$1"
  local desc="${2:-}"
  [[ -e "$f" ]] || { info "$f 없음"; echo "[MISS] $f $desc" >> "$OUT_FILE"; return 0; }

  local mode owner group
  mode="$(stat -c '%a' "$f" 2>/dev/null || echo "?")"
  owner="$(stat -c '%U' "$f" 2>/dev/null || echo "?")"
  group="$(stat -c '%G' "$f" 2>/dev/null || echo "?")"

  # basic rules
  local mode_int=0
  if [[ "$mode" =~ ^[0-7]+$ ]]; then
    mode_int=$((8#$mode))
  fi

  local other_write=$(( mode_int & 0o002 ))
  local group_write=$(( mode_int & 0o020 ))

  echo "[INFO] $f mode=$mode owner=$owner group=$group $desc" >> "$OUT_FILE"

  if [[ "$owner" != "root" ]]; then
    vuln "$f 소유자가 root 아님 (owner=$owner) $desc"
    return 0
  fi

  # Generic: never allow group/other write for sensitive paths
  if [[ "$group_write" -ne 0 || "$other_write" -ne 0 ]]; then
    vuln "$f 그룹/기타 쓰기 권한 존재 (mode=$mode) $desc"
    return 0
  fi

  # File-specific additional checks
  case "$f" in
    /etc/shadow|/etc/gshadow)
      # others should have no perms
      if (( mode_int & 0o007 )); then
        vuln "$f 기타 사용자 권한 존재 (mode=$mode) $desc"
      else
        good "$f 권한 양호 (mode=$mode) $desc"
      fi
      ;;
    /etc/sudoers|/etc/sudoers.d/*)
      # should not be readable by others ideally
      if (( mode_int & 0o004 )); then
        warn "$f 기타 사용자 읽기 권한 존재 (mode=$mode) $desc"
      else
        good "$f 권한 양호 (mode=$mode) $desc"
      fi
      ;;
    /etc/passwd|/etc/group)
      # allow world-read (not security vuln), but warn if too restrictive
      if (( mode_int & 0o004 )); then
        good "$f 권한 양호 (mode=$mode) $desc"
      else
        warn "$f 기타 사용자 읽기 권한 없음 (mode=$mode). 운영상 영향 가능 $desc"
      fi
      ;;
    *)
      good "$f 권한 기본 점검 양호 (mode=$mode) $desc"
      ;;
  esac
}

check_dir() {
  local d="$1"
  local desc="${2:-}"
  [[ -d "$d" ]] || { info "$d 디렉토리 없음"; echo "[MISS] $d (dir) $desc" >> "$OUT_FILE"; return 0; }

  local mode owner group
  mode="$(stat -c '%a' "$d" 2>/dev/null || echo "?")"
  owner="$(stat -c '%U' "$d" 2>/dev/null || echo "?")"
  group="$(stat -c '%G' "$d" 2>/dev/null || echo "?")"

  local mode_int=0
  if [[ "$mode" =~ ^[0-7]+$ ]]; then
    mode_int=$((8#$mode))
  fi
  local other_write=$(( mode_int & 0o002 ))
  local group_write=$(( mode_int & 0o020 ))

  echo "[INFO] $d (dir) mode=$mode owner=$owner group=$group $desc" >> "$OUT_FILE"

  if [[ "$owner" != "root" ]]; then
    vuln "$d 디렉토리 소유자가 root 아님 (owner=$owner) $desc"
    return 0
  fi
  if [[ "$group_write" -ne 0 || "$other_write" -ne 0 ]]; then
    vuln "$d 디렉토리에 그룹/기타 쓰기 권한 존재 (mode=$mode) $desc"
  else
    good "$d 디렉토리 권한 양호 (mode=$mode) $desc"
  fi
}

# Key files
check_file /etc/passwd      "(계정 DB)"
check_file /etc/shadow      "(패스워드 해시)"
check_file /etc/group       "(그룹 DB)"
check_file /etc/gshadow     "(그룹 패스워드)"
check_file /etc/sudoers     "(sudo 정책)"
if [[ -d /etc/sudoers.d ]]; then
  for f in /etc/sudoers.d/*; do
    [[ -e "$f" ]] || continue
    check_file "$f" "(sudo 정책 include)"
  done
fi

# SSH config
check_file /etc/ssh/sshd_config "(SSHD 설정)"
if ls /etc/ssh/sshd_config.d/*.conf >/dev/null 2>&1; then
  for f in /etc/ssh/sshd_config.d/*.conf; do
    check_file "$f" "(SSHD include)"
  done
fi

# Cron
check_file /etc/crontab "(system cron)"
check_dir  /etc/cron.d "(system cron.d)"
check_dir  /etc/cron.daily "(cron.daily)"
check_dir  /etc/cron.hourly "(cron.hourly)"
check_dir  /etc/cron.weekly "(cron.weekly)"
check_dir  /etc/cron.monthly "(cron.monthly)"

info "file permissions evidence saved: $OUT_FILE"
