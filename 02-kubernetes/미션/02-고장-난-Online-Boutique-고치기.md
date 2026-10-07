[← 미션 1](./01-Online-Boutique를-쿠버네티스로-옮기기.md) · [목차](../Kubernetes-미션.md)

# 미션 2. 고장 난 Online Boutique 고치기

**무엇을 하나요**: 누군가 Online Boutique를 `broken` 네임스페이스에 배포했는데 사이트가 열리지 않습니다. **고장이 6개** 숨어 있습니다. 교안 08장의 순서(**get → describe → logs**, 그리고 Service는 엔드포인트)로 하나씩 찾아 고칩니다. 목표: **홈 화면과 장바구니가 모두 열리게** 하는 것.

> **바로 가기** · [준비](#준비) · [규칙](#규칙) · [힌트](#힌트) · [도전 (선택)](#도전-선택) · [미션 2 결과 정리 표](#미션-2-결과-정리-표) · [미션 2 정리](#미션-2-정리)

## 준비

고장 난 파일은 학생 저장소의 `02-kubernetes/shop-broken.yaml`입니다.

```bash
cd ~/ktcloud-cloud-native-lab && git pull
mkdir -p ~/k8s-mission2 && cd ~/k8s-mission2
cp ~/ktcloud-cloud-native-lab/02-kubernetes/shop-broken.yaml .
kubectl create namespace broken
kubectl apply -n broken -f shop-broken.yaml
```

브라우저: 터미널 1에서 `kubectl port-forward -n broken svc/frontend 8090:80` → `http://localhost:8090` (frontend가 고장 나 있으면 port-forward도 실패합니다 — 그것도 증상)

## 규칙
- `shop-broken.yaml`을 **고친 뒤 `kubectl apply -n broken -f shop-broken.yaml`** 하는 방식으로 고칩니다
- 고장 하나를 찾을 때마다 **증상 → 찾은 방법(명령) → 원인 → 고친 내용**을 결과 정리 표에 적습니다
- 파드가 `Running`이라고 정상인 것은 아닙니다

## 힌트
<details><summary>힌트 1 — 어디서부터 볼까</summary>

`kubectl get pods -n broken`의 STATUS에서 이상한 것 3개가 바로 보입니다. 각각 `kubectl describe pod -n broken <이름>`의 Events 마지막 줄을 읽으세요. 나머지 3개는 파드가 멀쩡해 보입니다 — 그때는 frontend의 로그를 보세요.
</details>
<details><summary>힌트 2 — 파드가 멀쩡한데 안 될 때</summary>

`kubectl get endpointslices -n broken`에서 Service마다 **파드 IP가 붙었는지**(`<unset>`이면 셀렉터), **PORTS가 컨테이너 포트와 같은지**(아니면 `targetPort`) 확인하세요.
</details>
<details><summary>힌트 3 — frontend 로그에 계속 나오는 cart 오류</summary>

`kubectl logs -n broken deploy/cartservice`와 cartservice의 환경변수(`shop-broken.yaml`의 cartservice 부분, 또는 `kubectl get deploy -n broken cartservice -o yaml | grep -A1 REDIS`)를 보세요. 이 이미지에는 `env` 명령이 없어 `kubectl exec … -- env`는 안 됩니다. 그 주소의 Service가 실제로 있나요(`kubectl get svc -n broken`)?
</details>
<details><summary>힌트 4 — 계속 재시작하는 파드</summary>

`describe`의 Events에 무엇이 실패했다고 나오나요? 앱이 실제로 쓰는 포트와 비교하세요(실습 9 4단계).
</details>

## 도전 (선택)
1. 고친 매니페스트의 서비스마다 **readinessProbe**를 넣어 보세요. frontend는 HTTP(`/_healthz`, 8080), 나머지는 gRPC(`grpc: {port: <포트>}`) — 공식 매니페스트(`~/ob/kubernetes-manifests/*.yaml`)를 참고
2. 고장 하나를 **직접 만들어** 파일로 남기고, 옆 사람과 바꿔 증상만 보고 원인을 찾아 보세요

## 미션 2 결과 정리 표

| # | 증상 | 찾은 방법 (명령) | 원인 | 고친 내용 |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |
| 6 | | | | |
| 최종 | 홈·장바구니 캡처 | | | |

## 미션 2 정리
결과 정리 표를 채운 뒤 `kubectl delete namespace broken`.
