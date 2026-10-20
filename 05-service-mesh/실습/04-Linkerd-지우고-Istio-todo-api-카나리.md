[← 실습 3](./03-db는-api만-서비스-계정-신분으로.md) · [목차](../서비스-메시-실습.md) · [실습 5 →](./05-타임아웃-재시도-장애-주입.md)

# 실습 4. Linkerd 지우고 Istio, todo-api 카나리

**무엇을 하나요**: Linkerd를 순서를 어기고 먼저 지워 보아 **거부되는 것**을 본 뒤, 순서대로 지우고 두 번째 메시 도구 **Istio**를 설치해 todo에 다시 주입합니다. 그다음 CI/CD 실습 7처럼 api를 한 줄 고친 **todo-api v2**를 만들어 v1 옆에 띄우고, 규칙 없이 반반으로 나뉘는 것을 본 뒤 Istio 규칙으로 **v1 90%, v2 10%**, 헤더 `x-canary: true`는 **항상 v2**로 보냅니다. (교안 04장)

**필요한 것**: 실습 3까지의 todo(Linkerd 주입, `load`가 계속 요청 중).

> **바로 가기** · [1. Linkerd 먼저 지워 보기 — 거부](#1단계-linkerd-먼저-지워-보기--거부) · [2. 순서대로 지우기](#2단계-순서대로-지우기) · [3. Istio 설치하고 todo에 주입](#3단계-istio-설치하고-todo에-주입) · [4. todo-api v2 만들기](#4단계-todo-api-v2-만들기) · [5. 규칙 없이 100번 — 반반쯤](#5단계-규칙-없이-100번--반반쯤) · [6. 90:10과 헤더 — canary.yaml](#6단계-9010과-헤더--canaryyaml) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. Linkerd 먼저 지워 보기 — 거부

```bash
linkerd uninstall | kubectl delete -f -
kubectl get crd | grep -c linkerd
```

**이 명령은**: 파드에 프록시가 붙은 채로 Linkerd를 지워 봄. 두 번째 줄 = 이름에 linkerd가 든 리소스 종류(CRD)의 개수.

**이렇게 나오면 성공**(거부되는 것이 정상)

```
Please uninstall the following extensions before uninstalling the control-plane:
	* viz
Please uninject the following pods before uninstalling the control-plane:
	* api-79d57968fd-gqg2b
	* db-b5ddd4dfb-wbf4x
	* load-d469f5865-srjsr
	* web-6fbbf5bcd8-7hg8t
No resources found
10
```

- `linkerd uninstall`이 지울 목록을 **출력하지 않고** 거부합니다. 넘겨받은 것이 없으니 `kubectl delete`는 `No resources found` — 아무것도 안 지워졌고 CRD도 10개 그대로
- 거부 이유 두 가지: 확장(viz)이 남아 있음, **프록시가 붙은 파드**가 남아 있음. 프록시는 제어 영역에서 인증서·주소를 받으므로 파드에서 프록시를 먼저 빼야 합니다

## 2단계. 순서대로 지우기

```bash
kubectl annotate ns todo linkerd.io/inject-
kubectl -n todo rollout restart deploy
kubectl get pods -A | grep -E " 2/2 | 3/3 | 4/4 "     # 30초쯤 뒤 — linkerd 줄만 남아야 함
linkerd viz uninstall | kubectl delete -f -
linkerd uninstall | kubectl delete -f -
kubectl get crd | grep -c linkerd                     # 0
kubectl -n todo get pods                              # 모두 1/1
```

**이 명령은**: 주석 이름 끝의 `-` = 그 주석을 지움 → 파드를 다시 만들어 프록시를 뺌 → 남은 `2/2` 이상 파드가 linkerd 네임스페이스뿐인지 확인 → 확장 viz → 본체 순서로 지움.

**이렇게 나오면 성공**: `grep` 결과에 `linkerd`·`linkerd-viz` 줄만, 마지막 CRD 수 `0`, todo 파드는 모두 `1/1`(강사 VM에서 두 uninstall 합쳐 약 22초).

```
0
NAME                    READY   STATUS    RESTARTS   AGE
api-65b64f8b5-7tw2z     1/1     Running   0          55s
db-5d94b4c9f-fql8f      1/1     Running   0          55s
load-5d47b9695d-kvg9c   1/1     Running   0          55s
web-f89f5d99-bqzs8      1/1     Running   0          54s
```

| | 순서를 어기면 (1단계) | 순서대로 (지금) |
|---|---|---|
| `linkerd uninstall` | 거부 — `Please uninject …` | 지울 YAML 출력 |
| `kubectl get crd \| grep -c linkerd` | 10 (그대로) | 0 |

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `Please uninject the following pods …` | 재시작이 아직 안 끝났거나 주석을 안 지움 | `grep` 결과에 todo 파드가 없어질 때까지 기다린 뒤 다시 |
| `Please uninstall the following extensions …` | viz를 먼저 안 지움 | `linkerd viz uninstall \| kubectl delete -f -` 먼저 |

</details>

## 3단계. Istio 설치하고 todo에 주입

```bash
cd ~/ktcloud-cloud-native-lab/lab
istioctl x precheck
istioctl install -f istio/istio.yaml -y           # 약 13초
kubectl -n istio-system get pods
kubectl label ns todo istio-injection=enabled
kubectl -n todo rollout restart deploy
kubectl -n todo get pods                          # 30초쯤 뒤 모두 2/2
```

**이 명령은**: `istioctl x precheck` = 설치 전 점검. `istioctl install -f` = 설정 파일대로 설치(minimal = 제어 영역 `istiod`만, 사이드카 요청 자원을 줄인 설정). Istio의 주입 표시는 네임스페이스 **라벨** `istio-injection=enabled`입니다.

**이렇게 나오면 성공**: `✔ Installation complete`, `istiod … 1/1 Running`, todo 파드 모두 `2/2`.

```
✔ No issues found when checking the cluster. Istio is safe to install or upgrade!
✔ Istiod installed 🧠
✔ Installation complete
NAME                      READY   STATUS    RESTARTS   AGE
istiod-5cf8f5d6df-lhwpz   1/1     Running   0          12s
```

| | Linkerd (실습 1~3) | Istio (지금부터) |
|---|---|---|
| 주입 표시 | 네임스페이스 **주석** `linkerd.io/inject=enabled` | 네임스페이스 **라벨** `istio-injection=enabled` |
| 제어 영역 | 파드 3개(identity · destination · proxy-injector) | `istiod` 하나 |
| 프록시 | linkerd-proxy | Envoy(`istio-proxy`) |
| 트래픽 규칙 | HTTPRoute(Gateway API) | VirtualService · DestinationRule (이 실습) |

## 4단계. todo-api v2 만들기

CI/CD 실습 7과 같은 한 줄을 고쳐 `/api/health` 응답에 `version: 2`를 더한 이미지를 만듭니다. 실습 저장소 원본은 건드리지 않게 `~/mesh`에 복사해서 고칩니다.

```bash
cd ~/mesh
cp -r ~/ktcloud-cloud-native-lab/lab/docker/todo/api api-v2
sed -i "s/res.json({ ok: true })/res.json({ ok: true, version: 2 })/" api-v2/app.js
grep -n "api/health" api-v2/app.js
docker build -t todo-api:v2 api-v2
kind load docker-image todo-api:v2 --name lab
nano api-v2.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata: {name: api-v2, namespace: todo}
spec:
  selector:
    matchLabels: {app: api, version: v2}
  template:
    metadata:
      labels: {app: api, version: v2}
    spec:
      containers:
      - name: api
        image: todo-api:v2
        envFrom:
        - configMapRef: {name: todo-config}
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef: {name: todo-secret, key: DB_PASSWORD}
        ports:
        - containerPort: 3000
```

```bash
kubectl -n todo patch deploy api -p '{"spec":{"template":{"metadata":{"labels":{"version":"v1"}}}}}'
kubectl apply -f api-v2.yaml
kubectl -n todo get pods -l app=api -L version     # 30초쯤 뒤
```

**이 명령은**: 고친 소스로 `todo-api:v2`를 만들어 노드에 넣고, v2 Deployment를 띄움. v2는 라벨 `app: api`가 v1과 같아서 **기존 Service api가 두 버전을 모두** 고릅니다. 마지막 `patch` = 기존 api 파드에 라벨 `version: v1`을 붙임(파드가 한 번 다시 만들어짐). `-L version` = 라벨 version을 열로 보여 줌.

**이렇게 나오면 성공**

```
18:app.get('/api/health', (req, res) => res.json({ ok: true, version: 2 }));
```
```
NAME                     READY   STATUS    RESTARTS   AGE   VERSION
api-78d47b7f85-zgmq2     2/2     Running   0          19s   v1
api-v2-87bbfcc4d-cmx57   2/2     Running   0          19s   v2
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `grep` 결과가 `{ ok: true }` 그대로 | sed가 못 바꿈 | `nano api-v2/app.js`로 `{ ok: true, version: 2 }` |
| api-v2가 `ErrImageNeverPull` | `kind load` 빠뜨림 | `kind load docker-image todo-api:v2 --name lab` 후 `kubectl -n todo rollout restart deploy/api-v2` |
| VERSION 열이 빈 api 파드 | `patch`를 빠뜨림 | `patch` 줄 다시 — 6단계의 v1 묶음이 비어 503이 나는 원인 |

</details>

## 5단계. 규칙 없이 100번 — 반반쯤

```bash
L="kubectl -n todo exec deploy/load -c curl --"
$L sh -c 'for i in $(seq 1 100); do curl -s http://web/api/health; echo; done' | sort | uniq -c
$L sh -c 'for i in $(seq 1 10); do curl -s -H x-canary:true http://web/api/health; echo; done' | sort | uniq -c
```

**이 명령은**: `L=…` = 긴 명령 앞부분을 변수에 담아 `$L`로 줄여 씀(이 터미널에서만 유효). `load` 안에서 web을 거쳐 api의 `/api/health`를 100번 부르고 응답별 개수를 셈. 둘째 줄은 헤더 `x-canary: true`를 붙여 10번.

**이렇게 나오면 성공**: 규칙이 없으면 파드 수(1:1)대로 반반쯤, 헤더도 소용없음.

```
     41 {"ok":true}
     59 {"ok":true,"version":2}
```
```
      3 {"ok":true}
      7 {"ok":true,"version":2}
```

- 10%만 보내려면 지금 방법으로는 v1을 9개로 늘려야 합니다. 1%면 파드 100개. 그리고 "테스터만 v2"는 할 수 없습니다

## 6단계. 90:10과 헤더 — canary.yaml

```bash
nano canary.yaml
```

```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata: {name: api, namespace: todo}
spec:
  host: api
  subsets:
  - name: v1
    labels: {version: v1}
  - name: v2
    labels: {version: v2}
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata: {name: api, namespace: todo}
spec:
  hosts: [api]
  http:
  - match:
    - headers:
        x-canary: {exact: "true"}
    route:
    - destination: {host: api, subset: v2}
  - route:
    - destination: {host: api, subset: v1}
      weight: 90
    - destination: {host: api, subset: v2}
      weight: 10
```

| 리소스 | 하는 일 |
|---|---|
| DestinationRule `api` | 목적지 api의 파드를 라벨로 **묶음(subset)** 으로 나눔 — v1, v2 |
| VirtualService `api` | `api`로 가는 요청을 **어느 묶음으로** — 위에서부터: 헤더 `x-canary: true`면 v2, 나머지는 v1 90 · v2 10 |

```bash
kubectl apply -f canary.yaml
$L sh -c 'for i in $(seq 1 200); do curl -s http://web/api/health; echo; done' | sort | uniq -c
$L sh -c 'for i in 1 2 3 4 5; do curl -s -H x-canary:true http://web/api/health; echo; done' | sort | uniq -c
```

**이렇게 나오면 성공**: 200번 중 v2가 20번 안팎, 헤더는 5번 모두 v2. 파드는 여전히 v1 1개, v2 1개입니다.

```
    188 {"ok":true}
     12 {"ok":true,"version":2}
```
```
      5 {"ok":true,"version":2}
```

| | 파드 수로 (5단계) | 메시 규칙으로 (지금) |
|---|---|---|
| v2에 10% | v1 9개 + v2 1개 필요 | 파드 2개 + `weight: 90`·`10` |
| 1%로 하려면 | 파드 100개 | `weight: 99`·`1` |
| 테스터만 v2로 | 안 됨 | 헤더 `x-canary: true` → 항상 v2 |
| 되돌리기 | 파드 수 바꾸기 | `weight: 100`·`0` |

- 규칙은 api 쪽이 아니라 **부르는 쪽(web 옆 프록시)** 이 지킵니다. 그래서 손님(`load`)이 web에 붙인 헤더가 web → api 구간에서 쓰입니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 여전히 반반 | 적용 직후 몇 초는 흔들림 | 5초쯤 기다렸다 다시 |
| 아무것도 안 나옴 | 새 터미널이라 `L`이 없음 | 5단계의 `L="…"` 줄을 다시 |
| 일부가 `no healthy upstream` | v1 파드에 `version: v1` 라벨이 없음(4단계 `patch`) | `kubectl -n todo get pods -l app=api -L version` 확인, `istioctl analyze -n todo` |
| 헤더를 붙였는데 섞여 나옴 · `Warning: virtualService rule #1 not used` | `match` 묶음이 비율 묶음보다 아래 | `canary.yaml`에서 `- match:` 묶음을 위로 |

</details>

## 끝났는지 확인
- ☐ 순서를 어긴 `linkerd uninstall`이 `Please uninject …`로 거부되는 것을 봄
- ☐ `kubectl get crd | grep -c linkerd`가 `0`, `istiod` `1/1`, todo 모두 `2/2`
- ☐ 규칙 없이 반반쯤 → `canary.yaml` 뒤 200번 중 v2가 20번 안팎
- ☐ `x-canary:true` 5번 모두 v2

## 정리
- 실습 3에서 만든 네임스페이스 `other`를 지웁니다: `kubectl delete ns other`
- todo·api-v2·`canary.yaml`은 실습 5에서 계속 씁니다

## 확인 문제
1. `canary.yaml`의 `weight`를 `50`·`50`으로 바꿔 적용하면 200번 중 v2는 몇 번쯤 나올까요?
2. 헤더 규칙(`- match:` 묶음)을 비율 규칙 **아래**로 옮겨 적용하면 `x-canary:true` 요청은 어떻게 될까요? 적용할 때 화면에 무엇이 나오나요?
