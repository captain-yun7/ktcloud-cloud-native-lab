[← 실습 3](./03-root-아닌-이미지-만들기-todo-api-safe.md) · [목차](../클라우드-보안-실습.md) · [실습 5 →](./05-Secret을-파일로-넣고-쓰지-않는-토큰-끄기.md)

# 실습 4. SecurityContext — api에 하나씩 켜기

**무엇을 하나요**: 먼저 설정이 **없을 때** api 컨테이너가 파일을 쓰고 리눅스 특권(capability)을 가진 채 도는 것을 봅니다. 이미지를 고치는 것 말고도, **파드 YAML**에서 "root면 시작하지 마", "파일을 쓰지 마" 같은 제한을 걸 수 있습니다. 이것이 SecurityContext입니다. todo의 api Deployment에 설정을 하나씩 켜 보고, 실패하면 메시지를 읽고, 실습 3의 `todo-api:safe`로 바꿔 통과시킵니다. (교안 05장)

**필요한 것**: 실습 3에서 클러스터에 넣은 `todo-api:safe`, todo(실습 1).

> **바로 가기** · [1. 설정 없이 먼저 보고, runAsNonRoot 하나만 켜기](#1단계-설정-없이-먼저-보고-runasnonroot-하나만-켜기) · [2. 실패 이유 읽기](#2단계-실패-이유-읽기) · [3. 이미지를 todo-api:safe로](#3단계-이미지를-todo-apisafe로) · [4. 나머지 설정 묶음 켜기](#4단계-나머지-설정-묶음-켜기) · [5. 앱이 그대로 되는지](#5단계-앱이-그대로-되는지) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 설정 없이 먼저 보고, runAsNonRoot 하나만 켜기

### 가. 설정이 없을 때

지금 api는 `todo.yaml` 그대로(SecurityContext 없음, 이미지 `todo-api:v1`)입니다. 컨테이너 안에서 파일을 만들어 보고, 1번 프로세스가 가진 리눅스 특권을 봅니다.

```bash
kubectl -n todo exec deploy/api -- touch /tmp/x && echo 쓰기 됨
kubectl -n todo exec deploy/api -- grep Cap /proc/1/status
```

**이 명령은**: 첫 줄 = api 컨테이너 안에 빈 파일 `/tmp/x`를 만들고, 성공하면 `쓰기 됨`을 찍음. 둘째 줄 = 1번 프로세스(`node app.js`)의 capability(root의 힘을 나눈 조각) 상태를 16진수로 봄.

**이렇게 나오면 성공**

```
쓰기 됨
CapInh:	0000000000000000
CapPrm:	00000000a80425fb
CapEff:	00000000a80425fb
CapBnd:	00000000a80425fb
CapAmb:	0000000000000000
```

| 줄 | 뜻 | 지금 |
|---|---|---|
| `CapEff` | 지금 **실제로 쓸 수 있는** 특권 | `a80425fb` = 기본 특권 14개(파일 소유자 바꾸기 `CHOWN`, 1024 아래 포트 열기 `NET_BIND_SERVICE` 등) |
| `CapBnd` | 이 컨테이너에서 **최대로 가질 수 있는** 특권 | 같음 |

- 설정이 없으면 컨테이너는 **파일을 쓸 수 있고**(침입자가 도구를 내려받아 둘 자리), root로 돌며 **특권 14개를 가진 채** 시작합니다. 앱은 둘 다 쓰지 않습니다. 이 장에서 같은 두 명령을 설정을 켠 뒤 다시 칩니다(4단계)

### 나. runAsNonRoot 하나만 켜기

`todo.yaml`의 api Deployment를 따로 떼어 `securityContext`를 넣을 파일 `api-secure.yaml`을 만듭니다.

```bash
cd ~/sec
nano api-secure.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: todo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      securityContext:
        runAsNonRoot: true
      containers:
      - name: api
        image: todo-api:v1
        envFrom:
        - configMapRef:
            name: todo-config
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: todo-secret
              key: DB_PASSWORD
        ports:
        - containerPort: 3000
```

**이 파일은** — `todo.yaml`의 api Deployment와 같고(Kubernetes 실습 7의 `api.yaml`에 `namespace: todo`만 더함), 두 줄만 새로 들어갔습니다.

| 줄 | 뜻 |
|---|---|
| `securityContext:` (파드 `spec:` 바로 아래) | 이 파드 안 모든 컨테이너에 똑같이 걸 실행 제한(여기서는 `runAsNonRoot`) |
| `runAsNonRoot: true` | **root로 돌게 되어 있으면 시작하지 마.** 사용자를 바꿔 주지는 않고 확인만 함 |

## 2단계. 실패 이유 읽기

```bash
kubectl apply -f api-secure.yaml
kubectl -n todo get pods          # 15초쯤 뒤
kubectl -n todo get events --field-selector reason=Failed
```

**이 명령은**: `apply` = 바뀐 Deployment를 적용(새 api 파드를 만들고, 뜨면 옛 파드를 지움 — Kubernetes 실습 5의 롤링 업데이트). `get events --field-selector reason=Failed` = 이 네임스페이스의 사건 기록 중 실패만.

**이렇게 나오면 성공** — 새 파드가 실패하는 것이 맞습니다.

```
deployment.apps/api configured
NAME                   READY   STATUS                       RESTARTS   AGE
api-58496684fd-sg8qn   0/1     CreateContainerConfigError   0          15s
api-7bcdc699f-gmv69    1/1     Running                      0          5m
db-86878656ff-nkmlv    1/1     Running                      0          5m
web-5bdd6887b7-llw4z   1/1     Running                      0          5m
LAST SEEN   TYPE      REASON   OBJECT                     MESSAGE
3s          Warning   Failed   pod/api-58496684fd-sg8qn   Error: container has runAsNonRoot and image will run as root (pod: …, container: api)
```

**왜 그런가**
- `container has runAsNonRoot and image will run as root` = "root로 돌지 말라고 했는데 **이미지가 root로 돌게 되어 있음**" → 컨테이너를 아예 만들지 않음(`CreateContainerConfigError`). `todo-api:v1`에는 `USER`가 없었습니다(실습 3)
- **옛 api 파드(`1/1 Running`)는 그대로** 있습니다. 새 파드가 준비되지 않으면 쿠버네티스는 옛 파드를 지우지 않으니 앱은 계속 동작합니다

## 3단계. 이미지를 todo-api:safe로

`api-secure.yaml`에서 이미지 한 줄만 바꿉니다.

```bash
sed -i 's/todo-api:v1/todo-api:safe/' api-secure.yaml
grep image: api-secure.yaml
kubectl apply -f api-secure.yaml
kubectl -n todo rollout status deployment/api
kubectl -n todo exec deploy/api -- ps
```

**이 명령은**: `sed -i 's/A/B/' 파일` = 파일 안의 글자 A를 B로 바꿔 저장(nano로 고쳐도 같음). `rollout status` = 새 파드로 다 바뀔 때까지 기다림.

**이렇게 나오면 성공**

```
        image: todo-api:safe
deployment.apps/api configured
Waiting for deployment "api" rollout to finish: 1 old replicas are pending termination...
deployment "api" successfully rolled out
PID   USER     TIME  COMMAND
    1 node      0:00 node app.js
   25 node      0:00 ps
```

- 이제 api는 **node(1000번)** 로 돕니다. `runAsNonRoot`가 이미지의 `USER 1000`을 보고 통과시켰습니다
- `Waiting … pending termination` 줄은 옛 파드가 꺼지기를 기다리는 것입니다. todo api는 끄라는 신호를 받아도 바로 끝나지 않아 **30초쯤** 걸립니다(Kubernetes 과목과 같음, 고장 아님)

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 새 파드가 `ErrImagePull`·`ImagePullBackOff` | 실습 3의 `kind load`를 안 함 | `kind load docker-image todo-api:safe --name lab` 후 잠시 기다림 |
| `ps`가 여전히 `root` | 옛 파드에 들어감(롤아웃 전) | `rollout status`가 끝난 뒤 다시 |

</details>

## 4단계. 나머지 설정 묶음 켜기

`nano api-secure.yaml`로 열어 **두 곳**을 고칩니다. 파드 `securityContext`에 `seccompProfile` 두 줄, 컨테이너 `image:` 줄 아래에 `securityContext` 다섯 줄입니다. 고친 뒤 파일 전체는 이렇습니다.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: todo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: api
        image: todo-api:safe
        securityContext:
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          capabilities:
            drop: [ALL]
        envFrom:
        - configMapRef:
            name: todo-config
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: todo-secret
              key: DB_PASSWORD
        ports:
        - containerPort: 3000
```

| 줄 | 위치 | 뜻 |
|---|---|---|
| `seccompProfile: type: RuntimeDefault` | 파드 | 컨테이너 런타임(containerd)이 정한 기본 목록으로 **일반 앱이 쓰지 않는 시스템 호출(커널에 하는 요청)을 막음** |
| `readOnlyRootFilesystem: true` | 컨테이너 | 컨테이너 안의 파일을 **쓰지 못하게**(읽기만) |
| `allowPrivilegeEscalation: false` | 컨테이너 | 실행 중에 권한이 **더 올라가지 않게** |
| `capabilities: drop: [ALL]` | 컨테이너 | root가 가진 특수 권한 조각(capability)을 **전부 뺌** |

- 파드 `securityContext`는 파드 안 모든 컨테이너에, 컨테이너 `securityContext`는 그 컨테이너에만 걸립니다. 위 표의 자리 그대로 넣습니다(실습 8에서 이 묶음이 그대로 쓰임)

```bash
kubectl apply -f api-secure.yaml
kubectl -n todo rollout status deployment/api
kubectl -n todo exec deploy/api -- touch /tmp/x && echo 쓰기 됨
kubectl -n todo exec deploy/api -- grep Cap /proc/1/status
```

**이 명령은**: 셋째·넷째 줄은 1단계 가와 **같은 명령**입니다. 설정 전후를 비교합니다.

**이렇게 나오면 성공**: 롤아웃이 끝나고, 파일 쓰기가 거부되고(이것이 맞음), 특권이 모두 0입니다.

```
deployment.apps/api configured
…
deployment "api" successfully rolled out
touch: /tmp/x: Read-only file system
command terminated with exit code 1
CapInh:	0000000000000000
CapPrm:	0000000000000000
CapEff:	0000000000000000
CapBnd:	0000000000000000
CapAmb:	0000000000000000
```

| 시험 | 설정 없음 (1단계 가) | 설정 묶음 (4단계) |
|---|---|---|
| `touch /tmp/x` | `쓰기 됨` | `Read-only file system` |
| `CapEff` (지금 쓸 수 있는 특권) | `a80425fb` (14개) | `0` |
| `CapBnd` (최대로 가질 수 있는 특권) | `a80425fb` | `0` — root가 되더라도 특권이 없음 |
| root 이미지 `todo-api:v1` | 그대로 root로 실행 | `CreateContainerConfigError` (1·2단계) |

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `error: error parsing api-secure.yaml: error converting YAML to JSON: yaml: line 10: did not find expected key` | 들여쓰기 틀림(탭, 칸 수) | 위 전체 파일과 칸을 맞춤. 컨테이너 `securityContext`는 `image:`와 같은 칸 |
| `touch`가 성공해 `쓰기 됨`이 나옴 | 롤아웃 전 옛 파드에 들어감, 또는 `readOnlyRootFilesystem` 줄 오타 | `rollout status` 뒤 다시, `grep -n readOnly api-secure.yaml` |

</details>

## 5단계. 앱이 그대로 되는지

```bash
kubectl -n todo exec deploy/web -- wget -qO- -T 3 --post-data '{"title":"secure api"}' --header 'Content-Type: application/json' http://api:3000/api/todos
echo
kubectl -n todo exec deploy/web -- wget -qO- -T 3 http://api:3000/api/todos
echo
```

**이 명령은**: web 파드 안에서 api에 할 일 하나를 추가(`--post-data` = POST로 보낼 내용)하고 목록을 다시 봄. Kubernetes 실습 7의 `curl -X POST …`와 같은 일입니다.

**이렇게 나오면 성공**

```
{"id":1,"title":"secure api"}
[{"id":1,"title":"secure api"}]
```

**왜 그런가**: todo api는 파일을 쓰지 않고(데이터는 db에), root 권한도 특수 권한도 쓰지 않습니다. 그래서 제한을 모두 걸어도 그대로 동작합니다. **앱이 필요로 하지 않는 권한은 처음부터 주지 않는 것**이 이 장의 핵심입니다. todo api라면 파일 쓰기 · root · 특권 14개(`CapEff a80425fb`)를 모두 꺼도 할 일 추가·조회가 그대로 됩니다.

## 끝났는지 확인

- ☐ `todo-api:v1` + `runAsNonRoot`에서 `image will run as root` 메시지를 읽었다
- ☐ `todo-api:safe`로 바꾼 뒤 `ps`의 USER가 `node`
- ☐ 설정 없이 `touch /tmp/x`가 `쓰기 됨`, `CapEff`가 0이 아님을 먼저 봤다
- ☐ 설정 묶음 뒤 같은 명령이 `Read-only file system`, `Cap*` 모두 0
- ☐ web에서 할 일 추가·조회가 됨

## 정리

`api-secure.yaml`은 실습 5·8에서 다시 씁니다. 지우지 마세요. 이제 todo의 api는 `todo.yaml`이 아니라 **`api-secure.yaml`의 것**입니다(`todo.yaml`을 다시 apply하면 `securityContext`가 없고 `todo-api:v1`(root)을 쓰는 api로 돌아가니 주의).

## 확인 문제

1. `api-secure.yaml`을 복사한 `q1.yaml`에서 이미지를 `todo-api:v1`로 되돌리고, 파드 `securityContext`의 `runAsNonRoot: true` 아래에 `runAsUser: 1000`을 한 줄 더해 apply 하세요. 이번에는 파드가 뜨나요? `ps`의 USER는? 확인한 뒤 `kubectl apply -f api-secure.yaml`로 되돌립니다.
2. api 파드 안에서 `/app`에는 파일을 쓸 수 있을까요? `kubectl -n todo exec deploy/api -- touch /app/x`로 확인하세요. 쓰기가 꼭 필요한 앱이면 어떻게 해야 할까요?
