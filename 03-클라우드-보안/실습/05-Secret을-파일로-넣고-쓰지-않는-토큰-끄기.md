[← 실습 4](./04-SecurityContext-api에-하나씩-켜기.md) · [목차](../클라우드-보안-실습.md) · [실습 6 →](./06-RBAC-파드를-읽기만-하는-계정.md)

# 실습 5. Secret을 파일로 넣고 쓰지 않는 토큰 끄기

**무엇을 하나요**: todo의 DB 비밀번호가 든 Secret `todo-secret`이 **암호화가 아니라는 것**, 환경변수로 넣으면 **그대로 보인다는 것**을 확인합니다. 그다음 Secret을 주인만 읽을 수 있는 **파일**로 넣는 법과, 실습 1에서 본 **쓰지 않는 토큰을 끄는 법**을 api에 적용합니다. (교안 06장)

**필요한 것**: todo(실습 1), 실습 4의 `api-secure.yaml`.

> **바로 가기** · [1. Secret은 암호화가 아님](#1단계-secret은-암호화가-아님) · [2. 환경변수로 넣은 비밀번호는 보임](#2단계-환경변수로-넣은-비밀번호는-보임) · [3. 파일로 넣기 — 권한 0400](#3단계-파일로-넣기--권한-0400) · [4. api의 토큰 끄기](#4단계-api의-토큰-끄기) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. Secret은 암호화가 아님

```bash
cd ~/sec
grep -A1 stringData todo.yaml
kubectl -n todo get secret todo-secret -o yaml | head -4
kubectl -n todo get secret todo-secret -o jsonpath='{.data.DB_PASSWORD}'; echo
kubectl -n todo get secret todo-secret -o jsonpath='{.data.DB_PASSWORD}' | base64 -d; echo
```

**이 명령은**
- 첫 줄 = `todo.yaml`에 비밀번호가 어떻게 적혀 있는지(`-A1` = 찾은 줄과 그 아래 한 줄)
- `-o yaml` = 클러스터에 저장된 모양 그대로, `-o jsonpath='{.data.DB_PASSWORD}'` = 그중 값 하나만
- `base64 -d` = base64로 적힌 것을 원래대로 풂. `; echo` = 줄 바꿈만

**이렇게 나오면 성공**

```
stringData:
  DB_PASSWORD: todo-pass
apiVersion: v1
data:
  DB_PASSWORD: dG9kby1wYXNz
kind: Secret
dG9kby1wYXNz
todo-pass
```

**왜 그런가**
- 클러스터에는 `dG9kby1wYXNz`로 저장되어 있지만 이것은 **base64(글자 바꿔 적기)일 뿐**이라 `base64 -d` 한 번이면 `todo-pass`가 나옵니다(Kubernetes 실습 7). Secret을 **읽을 권한이 있는 사람은 누구나** 원문을 봅니다 → 누가 읽을 수 있는지를 막아야 합니다(실습 6 RBAC)
- `todo.yaml`에는 비밀번호가 글자 그대로(`stringData`) 적혀 있습니다. 연습용이라 이렇게 두었지만, 실제로는 이런 파일을 **저장소(git)에 올리지 않습니다.** 명령으로 만들거나(Kubernetes 실습 7의 `kubectl create secret`) 외부 금고를 씁니다(부록 A4)

## 2단계. 환경변수로 넣은 비밀번호는 보임

```bash
kubectl -n todo exec deploy/api -- env | grep PASSWORD
```

**이 명령은**: api 파드 안의 환경변수 목록(`env`)에서 `PASSWORD`가 든 줄만.

**이렇게 나오면 성공**

```
DB_PASSWORD=todo-pass
```

**왜 그런가**: api는 비밀번호를 환경변수(`env:` → `secretKeyRef`)로 받습니다. 환경변수는 `env` 명령, 오류 화면, 진단 기록 등에 **그대로 찍히기 쉽습니다.** 파일로 넣으면 이런 곳에 나오지 않고, 파일 권한으로 읽을 수 있는 사용자도 정할 수 있습니다. (todo api는 환경변수만 읽게 만들어져 있어 앱은 그대로 두고, 다음 단계에서 파일로 받는 모습을 시험 파드로 봅니다.)

## 3단계. 파일로 넣기 — 권한 0400

```bash
nano secret-file.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-file
  namespace: todo
spec:
  automountServiceAccountToken: false
  containers:
  - name: c
    image: busybox:1.37
    command: ["sleep", "infinity"]
    volumeMounts:
    - name: db
      mountPath: /etc/db
      readOnly: true
  volumes:
  - name: db
    secret:
      secretName: todo-secret
      defaultMode: 0400
```

**이 파일은**

| 줄 | 뜻 |
|---|---|
| `automountServiceAccountToken: false` | 서비스 계정 토큰을 **넣지 않음**(실습 1에서 본 폴더가 안 생김) |
| `command: ["sleep", "infinity"]` | 아무것도 안 하고 계속 켜져 있는 시험 파드 |
| `volumes:` → `secret: secretName: todo-secret` | Secret `todo-secret`을 **파일로** 만듦. 키 이름(`DB_PASSWORD`)이 파일 이름 |
| `defaultMode: 0400` | 파일 권한: **주인만 읽기**(쓰기·실행 없음, 다른 사용자는 못 읽음) |
| `volumeMounts:` → `mountPath: /etc/db`, `readOnly: true` | 컨테이너 안 `/etc/db` 폴더에 읽기 전용으로 붙임 |

```bash
kubectl apply -f secret-file.yaml
kubectl -n todo wait --for=condition=Ready pod/secret-file
kubectl -n todo exec secret-file -- ls -lL /etc/db
kubectl -n todo exec secret-file -- cat /etc/db/DB_PASSWORD; echo
kubectl -n todo exec secret-file -- env | grep -c PASSWORD
kubectl -n todo exec secret-file -- ls /var/run/secrets/kubernetes.io
```

**이 명령은**: `ls -lL` = 파일 권한까지 자세히(`-L` = 링크가 가리키는 실제 파일 기준). `grep -c` = 찾은 줄 수만 셈.

**이렇게 나오면 성공**

```
pod/secret-file created
pod/secret-file condition met
total 4
-r--------    1 root     root             9 Oct  5 08:14 DB_PASSWORD
todo-pass
0
ls: /var/run/secrets/kubernetes.io: No such file or directory
command terminated with exit code 1
```

- `-r--------` = 주인(root)만 읽기(0400)
- `env`에서 찾은 줄 `0` = 환경변수에는 비밀번호가 없음
- 마지막 줄이 "없음"인 것이 맞습니다 — 토큰을 껐기 때문

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 파드가 `ContainerCreating`에서 멈춤, Events에 `MountVolume.SetUp failed for volume "db" : secret "todo-secrets" not found` | `secretName` 오타 | 파일을 고치고 `kubectl -n todo delete pod secret-file` 후 다시 apply |
| 마지막 줄에 `serviceaccount`가 보임 | `automountServiceAccountToken` 줄 누락·오타 | 위와 같이 지우고 다시 apply (파드는 만든 뒤 고칠 수 없음) |
| `The Pod "secret-file" is invalid: spec: Forbidden: pod updates may not change fields …` | 이미 만든 파드에 고친 파일을 apply | `kubectl -n todo delete pod secret-file` 후 다시 apply |

</details>

## 4단계. api의 토큰 끄기

실습 1에서 api 파드에 API 서버용 토큰이 들어 있는 것을 봤습니다. todo api는 API 서버를 쓰지 않으니 끕니다. `nano api-secure.yaml`로 열어 파드 `spec:` 바로 아래(`securityContext:` 위)에 한 줄을 넣습니다.

```yaml
    spec:
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
```

| 줄 | 뜻 |
|---|---|
| `automountServiceAccountToken: false` | 이 파드에는 서비스 계정 토큰을 넣지 않음(3단계 시험 파드와 같은 줄, 들여쓰기는 `securityContext:`와 같은 칸) |

```bash
kubectl apply -f api-secure.yaml
kubectl -n todo rollout status deployment/api
kubectl -n todo exec deploy/api -- ls /var/run/secrets/kubernetes.io
kubectl -n todo exec deploy/web -- wget -qO- -T 3 http://api:3000/api/todos; echo
```

**이렇게 나오면 성공**: 토큰 폴더가 없고, 앱은 그대로 동작합니다.

```
deployment.apps/api configured
…
deployment "api" successfully rolled out
ls: /var/run/secrets/kubernetes.io: No such file or directory
command terminated with exit code 1
[{"id":1,"title":"secure api"}]
```

Secret을 넣는 방법을 정리하면 이렇습니다.

| 방법 | 좋은 점 | 주의 |
|---|---|---|
| 환경변수(`env`) | 앱 수정이 쉬움 | `env`·오류 출력에 보임, 값을 바꾸면 파드를 다시 시작해야 반영 |
| 파일(volume) | 권한 지정(0400), 값이 바뀌면 파일도 바뀜(1분 안팎) | 앱이 파일을 읽게 만들어야 함 |
| 외부 금고(Vault, 클라우드 Secret Manager) | 저장 암호화·기록·교체 | 설치·연동 필요 (이 과정은 개념만 — 부록 A4) |

## 끝났는지 확인

- ☐ `base64 -d`로 `todo-pass`가 나옴
- ☐ api의 `env`에 `DB_PASSWORD=todo-pass`가 보임
- ☐ `secret-file`의 파일 권한 `-r--------`, `env`에는 없음
- ☐ api 파드에 토큰 폴더가 없고(`No such file or directory`), 할 일 목록은 그대로

## 정리

확인 문제를 푼 뒤 시험 파드를 지웁니다. `api-secure.yaml`은 실습 8에서 다시 씁니다.

```bash
kubectl -n todo delete pod secret-file
```

여기까지 마쳤으면 [미션 1](../미션/01-취약한-memo-api-고치기.md#미션-1-취약한-memo-api-고치기)을 합니다.

## 확인 문제

1. Secret `todo-secret`에 키를 하나 더해 보세요(비밀번호는 그대로 두고 `EXTRA=hello`만 더함). 파드를 다시 만들지 않아도 `secret-file`의 `/etc/db`에 `EXTRA` 파일이 생기나요? 얼마나 걸리나요? api의 `env`에는 생기나요?
   ```bash
   kubectl -n todo create secret generic todo-secret --from-literal=DB_PASSWORD=todo-pass --from-literal=EXTRA=hello --dry-run=client -o yaml | kubectl apply -f -
   kubectl -n todo exec secret-file -- ls /etc/db      # 몇 번 반복
   ```
2. db 파드에도 토큰이 들어 있나요? (`kubectl -n todo exec deploy/db -- ls /var/run/secrets/kubernetes.io/serviceaccount`) db에 토큰이 필요할까요?
