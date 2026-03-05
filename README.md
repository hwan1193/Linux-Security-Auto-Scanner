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
