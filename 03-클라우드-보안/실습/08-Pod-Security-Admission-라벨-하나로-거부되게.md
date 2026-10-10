[← 실습 7](./07-NetworkPolicy-db는-api만.md) · [목차](../클라우드-보안-실습.md) · [실습 9 →](./09-Kyverno-우리-규칙-만들기.md)

# 실습 8. Pod Security Admission — 라벨 하나로 거부되게

**무엇을 하나요**: 실습 4에서 SecurityContext를 파드마다 직접 넣었습니다. 이번에는 **네임스페이스에 라벨 하나**를 붙여, `runAsNonRoot` 같은 설정이 빠진 파드(예: `todo-web:v1`을 그대로 띄운 파드)는 `Forbidden`으로 아예 만들어지지 않게 합니다. 먼저 todo에 붙이면 어떻게 될지 시험하고, 경고만 켜 본 뒤, 빈 네임스페이스에서 라벨 **없이** 같은 파드가 그냥 만들어지는 것을 보고 나서 실제로 거부되게 합니다. (교안 09장)

**필요한 것**: todo, 실습 4·5의 `api-secure.yaml`(적용된 상태).

> **바로 가기** · [1. 라벨을 붙이면 어떻게 될지 시험](#1단계-라벨을-붙이면-어떻게-될지-시험) · [2. 경고만 켜기 — warn](#2단계-경고만-켜기--warn) · [3. 강제하기 — enforce](#3단계-강제하기--enforce) · [4. Deployment는 생기는데 파드가 없다](#4단계-deployment는-생기는데-파드가-없다) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 라벨을 붙이면 어떻게 될지 시험

```bash
kubectl label namespace todo pod-security.kubernetes.io/enforce=restricted --dry-run=server
```

**이 명령은**
- `kubectl label namespace todo 키=값` = todo 네임스페이스에 라벨을 붙임
- `pod-security.kubernetes.io/enforce=restricted` = "이 네임스페이스에서 **가장 엄격한 수준(restricted)에 안 맞는 파드는 거부(enforce)**"라는 뜻의 정해진 라벨
- `--dry-run=server` = 실제로 붙이지 않고, 붙이면 어떻게 될지 서버에 **시험만** 해 봄

**이렇게 나오면 성공**: 경고 두 줄

```
namespace/todo labeled (server dry run)
Warning: existing pods in namespace "todo" violate the new PodSecurity enforce level "restricted:latest"
Warning: db-86878656ff-nkmlv (and 1 other pod): allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile
```

**왜 그런가**
- 지금 todo의 파드 중 **db와 다른 하나(web)** 가 restricted 기준에 맞지 않는다는 뜻입니다. 이유 4가지가 실습 4에서 api에 넣은 설정 묶음과 같습니다
- **api는 목록에 없습니다** — 실습 4에서 묶음을 다 넣었기 때문입니다
- 쓰고 있는 todo에 바로 `enforce`를 붙이면 web·db 파드를 다시 만들 때(재시작·롤아웃) 거부되어 앱이 멈출 수 있습니다. 그래서 **먼저 시험(`--dry-run=server`)** 합니다

## 2단계. 경고만 켜기 — warn

```bash
kubectl label namespace todo pod-security.kubernetes.io/warn=restricted
kubectl -n todo rollout restart deployment/api
kubectl -n todo rollout restart deployment/web
```

**이 명령은**: 이번에는 `enforce`가 아니라 **`warn`**(경고만) 라벨을 실제로 붙임. `rollout restart` = Deployment의 파드를 새로 만들어 다시 시작(새 파드를 만들 때 검사가 일어나므로).

**이렇게 나오면 성공**: api는 조용히, web은 경고와 함께 다시 시작합니다.

```
namespace/todo labeled
deployment.apps/api restarted
Warning: would violate PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "nginx" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "nginx" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "nginx" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "nginx" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
deployment.apps/web restarted
```

- 경고에 **어느 컨테이너가 무엇을 넣어야 하는지**(`container "nginx" must set securityContext.allowPrivilegeEscalation=false` …)까지 나옵니다. 이 줄이 고칠 목록입니다
- warn은 **허용하되 경고만** 하므로 web도 그대로 다시 뜹니다. db는 다시 시작하지 않습니다(데이터는 PVC에 있지만, 시험에 필요 없음)

## 3단계. 강제하기 — enforce

이제 빈 네임스페이스 `psa`를 만들어 `enforce` 라벨을 붙이고 실제로 거부되는지 봅니다.

### 가. 라벨 없이 먼저

```bash
kubectl create namespace psa
kubectl -n psa run web --image=todo-web:v1
kubectl -n psa get pods
kubectl -n psa delete pod web --now
```

**이 명령은**: 라벨이 없는 `psa`에 todo의 화면 이미지(nginx, root로 돎)로 파드 하나를 바로 만들고(`kubectl run`), 확인한 뒤 지움.

**이렇게 나오면 성공**

```
namespace/psa created
pod/web created
NAME   READY   STATUS    RESTARTS   AGE
web    1/1     Running   0          0s
pod "web" deleted from psa namespace
```

- `securityContext`가 하나도 없는 파드가 **아무 경고 없이** 만들어져 돕니다(`STATUS`가 `ContainerCreating`이면 몇 초 뒤 다시 `get pods`). 라벨이 없는 네임스페이스는 검사를 하지 않습니다

라벨이 없으면 훨씬 위험한 파드도 그냥 만들어집니다. **특권 모드**(`privileged: true`)에 **노드의 `/` 전체**를 붙인 파드를 만들어 봅니다.

```bash
nano priv.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: priv
spec:
  containers:
  - name: c
    image: busybox:1.37
    command: ["sleep", "infinity"]
    securityContext:
      privileged: true
    volumeMounts:
    - name: host
      mountPath: /host
  volumes:
  - name: host
    hostPath:
      path: /
```

| 줄 | 뜻 |
|---|---|
| `privileged: true` | 컨테이너에 노드와 같은 권한을 줌(리눅스 특권 전부, 장치 접근) |
| `hostPath: path: /` · `mountPath: /host` | **노드의 `/` 전체**를 컨테이너 안 `/host`에 붙임 |
| `metadata`에 `namespace` 없음 | `kubectl -n psa`로 넣을 네임스페이스를 정함(나에서 같은 파일을 다시 씀) |

```bash
kubectl -n psa apply -f priv.yaml
kubectl -n psa wait --for=condition=Ready pod/priv --timeout=60s
kubectl -n psa exec priv -- ls /host
kubectl -n psa exec priv -- touch /host/tmp/from-pod
N=$(kubectl -n psa get pod priv -o jsonpath='{.spec.nodeName}'); echo $N
docker exec $N ls -l /tmp/from-pod
kubectl -n psa exec priv -- rm /host/tmp/from-pod
kubectl -n psa delete pod priv --now
```

**이 명령은**
- `ls /host` = 파드 안에서 **노드의** `/`를 봄
- `touch /host/tmp/from-pod` = 파드 안에서 노드의 `/tmp`에 빈 파일 하나를 만듦
- `N=$(… -o jsonpath='{.spec.nodeName}')` = 이 파드가 뜬 노드 이름을 변수 `N`에 담음. kind의 노드는 VM의 도커 컨테이너(`lab-control-plane` 등)라서
- `docker exec $N ls -l /tmp/from-pod` = **노드 쪽에서** 그 파일이 보이는지 확인
- 마지막 두 줄 = 만든 파일과 파드를 지움

**이렇게 나오면 성공** (노드 이름은 클러스터에 따라 `lab-control-plane` 등)

```
pod/priv created
pod/priv condition met
LICENSES
bin
boot
dev
etc
home
kind
lib
…
tmp
usr
var
lab-control-plane
-rw-r--r-- 1 root root 0 Oct 10 23:47 /tmp/from-pod
pod "priv" deleted from psa namespace
```

- `ls /host`에 보이는 것은 컨테이너가 아니라 **노드의 파일**입니다(`kind` 폴더가 kind 노드라는 표시). 파드 안에서 만든 `from-pod`가 노드에 root 소유로 생겼습니다
- 즉 이런 파드를 하나 만들 수 있는 사람은 **그 노드의 모든 파일을 root로 읽고 바꿀 수 있습니다**. 노드 위의 다른 파드(todo의 db 데이터 포함)까지 손이 닿습니다. 그런데 라벨 없는 네임스페이스는 아무것도 묻지 않고 만들어 줍니다

### 나. enforce 라벨을 붙이고 다시

```bash
kubectl label namespace psa pod-security.kubernetes.io/enforce=restricted
kubectl -n psa run web --image=todo-web:v1
```

**이 명령은**: `psa`에 `enforce=restricted` 라벨을 붙이고, 가와 **같은 명령**으로 파드를 만들어 봄.

**이렇게 나오면 성공** — 거부되는 것이 맞습니다.

```
namespace/psa labeled
Error from server (Forbidden): pods "web" is forbidden: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "web" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "web" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "web" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "web" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
```

**왜 그런가**: 거부 이유 4가지 = 권한 상승 허용, capability 그대로, root 실행 가능, seccomp 없음. 2단계의 경고와 같은 내용이지만 enforce라서 **파드가 만들어지지 않습니다.**

가에서 노드의 `/`까지 만졌던 특권 파드도 다시 만들어 봅니다.

```bash
kubectl -n psa apply -f priv.yaml
```

**이렇게 나오면 성공** — 이유가 6가지로 늘어납니다.

```
Error from server (Forbidden): error when creating "priv.yaml": pods "priv" is forbidden: violates PodSecurity "restricted:latest": privileged (container "c" must not set securityContext.privileged=true), allowPrivilegeEscalation != false (container "c" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "c" must set securityContext.capabilities.drop=["ALL"]), restricted volume types (volume "host" uses restricted volume type "hostPath"), runAsNonRoot != true (pod or container "c" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "c" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
```

- 맨 앞 `privileged (… must not set securityContext.privileged=true)`와 중간 `restricted volume types (volume "host" uses restricted volume type "hostPath")`가 가에서 노드를 만지게 해 준 두 설정입니다. 라벨 한 줄로 이 파드는 **만들어지지도 않습니다**

| 같은 명령 `kubectl -n psa run web --image=todo-web:v1` | 라벨 없음 (가) | `enforce=restricted` (나) |
|---|---|---|
| 결과 | `pod/web created` → `Running` | `Error from server (Forbidden)` |
| 빠진 설정(`runAsNonRoot` 등) | 아무 메시지 없음 | 빠진 설정 4가지가 메시지에 나옴 |
| 누가 검사하나 | 아무도 — YAML 쓰는 사람이 기억해야 함 | API 서버가 파드를 만들 때 네임스페이스 라벨을 보고 검사 |

## 4단계. Deployment는 생기는데 파드가 없다

파드를 직접 만들지 않고 Deployment로 만들면 어떻게 될까요?

```bash
kubectl -n psa create deployment web --image=todo-web:v1
kubectl -n psa get deployment,pods
kubectl -n psa get events --field-selector reason=FailedCreate | head -3
```

**이 명령은**: `create deployment` = Deployment를 명령으로 바로 만듦. `get deployment,pods` = 둘을 한 번에. 마지막 줄 = "만들기 실패" 사건만.

**이렇게 나오면 성공**

```
Warning: would violate PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "todo-web" …), …
deployment.apps/web created
NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/web   0/1     0            0           3s
LAST SEEN   TYPE      REASON         OBJECT                    MESSAGE
2s          Warning   FailedCreate   replicaset/web-9658bdf67   Error creating: pods "web-9658bdf67-qmpxx" is forbidden: violates PodSecurity "restricted:latest": …
```

**왜 그런가 — 자주 헷갈리는 곳**
- PSA는 **파드**를 검사합니다. Deployment 자체는 `created`(경고만)로 만들어지고, Deployment가 파드를 만들려 할 때 거부됩니다
- 그래서 `kubectl apply`는 성공한 것처럼 보이는데 `READY 0/1`, **파드가 하나도 없습니다.** 이럴 때는 `get events`의 `FailedCreate`를 봅니다(미션 1·2에서 다시 만남)

수준과 모드는 이렇습니다.

| 수준 | 뜻 |
|---|---|
| privileged | 아무 파드나 만들어짐 |
| baseline | `privileged: true`·`hostNetwork: true`·`hostPath` 같은 설정이 있는 파드만 거부 |
| restricted | baseline에 더해 `runAsNonRoot: true`·`capabilities.drop: [ALL]`·`allowPrivilegeEscalation: false`·`seccompProfile`이 없으면 거부 — `todo-web:v1`이 여기서 걸림(3단계) |

| 모드 라벨 | 동작 |
|---|---|
| `pod-security.kubernetes.io/enforce` | 어긴 파드는 `Forbidden`으로 거부(3단계) |
| `pod-security.kubernetes.io/warn` | 파드는 만들어지고 `Warning: would violate …` 줄이 뜸(2단계) |
| `pod-security.kubernetes.io/audit` | 파드는 만들어지고 API 서버 감사 로그에만 남음(터미널에는 아무것도 안 뜸) |

## 끝났는지 확인

- ☐ todo dry-run 경고에 db(와 web 1개)가 나오고 api는 없음
- ☐ warn 라벨 뒤 web 재시작에만 `Warning: would violate …`
- ☐ 라벨 없는 psa에서는 같은 `kubectl run`이 `created`·`Running`
- ☐ 라벨 없는 psa에서 특권 파드 `priv`가 만들어지고, 노드에 `/tmp/from-pod`가 보임
- ☐ enforce 라벨 뒤 psa에서 `kubectl run`이 `forbidden`
- ☐ enforce 라벨 뒤 `priv.yaml`이 `privileged`·`hostPath` 이유로 `Forbidden`
- ☐ psa의 Deployment가 `0/1`, 이벤트에 `FailedCreate`

## 정리

확인 문제를 푼 뒤 지웁니다. todo의 warn 라벨도 뗍니다(남겨 두면 실습 9에서 경고가 계속 섞여 나옴).

```bash
kubectl delete namespace psa
kubectl label namespace todo pod-security.kubernetes.io/warn-
```

- `라벨이름-`(끝에 `-`) = 그 라벨을 뗌

## 확인 문제

1. psa의 수준을 **baseline**으로 바꾸면(`kubectl label namespace psa pod-security.kubernetes.io/enforce=baseline --overwrite`) 같은 `kubectl -n psa run web --image=todo-web:v1`은 어떻게 되나요? root로 도는데 왜 통과하나요? 그때 4단계의 Deployment는 어떻게 되나요?
2. todo에 restricted를 **강제**하려면 web과 db를 어떻게 고쳐야 할까요? 1단계 경고의 네 가지를 보고, 실습 4의 무엇을 가져오면 되는지 말해 보세요. (실제로 고치지는 않습니다)
