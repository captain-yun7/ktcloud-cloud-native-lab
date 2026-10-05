[← 실습 9](./09-Probe-준비됐나-살아-있나.md) · [목차](../Kubernetes-실습.md) · [실습 11 →](./11-Ingress-주소-하나로-나눠-보내기.md)

# 실습 10. requests와 limits — 얼마나 쓰나

**무엇을 하나요**: hello 파드에 CPU·메모리 **requests**(예약)와 **limits**(최대)를 적습니다. 그리고 너무 많이 예약해서 자리를 못 잡는 파드(`Pending`)와, 메모리 최대치를 넘어 강제로 꺼지는 파드(`OOMKilled`)를 일부러 만들어 봅니다. (교안 08장)

**필요한 것**: 실습 9의 `probe.yaml`(hello).

> **바로 가기** · [1. requests·limits 넣기](#1단계-requestslimits-넣기) · [2. 일부러 실패하는 파드 두 개](#2단계-일부러-실패하는-파드-두-개) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. requests·limits 넣기

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

## 2단계. 일부러 실패하는 파드 두 개

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

## 끝났는지 확인
- ☐ `kubectl top pods`로 hello의 실제 메모리를 봤다
- ☐ `big`이 `Pending`이고 Events에 `Insufficient cpu`
- ☐ `tiny`가 `OOMKilled`이고 `Last State`의 `Reason: OOMKilled`

## 정리
- `big`·`tiny`는 2단계 끝에서 지웠습니다. hello는 이제 `res.yaml`의 것입니다(실습 11에서 씀)

## 확인 문제
1. `res-test.yaml`에서 `big`의 `cpu: "8"`을 `cpu: "1"`로 고쳐 `kubectl apply -f res-test.yaml` 하세요. 무슨 오류가 나오나요? 어떻게 하면 `big`이 `Running`이 되나요? 확인한 뒤 `kubectl delete -f res-test.yaml`.
2. hello 파드는 메모리를 64Mi 예약(requests)했는데 `kubectl top pods`로 본 실제 사용량은 얼마였나요? 예약과 실제 사용량이 다르면 어떤 일이 생길 수 있을까요?
