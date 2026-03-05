#!/usr/bin/env bash
# =================================================================
# Linux Security Vulnerability Auto-Scanner (KISA check starter)
# - Evidence-friendly (log + outputs)
# - Uses "effective config" when possible
# =================================================================

set -euo pipefail
IFS=$'\n\t'

TS="$(date '+%F_%H-%M-%S')"
OUT_DIR="${OUT_DIR:-/var/tmp/secscan_${TS}}"
mkdir -p "$OUT_DIR"

LOG="$OUT_DIR/scan.log"
SUMMARY="$OUT_DIR/summary.txt"
touch "$SUMMARY"

# tee all outputs to log (evidence)
exec > >(tee -a "$LOG") 2>&1

say()   { echo -e "$*"; }
good()  { say "  [양호] $*"; echo -e "[양호] $*" >> "$SUMMARY"; }
vuln()  { say "  [취약] $*"; echo -e "[취약] $*" >> "$SUMMARY"; }
warn()  { say "  [주의] $*"; echo -e "[주의] $*" >> "$SUMMARY"; }
info()  { say "  [*] $*"; }

need_root_note() {
  if [[ "${EUID}" -ne 0 ]]; then
    warn "root 권한이 아니면 일부 항목(예: /etc/shadow, 전체 SUID 스캔)은 정확도가 떨어질 수 있음"
  fi
}

header() {
  say "================================================="
  say "[*] 리눅스 서버 보안 취약점 자동 진단 시작"
  say "    - Output: $OUT_DIR"
  say "================================================="
  need_root_note
}

# -----------------------------------------------------------------
# [1] SSH Root Login (U-01)
# -----------------------------------------------------------------
check_ssh_root_login() {
  say "\n[1] SSH Root 직접 로그인 제한 여부 점검 (U-01)"

  if ! command -v sshd >/dev/null 2>&1; then
    warn "sshd 바이너리를 찾지 못함(OpenSSH Server 미설치 가능). SSH 점검 스킵"
    return
  fi

  # Effective config (supports includes & match blocks)
  # -C is for Match evaluation; addr/host can be adjusted
  local eff
  eff="$(sshd -T -C user=root,host="$(hostname)",addr=127.0.0.1 2>/dev/null | awk '$1=="permitrootlogin"{print $2}' | tail -n 1 || true)"

  if [[ -n "$eff" ]]; then
    info "Effective permitrootlogin = $eff"
    case "$eff" in
      no)
        good "Root 원격 로그인 완전 차단(PermitRootLogin no) 적용"
        ;;
      prohibit-password|without-password)
        # 정책 기준에 따라 '양호/주의' 달라짐
        warn "키 기반 Root 로그인은 허용 상태($eff). 조직 정책이 'no'면 취약으로 판정해야 함"
        ;;
      yes)
        vuln "Root 원격 로그인 허용(permitrootlogin yes)"
        ;;
      *)
        warn "permitrootlogin 값이 표준 케이스가 아님: $eff (수동 확인 권장)"
        ;;
    esac
  else
    warn "sshd -T 로 effective config 추출 실패. 설정 파일 직접 확인으로 대체"
  fi

  # Show configured lines (for evidence)
  local ssh_main="/etc/ssh/sshd_config"
  if [[ -f "$ssh_main" ]]; then
    info "Config evidence: $ssh_main (및 include 파일 가능)"
    grep -nE '^\s*PermitRootLogin\s+' "$ssh_main" 2>/dev/null || true
  else
    warn "$ssh_main 파일이 없음"
  fi

  # Also show include directory lines if exist
  if ls /etc/ssh/sshd_config.d/*.conf >/dev/null 2>&1; then
    info "Config evidence: /etc/ssh/sshd_config.d/*.conf"
    grep -nE '^\s*PermitRootLogin\s+' /etc/ssh/sshd_config.d/*.conf 2>/dev/null || true
  fi
}

# -----------------------------------------------------------------
# [2] Password policy (U-02) - show REAL enforcement hints
# -----------------------------------------------------------------
check_password_policy() {
  say "\n[2] 패스워드 보안 정책 설정 점검 (U-02)"

  # login.defs (aging/length baseline)
  if [[ -f /etc/login.defs ]]; then
    info "/etc/login.defs (PASS_*)"
    grep -E -i '^\s*(PASS_MAX_DAYS|PASS_MIN_DAYS|PASS_MIN_LEN|PASS_WARN_AGE)\b' /etc/login.defs | grep -v '^\s*#' || true
  else
    warn "/etc/login.defs 없음"
  fi

  # pwquality (common)
  if [[ -f /etc/security/pwquality.conf ]]; then
    info "/etc/security/pwquality.conf"
    grep -E '^\s*(minlen|dcredit|ucredit|lcredit|ocredit|retry|maxrepeat|maxclassrepeat)\b' /etc/security/pwquality.conf | grep -v '^\s*#' || true
  fi

  # PAM enforcement (Debian/Ubuntu)
  if [[ -f /etc/pam.d/common-password ]]; then
    info "/etc/pam.d/common-password (pwquality/cracklib/history)"
    grep -nE 'pam_pwquality\.so|pam_cracklib\.so|pam_pwhistory\.so' /etc/pam.d/common-password || true
  fi

  # PAM enforcement (RHEL/CentOS/Rocky)
  for f in /etc/pam.d/system-auth /etc/pam.d/password-auth; do
    if [[ -f "$f" ]]; then
      info "$f (pwquality/faillock/history)"
      grep -nE 'pam_pwquality\.so|pam_faillock\.so|pam_pwhistory\.so' "$f" || true
    fi
  done
}

# -----------------------------------------------------------------
# [3] Anonymous FTP (U-62) - check service status + config
# -----------------------------------------------------------------
check_anonymous_ftp() {
  say "\n[3] Anonymous FTP 접속 허용 여부 점검 (U-62)"

  # Candidate config paths
  local cfg=""
  for p in /etc/vsftpd/vsftpd.conf /etc/vsftpd.conf; do
    if [[ -f "$p" ]]; then cfg="$p"; break; fi
  done

  # Check if service exists / active
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl list-unit-files | grep -q '^vsftpd\.service'; then
      local st
      st="$(systemctl is-active vsftpd 2>/dev/null || true)"
      info "vsftpd service state: ${st:-unknown}"
    else
      info "vsftpd.service 없음"
    fi
  fi

  if [[ -n "$cfg" ]]; then
    info "Config: $cfg"
    # ignore comments; find last effective value
    local val
    val="$(grep -E '^\s*anonymous_enable\s*=' "$cfg" | tail -n 1 | cut -d= -f2- | tr -d '[:space:]' || true)"
    if [[ -z "$val" ]]; then
      warn "anonymous_enable 설정을 찾지 못함(기본값/다른 include 가능). 수동 확인 권장"
    elif [[ "$val" =~ ^(NO|no)$ ]]; then
      good "익명 FTP 차단(anonymous_enable=NO)"
    else
      vuln "익명 FTP 허용(anonymous_enable=$val)"
    fi
  else
    good "vsftpd 설정 파일 미존재(미설치/미사용 가능). 다른 FTP 데몬(proftpd/pure-ftpd) 사용 여부는 별도 확인"
  fi
}

# -----------------------------------------------------------------
# [4] SUID/SGID scan (U-13) - save full list + highlight suspicious dirs
# -----------------------------------------------------------------
check_suid_sgid() {
  say "\n[4] SUID/SGID 설정된 파일 검색 (U-13)"
  info "결과는 파일로 저장합니다(증적용)."

  local out_all="$OUT_DIR/suid_sgid_all.txt"
  local out_sus="$OUT_DIR/suid_sgid_suspicious.txt"

  # Default: scan common dirs only (fast). If FULL_SUID_SCAN=1 then scan /
  local scan_paths=(/bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin /opt)
  if [[ "${FULL_SUID_SCAN:-0}" == "1" ]]; then
    warn "FULL_SUID_SCAN=1 → / 전체 스캔(시간 오래 걸릴 수 있음)"
    scan_paths=(/)
  fi

  # Find SUID/SGID files (errors suppressed)
  find "${scan_paths[@]}" -xdev -type f \( -perm -4000 -o -perm -2000 \) -print 2>/dev/null \
    | sort -u > "$out_all" || true

  local cnt
  cnt="$(wc -l < "$out_all" | tr -d ' ')"
  info "SUID/SGID 파일 개수: $cnt"
  info "All list: $out_all"

  # Highlight suspicious locations (commonly abused)
  grep -E '^(/tmp/|/var/tmp/|/dev/shm/|/home/|/var/www/)' "$out_all" > "$out_sus" || true
  if [[ -s "$out_sus" ]]; then
    vuln "의심 경로에 SUID/SGID 파일 존재 → 즉시 검토 필요"
    info "Suspicious list: $out_sus"
    head -n 20 "$out_sus" | sed 's/^/  - /'
  else
    good "의심 경로(/tmp, /home 등)에 SUID/SGID 파일 없음(상대적으로 양호)"
  fi
}

footer() {
  say "\n================================================="
  say "[*] 점검 완료"
  say "[*] Summary: $SUMMARY"
  say "[*] Log:     $LOG"
  say "================================================="
}

main() {
  header
  check_ssh_root_login
  check_password_policy
  check_anonymous_ftp
  check_suid_sgid
  footer
}

main "$@"