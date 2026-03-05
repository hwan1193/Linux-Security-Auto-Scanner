#!/usr/bin/env bash
# =================================================================
# secscan_rhel9_kisa.sh
# Rocky/RHEL 9 baseline security check pack (evidence-friendly)
# Output: /var/tmp/secscan_<timestamp>/ (log + summary + artifacts)
# =================================================================

set -euo pipefail
IFS=$'\n\t'

TS="$(date '+%F_%H-%M-%S')"
OUT_DIR="${OUT_DIR:-/var/tmp/secscan_${TS}}"
mkdir -p "$OUT_DIR"

LOG="$OUT_DIR/scan.log"
SUMMARY="$OUT_DIR/summary.txt"
ARTIFACTS="$OUT_DIR/artifacts"
mkdir -p "$ARTIFACTS"
: > "$SUMMARY"

# Tee all outputs to log (evidence)
exec > >(tee -a "$LOG") 2>&1

say()   { echo -e "$*"; }
good()  { say "  [양호] $*"; echo -e "[양호] $*" >> "$SUMMARY"; }
vuln()  { say "  [취약] $*"; echo -e "[취약] $*" >> "$SUMMARY"; }
warn()  { say "  [주의] $*"; echo -e "[주의] $*" >> "$SUMMARY"; }
info()  { say "  [*] $*"; }

need_root_note() {
  if [[ "${EUID}" -ne 0 ]]; then
    warn "root 권한이 아니면 일부 항목(예: /etc/shadow, 전체 스캔)이 누락될 수 있음"
  fi
}

header() {
  say "================================================="
  say "[*] RHEL/Rocky 9 보안 점검 시작 (KISA starter + 운영증적)"
  say "    - Output: $OUT_DIR"
  say "================================================="
  need_root_note
}

footer() {
  say "\n================================================="
  say "[*] 점검 완료"
  say "[*] Summary:   $SUMMARY"
  say "[*] Log:       $LOG"
  say "[*] Artifacts: $ARTIFACTS"
  say "================================================="
}

main() {
  header

  export OUT_DIR LOG SUMMARY ARTIFACTS
  export -f say good vuln warn info

  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  # Run modules in numeric order
  local m
  for m in "$here"/modules/*.sh; do
    [[ -f "$m" ]] || continue
    info "\n--- Running module: $(basename "$m") ---"
    bash "$m"
  done

  footer
}

main "$@"
