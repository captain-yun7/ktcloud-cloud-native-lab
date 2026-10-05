[← 실습 1](./01-도구-설치와-첫-클러스터.md) · [목차](../Kubernetes-실습.md) · [실습 3 →](./03-hello-앱을-Pod로.md)

# 실습 2. kubectl로 둘러보기

**무엇을 하나요**: `kubectl get`·`describe`·`top`·`explain`으로 클러스터를 둘러봅니다. 네임스페이스(클러스터 안의 폴더)를 `-n`으로 골라 보는 법도 익힙니다. 이 과목의 모든 실습에서 쓰는 명령입니다. (교안 02장)

**필요한 것**: 실습 1의 클러스터(`kubectl get nodes`가 `Ready`).

> **바로 가기** · [1. 목록 보기 — get](#1단계-목록-보기--get) · [2. 다른 네임스페이스 보기 — -n, -A](#2단계-다른-네임스페이스-보기---n--a) · [3. 자세히 보기 — describe](#3단계-자세히-보기--describe) · [4. 사용량과 설명서 — top, explain](#4단계-사용량과-설명서--top-explain) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 목록 보기 — get

```bash
kubectl get nodes -o wide
kubectl get pods
kubectl get namespaces
```

**이 명령은**
- `kubectl get <종류>` = 그 종류의 목록. `-o wide` = 열을 더 보여 줌(IP 등)
- `kubectl get pods` = 파드 목록. 아직 아무것도 안 만들었으니 비어 있음
- `kubectl get namespaces` = 네임스페이스(폴더) 목록

**이렇게 나오면 성공**

```
No resources found in default namespace.
```
```
NAME                 STATUS   AGE
default              Active   45s
kube-node-lease      Active   45s
kube-public          Active   45s
kube-system          Active   45s
local-path-storage   Active   41s
```

- `in default namespace` — 네임스페이스를 고르지 않으면 `default`에서 찾습니다. 우리가 만드는 것도 따로 정하지 않으면 `default`에 들어갑니다

## 2단계. 다른 네임스페이스 보기 — -n, -A

```bash
kubectl get pods -n kube-system
kubectl get pods -A
```

**이 명령은**
- `-n kube-system` = `kube-system` 네임스페이스에서 보기(n = namespace)
- `-A` = 모든 네임스페이스(All). 맨 앞에 `NAMESPACE` 열이 붙음

**이렇게 나오면 성공** — `kube-system`에 클러스터 구성 요소가 모두 `Running`

```
NAME                                        READY   STATUS    RESTARTS   AGE
coredns-559f6c778d-sfb75                    1/1     Running   0          34s
coredns-559f6c778d-vf597                    1/1     Running   0          34s
etcd-lab-control-plane                      1/1     Running   0          43s
kindnet-mktvg                               1/1     Running   0          35s
kube-apiserver-lab-control-plane            1/1     Running   0          43s
kube-controller-manager-lab-control-plane   1/1     Running   0          43s
kube-proxy-8f2rl                            1/1     Running   0          35s
kube-scheduler-lab-control-plane            1/1     Running   0          43s
metrics-server-84c99cb944-vj9j8             1/1     Running   0          34s
```

| 열 | 뜻 |
|---|---|
| `READY` | 준비된 컨테이너 수 / 전체. `1/1`이면 준비 끝 |
| `STATUS` | 상태. `Running` = 실행 중 |
| `RESTARTS` | 컨테이너가 다시 시작된 횟수 |
| `AGE` | 만든 지 얼마나 됐나 |

| 파드 | 하는 일 (교안 01장 구조 그림) |
|---|---|
| `kube-apiserver-…` | 모든 요청의 입구. `kubectl`도 여기에 요청 |
| `etcd-…` | 클러스터 상태를 저장 |
| `kube-scheduler-…` | 새 파드를 어느 노드에 둘지 정함 |
| `kube-controller-manager-…` | "원하는 상태"와 지금 상태를 계속 맞춤 |
| `coredns-…` | 클러스터 안의 이름 찾기(05장 Service) |
| `kindnet-…` · `kube-proxy-…` | 파드끼리·Service로 통신하게 하는 네트워크 |
| `metrics-server-…` | CPU·메모리 사용량(`kubectl top`) |

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `No resources found in kube-sytem namespace.` | 네임스페이스 이름 오타(`kube-sytem`). **오류 없이** "없음"으로 나옴 | `kubectl get namespaces`로 이름을 확인하고 다시 |
| `0/1`이 섞여 있음 | 클러스터를 막 만들어 준비 중 | 20~30초 뒤 다시 |

</details>

## 3단계. 자세히 보기 — describe

```bash
kubectl describe node lab-control-plane | head -20
```

**이 명령은**: `kubectl describe <종류> <이름>` = 하나를 자세히. `| head -20` = 앞 20줄만(실습 2 파이프). 파드에 쓰면 맨 아래 **Events**(일어난 일 기록)가 나와, 문제를 찾을 때 가장 많이 씁니다(실습 3부터).

**이렇게 나오면 성공**: `Name: lab-control-plane`, `Roles: control-plane`, `Labels:` 아래 `kubernetes.io/hostname=lab-control-plane` 등.

## 4단계. 사용량과 설명서 — top, explain

```bash
kubectl top nodes
kubectl explain deployment.spec.replicas
```

**이 명령은**
- `kubectl top nodes` = 노드의 CPU·메모리 사용량(`docker stats`와 비슷)
- `kubectl explain <종류>.<필드>` = YAML에 쓰는 칸의 설명서. 인터넷 없이 VM 안에서 봄

**이렇게 나오면 성공**

```
NAME                CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)
lab-control-plane   240m         6%       644Mi           4%
```
```
FIELD: replicas <integer>

DESCRIPTION:
    Number of desired pods. This is a pointer to distinguish between explicit
    zero and not specified. Defaults to 1.
```

- `240m` = CPU 0.24개(m = 1000분의 1). `644Mi` = 메모리 약 644MB
- `kubectl top`이 `Metrics API not available`이면 metrics-server가 준비 중입니다. 30초쯤 뒤 다시

## 끝났는지 확인
- ☐ `kubectl get pods -n kube-system`의 파드가 모두 `Running`
- ☐ `kubectl top nodes`가 숫자를 보여 줌
- ☐ `kubectl get pods`(네임스페이스 없이)는 `No resources found in default namespace.`

## 정리
- 만든 것이 없으니 정리할 것도 없습니다

## 확인 문제
1. `coredns` 파드는 몇 개이고, 각각 어느 노드에서 돌고 있나요? (`-n kube-system`과 `-o wide`를 함께 쓰세요)
2. `kubectl get pods -n local-path-storage`로 보이는 파드는 몇 개인가요? `-A`로 본 결과와 비교해 보세요.
