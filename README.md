# secscan_rhel9_kisa

Rocky/RHEL 9용 KISA 스타일 보안 점검 스타터 팩입니다.

## Run
```bash
chmod +x secscan_rhel9_kisa.sh
sudo ./secscan_rhel9_kisa.sh
```

## Output
기본 출력 경로: `/var/tmp/secscan_<timestamp>/`
- `scan.log`: 전체 실행 로그(증적)
- `summary.txt`: 양호/취약/주의 요약
- `artifacts/`: 설정 파일/명령 결과 캡처

## Options
- `OUT_DIR=/path`: 결과 저장 경로 변경
- `FULL_SUID_SCAN=1`: SUID/SGID를 `/` 전체 스캔(시간 증가)

본 프로젝트는 KISA 주요 정보통신기반시설 기술적 취약점 분석 가이드를 기반으로, 
RHEL 9 / Rocky Linux 9 환경의 핵심 보안 취약점을 빠르게 스캔하고 **운영 증적(Artifacts)을 자동 수집**하는 모듈형 쉘 스크립트입니다.

> 💡 **목적:** 대규모 인프라 환경에서 보안 점검 및 인증 심사(ISO 27001 등) 시, 담당자의 수동 점검 리소스 최소화 및 증거 자료(Evidence) 자동화 패키징

## 🚀 Key Features

* **Modular Architecture:** 각 보안 영역(SSH, PAM, SUID, 방화벽 등)별 모듈화 (`modules/*.sh`)
* **Auto-Evidence Collection:** 스캔 결과를 자동 수집하여 점검 증거 파일로 생성
    * `summary.txt` : 양호 / 취약 / 주의 항목 요약 레포트
    * `scan.log` : 전체 실행 디버깅 로그
    * `artifacts/` : 각 설정 파일(`sshd_config`, `login.defs` 등) 및 명령어 출력 원본 덤프
* **Flexible Execution Options:**
    * `FULL_SUID_SCAN=1` : 파일시스템 전체 SUID/SGID 정밀 스캔
    * `OUT_DIR` : 보안 점검 결과물 저장 경로 커스텀 지정

## ⚙️ System Requirements

* **OS:** Rocky Linux 9.x / AlmaLinux 9.x / RHEL 9.x
* **Privilege:** Root 권한 (혹은 sudo) 필요

## 🛠️ Security Check Modules

* `10_os_info.sh`: OS / Kernel / Hostname 등 시스템 기본 정보 증적
* `20_ssh_hardening.sh`: SSH 접근 통제 (KISA U-01) - Root 로그인, 패스워드 인증 제한 점검
* `30_password_pam.sh`: 패스워드 복잡도 및 PAM 정책 (KISA U-02 확장) - pwquality, faillock 점검
* `35_account_basic.sh`: 관리자 권한 남용 점검 - UID 0 계정, 빈 패스워드, sudo NOPASSWD 설정 확인
* `40_ftp_anonymous.sh`: 익명 FTP 접속 허용 여부 (KISA U-62)
* `50_suid_sgid.sh`: 악성 권한 상승 탐지용 SUID/SGID 파일 스캔 (KISA U-13)
* `60_firewalld_ports.sh`: 방화벽(Firewalld) 상태 및 Listening Port 점검
* `70_selinux.sh`: SELinux 동작 상태 점검
* `80_logging_auditd.sh`: Auditd 및 시스템 로깅 활성화 상태 점검
* `90_time_sync.sh`: NTP/Chrony 시간 동기화 상태 점검

### 2026-03-06
- **모듈 추가 적용**
  - `55_file_permissions.sh` (핵심 파일/디렉토리 권한 점검)
  - `65_services_minimize.sh` (enabled/active 서비스 점검)
  - `75_cron_autostart.sh` (cron + systemd timers 점검)
  - `95_patch_security.sh` (dnf security advisory 기반 보안 업데이트 점검)

- **Bug Fix: 55_file_permissions.sh bash octal 연산 오류 수정**
  - 증상: `value too great for base (error token is "0o002" / "0o020")`
  - 원인: bash 산술식에서 `0o###` (python-style octal) 미지원
  - 조치: `0o###` → bash 호환 옥탈(`0002`, `0020` 등)로 변환 후 재배포
  - 결과: 55 모듈 정상 실행 확인 (권한 점검 결과 출력 및 artifacts 저장 정상)

- **Run Evidence**
  - Output: `/var/tmp/secscan_2026-03-06_06-09-53/`
  - Summary: `/var/tmp/secscan_2026-03-06_06-09-53/summary.txt`
  - Artifacts: `/var/tmp/secscan_2026-03-06_06-09-53/artifacts/`

### Known Findings (Follow-up)
- `PermitRootLogin=without-password` : Root 키 로그인 허용 상태 → 정책이 `no`면 취약 판정/예외 승인 필요
- `sudo NOPASSWD` 발견(azureuser 포함) → 최소권한/명령 제한/예외 승인 검토 필요
- `rpcbind.socket` 활성 → 미사용 시 disable 권장
- 보안 업데이트 및 reboot 필요 가능성(needs-restarting) → 패치 윈도우 내 검토

## 💻 Quick Start & Usage

상세한 실행 명령어 및 옵션 사용법은 레포지토리 내 [`Command_CheatSheet.txt`](./Linux-Sec-Scanner_CheatSheet.txt) 파일을 참고하십시오.

## ⚠️ Notes & Policy (예외 처리 기준)

* `permitrootlogin=without-password`: 현재 Root 키 로그인이 허용된 상태입니다. 조직의 ISMS/ISO 인증 정책에 따라 `no`로 강제해야 할 경우 [취약]으로 자체 분류해야 합니다.
* `sudo NOPASSWD`: 운영 자동화(Ansible 등)를 위해 허용된 경우, 접근 통제(ACL) 정책과 교차 검증하여 예외 처리 기안이 필요합니다.

<img width="615" height="435" alt="image" src="https://github.com/user-attachments/assets/103e93de-fe3b-49db-9997-5d1b52b5b504" />

