[← 실습 9](./09-Probe-준비됐나-살아-있나.md) · [목차](../Kubernetes-실습.md) · [실습 11 →](./11-Ingress-주소-하나로-나눠-보내기.md)

# 실습 10. requests와 limits — 얼마나 쓰나

**무엇을 하나요**: hello 파드에 CPU·메모리 **requests**(예약)와 **limits**(최대)를 적습니다. 그리고 너무 많이 예약해서 자리를 못 잡는 파드(`Pending`)와, 메모리 최대치를 넘어 강제로 꺼지는 파드(`OOMKilled`)를 일부러 만들어 봅니다. 그 전에 **아무것도 안 적은 파드가 노드 자원을 마음대로 쓰는 것**을 먼저 보고, 마지막으로 사용량에 따라 개수를 자동으로 늘리는 HPA를 봅니다. (교안 08장)

**필요한 것**: 실습 9의 `probe.yaml`(hello).

> **바로 가기** · [1. 안 적으면 어떻게 되나](#1단계-안-적으면-어떻게-되나--한-파드가-다-쓴다) · [2. requests·limits 넣기](#2단계-requestslimits-넣기) · [3. 일부러 실패하는 파드 두 개](#3단계-일부러-실패하는-파드-두-개) · [4. 자동으로 늘리기 — HPA](#4단계-자동으로-늘리기--hpa) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 안 적으면 어떻게 되나 — 한 파드가 다 쓴다

지금까지 만든 파드에는 CPU·메모리를 얼마나 쓸지 아무것도 적지 않았습니다. 그러면 쿠버네티스는 이 파드가 **얼마나 쓸지 모르고, 얼마나 쓰든 막지 않습니다.** 메모리를 300Mi까지 쓰는 파드 `hog`로 확인합니다.

```bash
cd ~/ktcloud-cloud-native-lab/lab/k8s/hello
nano hog.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hog
spec:
  containers:
  - name: hog
    image: busybox:1.37
    command: ["sh", "-c", "tail -c 314572800 /dev/zero"]
```

- `tail -c 314572800 /dev/zero` = 끝없이 나오는 0을 읽으며 마지막 300MB(314,572,800바이트)를 메모리에 쥐고 있음. 메모리를 많이 쓰는 앱(또는 메모리가 새는 버그)을 흉내 냄

```bash
kubectl apply -f hog.yaml
kubectl top pod hog
kubectl get pod hog -o jsonpath='{.status.qosClass}'; echo
kubectl describe node lab-control-plane | grep hog
```

`top`이 `not found`이면 30초쯤 뒤 다시 칩니다.

**이렇게 나오면 성공**

```
NAME   CPU(cores)   MEMORY(bytes)
hog    998m         300Mi
BestEffort
  default    hog    0 (0%)    0 (0%)    0 (0%)    0 (0%)    41s
```

| 화면 | 뜻 |
|---|---|
| `998m · 300Mi` | 파드 하나가 **CPU 1개를 통째로**, 메모리를 300Mi 씀. 아무도 막지 않음. 메모리가 새는 앱이라면 노드의 메모리가 바닥날 때까지 늘어남 |
| `BestEffort` | 아무것도 적지 않은 파드의 등급. 노드 메모리가 모자라면 **가장 먼저 쫓겨남** |
| `0 (0%)` 네 개 | 이 파드가 예약한 CPU·메모리가 0. 스케줄러는 이 파드가 얼마나 쓸지 모른 채 노드에 둠 — 이런 파드가 한 노드에 몰리면 노드가 버티지 못함 |

이번에는 `limits`로 메모리 상한 128Mi를 줍니다. `command:` 줄 바로 위에 세 줄을 넣습니다.

```bash
kubectl delete pod hog --now
nano hog.yaml
```

```yaml
    image: busybox:1.37
    resources:
      limits:
        memory: 128Mi
    command: ["sh", "-c", "tail -c 314572800 /dev/zero"]
```

```bash
kubectl apply -f hog.yaml
kubectl get pod hog
kubectl describe pod hog | grep -A3 "Last State"
```

**이렇게 나오면 성공**: 몇 초 안에 `hog   0/1   OOMKilled`(또는 `CrashLoopBackOff`), `Reason: OOMKilled`, `Exit Code: 137`.

- 상한(128Mi)을 넘자 **hog만** 꺼졌습니다. 같은 노드의 hello·todo 파드는 그대로입니다(`kubectl get pods`). 안 적었을 때는 hog가 노드 자원을 마음대로 썼고, 적으니 그 파드 안에서 끝났습니다
- 그래서 실제 서비스의 파드에는 **requests(이만큼 자리를 잡아 줘)와 limits(이 이상은 못 씀)를 적습니다.** 2단계에서 hello에 넣습니다

다 봤으면 지웁니다.

```bash
kubectl delete pod hog --now
```

## 2단계. requests·limits 넣기

`probe.yaml`에 `resources:` 7줄을 더한 `res.yaml`을 씁니다.

```bash
cd ~/ktcloud-cloud-native-lab/lab/k8s/hello
cp probe.yaml res.yaml
nano res.yaml            # 맨 아래에 아래 7줄을 붙임 (livenessProbe와 같은 들여쓰기, 스페이스 8칸)
```

```yaml
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
```

`cat res.yaml`로 맨 아래가 이렇게 끝나는지 봅니다.

```yaml
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          periodSeconds: 5
          failureThreshold: 3
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
```

| 줄 | 뜻 |
|---|---|
| `requests: cpu: 50m` | CPU 0.05개를 **예약**. 노드에 이만큼 남은 자리가 있어야 파드를 둠 |
| `requests: memory: 64Mi` | 메모리 64Mi를 예약 |
| `limits: cpu: 200m` | CPU는 최대 0.2개까지. 넘으면 느려짐(꺼지지는 않음) |
| `limits: memory: 128Mi` | 메모리는 최대 128Mi. **넘으면 강제로 꺼짐**(OOMKilled) |

- `m` = 1000분의 1(1000m = CPU 1개), `Mi` = 메비바이트(약 1MB)

```bash
kubectl apply -f res.yaml
kubectl rollout status deployment/hello
kubectl top pods
kubectl describe node lab-control-plane | grep -A5 "Allocated resources"
```

**이렇게 나오면 성공**

```
NAME                     CPU(cores)   MEMORY(bytes)
api-59db9ddfbf-7sl7t     1m           14Mi
client                   0m           0Mi
db-86878656ff-xj48l      1m           19Mi
hello-5cc5d79c76-g5ds8   4m           15Mi
hello-5cc5d79c76-gjn8p   1m           13Mi
hello-5cc5d79c76-rgs9c   1m           13Mi
web-5f559d65d7-hzzlv     0m           4Mi
```
```
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests     Limits
  --------           --------     ------
  cpu                1200m (30%)  600m (15%)
  memory             682Mi (4%)   724Mi (4%)
```

- `kubectl top pods` = 지금 **실제로 쓰는** 양. hello는 메모리 13~15Mi쯤
- `Allocated resources` = 노드에서 **예약된** 양의 합계(클러스터 구성 요소 포함). 4코어 노드의 30%가 예약됨
- `top`이 `metrics not available yet`이면 새 파드라 아직 숫자가 없는 것. 30초쯤 뒤 다시

## 3단계. 일부러 실패하는 파드 두 개

```bash
nano res-test.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: big
spec:
  containers:
  - name: hello
    image: hello:v1
    resources:
      requests:
        cpu: "8"
---
apiVersion: v1
kind: Pod
metadata:
  name: tiny
spec:
  containers:
  - name: hello
    image: hello:v1
    resources:
      limits:
        memory: 8Mi
```

- `big` = CPU **8개**를 예약(노드는 4코어) / `tiny` = 메모리 최대 **8Mi**(앱은 13Mi쯤 씀)

```bash
kubectl apply -f res-test.yaml
kubectl get pods big tiny
```

20초쯤 뒤 다시 봅니다.

**이렇게 나오면 성공**

```
NAME   READY   STATUS      RESTARTS      AGE
big    0/1     Pending     0             20s
tiny   0/1     OOMKilled   2 (19s ago)   20s
```

이유를 봅니다.

```bash
kubectl describe pod big | tail -2
kubectl describe pod tiny | grep -A3 "Last State"
```

```
  Warning  FailedScheduling  25s   default-scheduler  0/1 nodes are available: 1 Insufficient cpu. preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling.
```
```
    Last State:     Terminated
      Reason:       OOMKilled
      Exit Code:    137
```

| 파드 | 상태 | 뜻 |
|---|---|---|
| `big` | `Pending` — `Insufficient cpu` | 예약할 CPU 자리가 있는 노드가 없음 → **어느 노드에도 놓이지 못하고 기다림**. 컨테이너는 시작조차 안 함 |
| `tiny` | `OOMKilled` → 다시 시작 → 다시 `OOMKilled` … | 메모리 최대치(8Mi)를 넘자 강제로 꺼짐(OOM = Out Of Memory). 다시 시작해도 또 넘으니 반복. 시간이 지나면 `CrashLoopBackOff`(다시 시작 간격을 늘리며 기다림)로도 보임 |

- requests는 **자리 잡기**(예약)에, limits는 **실행 중 상한**에 쓰입니다. requests는 실제 사용량과 상관없습니다(확인 문제 2)

정리합니다.

```bash
kubectl delete -f res-test.yaml
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `big`·`tiny`가 아니라 hello 파드가 `Pending` | `res.yaml`의 requests가 너무 큼(예: `cpu: 50`처럼 `m`을 빠뜨림) | `cpu: 50m`인지 확인 |
| `The Pod "big" is invalid: spec: Forbidden: pod updates may not change fields …` | 이미 만든 **Pod**의 resources는 바꿀 수 없음 | `kubectl delete pod big` 후 다시 apply (Deployment는 새 파드를 만들어 바꾸므로 이 오류가 없음) |
| `kubectl top`에 `error: metrics not available yet` | 사용량을 아직 모음 | 30초쯤 뒤 다시 |

</details>

## 4단계. 자동으로 늘리기 — HPA

지금까지 파드 개수는 사람이 파일의 `replicas`를 고쳐 바꿨습니다. **HPA**(HorizontalPodAutoscaler)는 파드의 CPU 사용량을 보고 이 숫자를 대신 바꿔 줍니다. 2단계에서 넣은 `requests`가 기준이 됩니다.

```bash
kubectl autoscale deployment hello --cpu=50% --min=3 --max=6
kubectl get hpa
```

**이 명령은**: Deployment `hello`의 파드 평균 CPU가 requests(50m)의 **50%** 를 넘으면 늘리고, 개수는 **최소 3, 최대 6**으로.

**이렇게 나오면 성공**: `horizontalpodautoscaler.autoscaling/hello autoscaled`, 그리고

```
NAME    REFERENCE          TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
hello   Deployment/hello   cpu: 4%/50%   3         6         3          30s
```

- `TARGETS cpu: 4%/50%` = 지금 4%, 목표 50%. 처음 몇 초는 `cpu: <unknown>/50%`(아직 못 잼) — 30초쯤 뒤 다시

이제 hello를 쉬지 않고 부르는 파드 `load`를 띄워 CPU를 올립니다.

```bash
kubectl run load --image=busybox:1.37 -- sh -c "while true; do wget -qO- hello > /dev/null; done"
kubectl get hpa hello -w
```

`-w`(watch)는 바뀔 때마다 한 줄씩 더 보여 줍니다. 1분쯤 지켜본 뒤 **Ctrl+C**로 멈춥니다.

**이렇게 나오면 성공**: 30~40초 뒤 `TARGETS`가 50%를 넘고 `REPLICAS`가 늘어납니다.

```
hello   Deployment/hello   cpu: 4%/50%     3   6   3   1m
hello   Deployment/hello   cpu: 94%/50%    3   6   3   1m30s
hello   Deployment/hello   cpu: 218%/50%   3   6   6   1m40s
```

```bash
kubectl get pods -l app=hello
kubectl describe hpa hello | tail -3
```

- 파드가 6개(새 3개는 `AGE`가 짧음). describe 맨 아래에 `New size: 6; reason: cpu resource utilization (percentage of request) above target`
- `--max=6`이라 6개에서 멈춥니다. 노드 자원이 허락하는 한에서만 늘어납니다

부하를 멈추고 HPA를 지웁니다.

```bash
kubectl delete pod load
kubectl delete hpa hello
kubectl apply -f res.yaml
kubectl get deployment hello
```

**이렇게 나오면 성공**: `load` 지우기는 30초쯤 걸리고, 마지막에 `hello   3/3` — 파일의 `replicas: 3`으로 돌아왔습니다.

- HPA를 그대로 두면 부하가 끝난 뒤 **5분쯤 기다렸다가** 3개로 줄입니다(개수가 자주 오르내리지 않게). 수업에서는 기다리지 않고 지웁니다
- HPA를 둔 채 `kubectl apply -f res.yaml`을 하면 파일의 `replicas: 3`과 HPA가 서로 숫자를 바꿉니다. HPA를 쓸 때는 보통 파일에서 `replicas`를 빼 둡니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `TARGETS`가 계속 `cpu: <unknown>/50%` | 사용량을 아직 못 잼, 또는 파드에 requests가 없음 | 30초 뒤 다시. 계속이면 2단계 `res.yaml`이 적용됐는지(`kubectl describe hpa hello`의 Events에 `missing request for cpu`) |
| `Flag --cpu-percent has been deprecated` 경고 | 옛 옵션을 씀 | 그대로 동작함. 새 모양은 `--cpu=50%` |
| `Error from server (AlreadyExists): … "hello" already exists` | HPA를 이미 만듦 | 그대로 진행, 또는 `kubectl delete hpa hello` 후 다시 |
| `Error from server (AlreadyExists): pods "load" already exists` | `load`를 이미 띄움 | `kubectl get pods load`로 확인 |
| 2분이 지나도 `REPLICAS 3` | `load`가 `Running`이 아님, 또는 Service `hello`가 없음(실습 6) | `kubectl logs load`, `kubectl get service hello` |

</details>

## 끝났는지 확인
- ☐ 아무것도 안 적은 `hog`가 `300Mi`를 쓰고, `limits: memory: 128Mi`를 넣으니 `OOMKilled`
- ☐ `kubectl top pods`로 hello의 실제 메모리를 봤다
- ☐ `big`이 `Pending`이고 Events에 `Insufficient cpu`
- ☐ `tiny`가 `OOMKilled`이고 `Last State`의 `Reason: OOMKilled`
- ☐ `load`를 띄운 뒤 `kubectl get hpa`의 `REPLICAS`가 3보다 커졌다

## 정리
- `hog`는 1단계 끝에서 지웠습니다(`kubectl get pod hog` → `NotFound`)
- `big`·`tiny`는 3단계 끝에서 지웠습니다. hello는 이제 `res.yaml`의 것입니다(실습 11에서 씀)
- `load` 파드와 HPA는 4단계 끝에서 지웠습니다. `kubectl get hpa` → `No resources found`, `kubectl get deployment hello` → `3/3`

## 확인 문제
1. `res-test.yaml`에서 `big`의 `cpu: "8"`을 `cpu: "1"`로 고쳐 `kubectl apply -f res-test.yaml` 하세요. 무슨 오류가 나오나요? 어떻게 하면 `big`이 `Running`이 되나요? 확인한 뒤 `kubectl delete -f res-test.yaml`.
2. hello 파드는 메모리를 64Mi 예약(requests)했는데 `kubectl top pods`로 본 실제 사용량은 얼마였나요? 예약과 실제 사용량이 다르면 어떤 일이 생길 수 있을까요?
