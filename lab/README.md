# 실습 환경 (kt cloud 클라우드 네이티브 과정)

모든 실습은 **Ubuntu 24.04 셸**에서 한다. 기본은 **본인에게 배정된 서버 VM**(`ssh ktc-sNN`, 설치 없음).
로컬(Windows → WSL2 / macOS → Lima)은 원하는 사람만 — `make doctor` 통과가 조건.

## 처음 한 번
```bash
git clone <이 저장소> && cd lab
make tools        # 고정 버전 도구 설치 (kubectl, kind, helm, kustomize, k9s) — k8s 템플릿 VM은 이미 설치돼 있음
make doctor       # 환경 점검 → doctor-report.txt 제출
```
## 매일
```bash
make up              # 클러스터 생성 (기본 lite: 노드 1개)
make up PROFILE=full # Service Mesh 과목부터: 노드 3개 (로컬은 메모리 8GB 이상)
make status
make down            # 끝나면 삭제 (자원 반환)
```
- Ingress(Kubernetes 과목 Ingress 실습부터): `make ingress`로 Traefik 설치 → `http://<이름>.localhost`로 열린다 (ingress-nginx는 2026-03 지원 종료)
- 망가지면 `make reset` — 몇 분이면 새 클러스터
