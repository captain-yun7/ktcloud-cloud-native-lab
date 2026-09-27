#!/usr/bin/env bash
# 실습 환경 사전 점검. 결과를 doctor-report.txt 로 남긴다 (OT 전 제출용)
# 옵션: --smoke  kind 클러스터 생성→파드 실행→삭제까지 실제로 해 본다 (3~5분, 이미지 1GB 내려받음)
set -uo pipefail
cd "$(dirname "$0")/.."
R=doctor-report.txt; : > $R
ok=0; warn=0; fail=0
say(){ echo "$1" | tee -a $R; }
pass(){ say "  [OK]   $1"; ok=$((ok+1)); }
wrn(){  say "  [주의] $1"; warn=$((warn+1)); }
bad(){  say "  [문제] $1"; fail=$((fail+1)); }
need(){ [ -z "${2:-}" ] || ver_ok "$1" "$2"; }

say "=== 실습 환경 점검 $(date '+%F %T') ==="
say "[시스템]"
say "  OS: $(. /etc/os-release 2>/dev/null; echo ${PRETTY_NAME:-알 수 없음}) / 커널 $(uname -r) / 아키텍처 $(uname -m)"
case "$(uname -m)" in x86_64) pass "아키텍처 x86_64";; aarch64|arm64) wrn "arm64 (M시리즈 맥): 실습 이미지는 멀티아치 제공, 일부 이미지(mysql 5.7 등) 미지원";; *) bad "지원하지 않는 아키텍처";; esac
grep -qi microsoft /proc/version 2>/dev/null && { grep -q WSL2 /proc/version 2>/dev/null || [ -d /run/WSL ] && pass "WSL2" || bad "WSL1로 보임 → 'wsl --set-version Ubuntu-24.04 2' 필요"; }
MEM=$(free -g | awk '/Mem/{print $2}'); DISK=$(df -BG --output=avail "$HOME" | tail -1 | tr -dc 0-9)
[ "$MEM" -ge 7 ] && pass "메모리 ${MEM}GB (full 가능)" || { [ "$MEM" -ge 5 ] && wrn "메모리 ${MEM}GB (lite만 권장. WSL은 .wslconfig, Lima는 --memory 로 늘릴 수 있음)" || bad "메모리 ${MEM}GB — 최소 6GB 필요"; }
[ "$DISK" -ge 30 ] && pass "디스크 여유 ${DISK}GB" || bad "디스크 여유 ${DISK}GB — 30GB 이상 필요"
say "[Docker]"
if command -v docker >/dev/null; then
  if docker info >/dev/null 2>&1; then pass "docker 실행 가능 ($(docker --version | awk '{print $3}' | tr -d ,))"; else bad "docker 명령은 있으나 권한/데몬 문제 → 'sudo usermod -aG docker \$USER' 후 재로그인, 'sudo systemctl start docker'"; fi
  docker info 2>/dev/null | grep -q "mirror.gcr.io" && pass "이미지 미러 mirror.gcr.io 설정됨" || wrn "이미지 미러 없음 → /etc/docker/daemon.json 확인 (서버 VM은 기본 설정됨, 로컬은 선택)"
else bad "docker 없음 → 설치 가이드 참고"; fi
say "[도구 버전 (.mise.toml 기준)]"
for t in kubectl kind helm kustomize k9s; do
  want=$(grep "^$t" .mise.toml | sed 's/.*"\(.*\)"/\1/')
  if command -v $t >/dev/null; then
    case $t in kubectl) have=$(kubectl version --client -o json 2>/dev/null | grep -o '"gitVersion": *"v[^"]*' | grep -o 'v.*' | tr -d v);;
      kind) have=$(kind version 2>/dev/null | awk '{print $2}' | tr -d v);;
      helm) have=$(helm version --template '{{.Version}}' 2>/dev/null | tr -d v);;
      kustomize) have=$(kustomize version 2>/dev/null | grep -o 'v[0-9.]*' | head -1 | tr -d v);;
      k9s) have=$(k9s version -s 2>/dev/null | awk '/Version/{print $2}' | tr -d v);; esac
    [ "$have" = "$want" ] && pass "$t $have" || wrn "$t $have (기준 $want) → make tools"
  else bad "$t 없음 → make tools"; fi
done
if [ "${1:-}" = "--smoke" ]; then
  say "[실제 동작 시험]"
  if kind create cluster --name doctor --wait 120s >/dev/null 2>&1; then
    if kubectl run doctor --image=nginx:alpine --restart=Never >/dev/null 2>&1 && kubectl wait --for=condition=Ready pod/doctor --timeout=120s >/dev/null 2>&1; then pass "kind 클러스터 생성 + 파드 실행 성공"; else bad "파드 실행 실패 (이미지 pull 또는 네트워크 문제)"; fi
    kind delete cluster --name doctor >/dev/null 2>&1
  else bad "kind 클러스터 생성 실패 (docker 권한/메모리 확인)"; fi
fi
say "=== 결과: 정상 $ok / 주의 $warn / 문제 $fail ==="
[ $fail -eq 0 ] && say "→ 실습 가능. doctor-report.txt 를 제출하세요." || say "→ [문제] 항목을 해결한 뒤 다시 실행하세요. 안 되면 doctor-report.txt 내용을 Discord에 올리세요."
exit $fail
