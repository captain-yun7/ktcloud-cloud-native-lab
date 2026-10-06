[← 실습 6](./06-Service와-port-forward.md) · [목차](../Kubernetes-실습.md) · [실습 8 →](./08-postgres-데이터를-PVC에.md)

# 실습 7. todo를 쿠버네티스에 — ConfigMap과 Secret

**무엇을 하나요**: Docker 실습 13에서 Compose로 띄운 할 일 앱(web · api · db)을 쿠버네티스로 옮깁니다. 세 개가 각각 Deployment + Service이고, 서로 **Service 이름**(`db`, `api`)으로 부릅니다. api의 설정(DB 주소 등)은 **ConfigMap**에, DB 비밀번호는 **Secret**에 넣습니다. Compose의 `environment:`가 하던 일입니다. (교안 06장)

**필요한 것**: 저장소의 `lab/docker/todo`(Docker 실습 13의 앱)와 `lab/k8s/todo`(이 과목에서 받은 YAML 두 개). 터미널 두 개.

> **바로 가기** · [1. 이미지 만들고 클러스터에 넣기](#1단계-이미지-만들고-클러스터에-넣기) · [2. 받은 파일 보기 — Compose와 비교](#2단계-받은-파일-보기--compose와-비교) · [3. 설정 — ConfigMap](#3단계-설정--configmap) · [4. 비밀번호 — Secret](#4단계-비밀번호--secret) · [5. db 띄우기](#5단계-db-띄우기) · [6. api 쓰기](#6단계-api-쓰기) · [7. web 띄우기](#7단계-web-띄우기) · [8. 화면과 API 확인 — port-forward](#8단계-화면과-api-확인--port-forward) · [9. ConfigMap을 파일로 넣어 보기](#9단계-configmap을-파일로-넣어-보기) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 이미지 만들고 클러스터에 넣기

```bash
cd ~/ktcloud-cloud-native-lab/lab/docker/todo
docker build -t todo-api:v1 api
docker build -t todo-web:v1 web
kind load docker-image todo-api:v1 todo-web:v1 --name lab
```

**이 명령은**
- `docker build -t todo-api:v1 api` = `api` 폴더의 Dockerfile로 이미지 `todo-api:v1`을 만듦(Compose가 `build: ./api`로 하던 일). 태그 `v1`을 꼭 붙입니다(실습 3 확인 문제 2 — 태그가 없으면 쿠버네티스가 Docker Hub에서 받으려 함)
- `kind load docker-image …` = 두 이미지를 클러스터 노드에 넣음(실습 3)

**이렇게 나오면 성공**: 빌드 두 번 모두 `naming to docker.io/library/todo-…:v1`, 그리고 `Image: "todo-api:v1" … loading...`, `Image: "todo-web:v1" … loading...`. db는 공식 이미지 `postgres:17-alpine`을 쓰므로 노드가 직접 받습니다.

## 2단계. 받은 파일 보기 — Compose와 비교

```bash
cd ~/ktcloud-cloud-native-lab/lab/k8s/todo
ls
cat web.yaml
```

**이렇게 나오면 성공**: `db.yaml  web.yaml`. 둘 다 Deployment + Service가 `---`(한 파일에 여러 개를 이어 쓸 때의 구분 줄)로 이어진 파일입니다.

Docker 실습 13의 `compose.yaml`이 쿠버네티스에서 어떻게 나뉘는지 봅니다.

| Compose(`compose.yaml`) | 쿠버네티스 | 파일 |
|---|---|---|
| `db:` (postgres, `POSTGRES_PASSWORD: todo-pass`) | Deployment `db` + Service `db`(5432). 비밀번호는 Secret에서 | `db.yaml` (받은 것) |
| `api:` 의 `environment:` (`DB_HOST`·`DB_USER`·`DB_NAME`) | **ConfigMap** `todo-config` | `todo-config.yaml` (직접 씀, 3단계) |
| `api:` 의 `DB_PASSWORD: todo-pass` | **Secret** `todo-secret` | 명령으로 만듦 (4단계) |
| `api:` (`build: ./api`) | Deployment `api` + Service `api`(3000) | `api.yaml` (직접 씀, 6단계) |
| `web:` (`ports: "8088:80"`) | Deployment `web` + Service `web`(80), VM 8088은 port-forward | `web.yaml` (받은 것) |
| 서비스 이름 = 주소 (`db`, `api`) | **Service 이름** = 주소 | — |

- web(nginx)은 `/api/`로 온 요청을 `api:3000`으로 넘깁니다(`lab/docker/todo/web/default.conf`). 그래서 api의 Service 이름은 꼭 `api`, 포트는 3000이어야 합니다

## 3단계. 설정 — ConfigMap

```bash
nano todo-config.yaml
```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: todo-config
data:
  DB_HOST: db
  DB_USER: todo
  DB_NAME: todo
```

| 줄 | 뜻 |
|---|---|
| `kind: ConfigMap` · `name: todo-config` | 설정 묶음의 이름. api가 이 이름으로 가져다 씀 |
| `data:` 아래 `키: 값` | 설정 값. 파드에 **환경변수**로 넣을 것(`DB_HOST=db` …) |
| `DB_HOST: db` | DB 주소 = Service 이름 `db` |

```bash
kubectl apply -f todo-config.yaml
kubectl describe configmap todo-config
```

**이렇게 나오면 성공**: `configmap/todo-config created`, describe의 `Data` 아래 `DB_HOST: db`, `DB_NAME: todo`, `DB_USER: todo`.

## 4단계. 비밀번호 — Secret

비밀번호는 파일에 적지 않고 명령으로 바로 만듭니다(파일로 두면 저장소에 올라갈 수 있음).

```bash
kubectl create secret generic todo-secret --from-literal=DB_PASSWORD=todo-pass
kubectl get secret todo-secret -o yaml | head -4
kubectl get secret todo-secret -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
echo
```

**이 명령은**
- `kubectl create secret generic 이름 --from-literal=키=값` = 키 하나짜리 Secret 만들기
- `-o yaml` = 클러스터에 저장된 모양 그대로 보기, `-o jsonpath='{.data.DB_PASSWORD}'` = 그중 값 하나만
- `base64 -d` = base64(글자를 다른 글자로 바꿔 적는 방식)로 적힌 것을 원래대로 풂. `echo` = 줄 바꿈만 하나 더

**이렇게 나오면 성공**

```
secret/todo-secret created
apiVersion: v1
data:
  DB_PASSWORD: dG9kby1wYXNz
kind: Secret
todo-pass
```

- Secret의 값은 `dG9kby1wYXNz`처럼 **base64로만** 적혀 있고, `base64 -d` 한 번이면 원래 값이 나옵니다. **암호화가 아닙니다.** 그래서 Secret을 누가 읽을 수 있는지를 따로 막아야 합니다(클라우드 보안 과목)
- ConfigMap과 다르게 따로 두는 이유: 읽을 수 있는 사람을 다르게 정할 수 있고, 화면(`describe`)에 값이 바로 보이지 않습니다

## 5단계. db 띄우기

```bash
kubectl apply -f db.yaml
kubectl get pods -l app=db
kubectl logs deploy/db | tail -1
```

**이렇게 나오면 성공**: `deployment.apps/db created`, `service/db created`. 처음에는 `postgres:17-alpine`을 받느라 10초쯤 걸리고, 그 뒤 `1/1 Running`과 로그 마지막 줄

```
… LOG:  database system is ready to accept connections
```

- `db.yaml`의 비밀번호 부분은 아래처럼 Secret을 가리킵니다. 값을 적지 않고 "어느 Secret의 어느 키"인지만 적습니다

```yaml
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: todo-secret
              key: DB_PASSWORD
```

## 6단계. api 쓰기

```bash
nano api.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
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
---
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  selector:
    app: api
  ports:
  - port: 3000
```

**이 파일은** — 위 절반은 실습 4의 Deployment 모양, 아래 절반은 실습 6의 Service 모양입니다. 새로 나온 것은 두 곳입니다.

| 줄 | 뜻 |
|---|---|
| `envFrom:` → `configMapRef: name: todo-config` | ConfigMap `todo-config`의 **모든 키**를 환경변수로 넣음(`DB_HOST`·`DB_USER`·`DB_NAME`) |
| `env:` → `DB_PASSWORD` → `secretKeyRef` | 환경변수 `DB_PASSWORD` **하나**의 값을 Secret `todo-secret`의 키 `DB_PASSWORD`에서 가져옴 |
| Service `port: 3000` | `targetPort`를 안 적으면 `port`와 같은 번호(3000)로 넘김 |

```bash
kubectl apply -f api.yaml
kubectl get pods -l app=api
kubectl logs deploy/api
kubectl exec deploy/api -- env | grep DB_
```

**이렇게 나오면 성공**

```
deployment.apps/api created
service/api created
connected to database at db
todo api listening on port 3000
```
```
DB_HOST=db
DB_NAME=todo
DB_USER=todo
DB_PASSWORD=todo-pass
DB_SERVICE_HOST=10.96.32.15
…
```

- `connected to database at db` = api가 Service 이름 `db`로 DB를 찾았습니다(Docker 실습 13의 로그와 같음)
- `DB_SERVICE_HOST` 같은 줄은 쿠버네티스가 Service마다 자동으로 넣어 주는 환경변수입니다. 우리 앱은 쓰지 않습니다(확인 문제 2)

## 7단계. web 띄우기

```bash
kubectl apply -f web.yaml
kubectl get pods
kubectl get service
```

**이렇게 나오면 성공** — `api`·`db`·`web`이 모두 `1/1 Running`, Service에 `api`(3000)·`db`(5432)·`web`(80)

```
NAME                    READY   STATUS    RESTARTS   AGE
api-7bcdc699f-bmtkk     1/1     Running   0          7s
client                  1/1     Running   0          52s
db-75cbd648f8-hnfvr     1/1     Running   0          46s
hello-d6646dd5c-b7gz7   1/1     Running   0          5m37s
…
web-5f559d65d7-hzzlv    1/1     Running   0          1s
```
```
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
api          ClusterIP   10.96.103.22    <none>        3000/TCP   7s
db           ClusterIP   10.96.32.15     <none>        5432/TCP   46s
hello        ClusterIP   10.96.116.181   <none>        80/TCP     5m46s
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP    9m42s
web          ClusterIP   10.96.79.148    <none>        80/TCP     22s
```

- **순서가 중요합니다**: web(nginx)은 시작할 때 `api`라는 이름을 찾습니다. api Service가 없을 때 web을 먼저 띄우면 web이 `Error`/`CrashLoopBackOff`가 됩니다. 이때는 api를 만든 뒤 `kubectl rollout restart deployment/web`(파드를 새로 만들어 다시 시작). Compose의 `depends_on`이 하던 일을 여기서는 순서로 맞춥니다

## 8단계. 화면과 API 확인 — port-forward

**터미널 1**:

```bash
kubectl port-forward svc/web 8088:80
```

**터미널 2**:

```bash
curl localhost:8088 | head -5
curl localhost:8088/api/todos
curl -X POST -H 'Content-Type: application/json' -d '{"title":"learn k8s"}' localhost:8088/api/todos
curl localhost:8088/api/todos
```

**이렇게 나오면 성공** — Docker 실습 13과 같은 결과

```
<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <title>todo</title>
[]
{"id":1,"title":"learn k8s"}
[{"id":1,"title":"learn k8s"}]
```

브라우저: PORTS 탭에서 `8088` 전달 → `http://localhost:8088` → 할 일 추가·삭제.

다 봤으면 터미널 1에서 **Ctrl+C**. (실습 8에서 다시 켭니다)

<details><summary><b>이렇게 나오면? (이 실습 전체)</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `CreateContainerConfigError` | 파드가 쓸 Secret·ConfigMap이 없음. `describe`의 Events에 `Error: secret "todo-secret" not found` / `configmap "todo-conf" not found` | 4단계 Secret, 3단계 ConfigMap을 만들었는지, 이름 오타가 없는지. 만들고 나면 저절로 시작됨 |
| `error: failed to create secret secrets "todo-secret" already exists` | Secret을 이미 만듦 | 그대로 진행 |
| api·web이 `ErrImagePull` | 1단계 `kind load`를 안 함, 또는 태그 없이 빌드 | 1단계 다시 |
| web이 `Error` / `CrashLoopBackOff`, 로그에 `host not found in upstream "api"` | api Service보다 web을 먼저 만듦 | 6단계(api) 후 `kubectl rollout restart deployment/web` |
| `502 Bad Gateway` | api 파드가 막 시작해 아직 DB에 연결 중(요청을 받을 준비 전) | 몇 초 뒤 다시. 실습 9에서 이 문제를 Probe로 해결 |
| api 로그에 `waiting for database at db (n/15)` | db가 아직 시작 중 | 몇 초 기다리면 `connected`. 15번 넘게 실패하면 api가 꺼졌다 다시 시작됨 |

</details>

## 9단계. ConfigMap을 파일로 넣어 보기

3단계의 ConfigMap은 **환경변수**로 넣었습니다. ConfigMap은 **파일**로도 넣을 수 있습니다. nginx 설정 파일처럼 파일 통째로 넣어야 하는 설정에 씁니다. 작은 파드 `cm-file`에 `todo-config`를 폴더로 붙여 봅니다.

```bash
nano cm-file.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cm-file
spec:
  containers:
  - name: cm-file
    image: busybox:1.37
    command: ["sleep", "infinity"]
    volumeMounts:
    - name: config
      mountPath: /config
  volumes:
  - name: config
    configMap:
      name: todo-config
```

| 줄 | 뜻 |
|---|---|
| `volumes:` 아래 `configMap: name: todo-config` | ConfigMap `todo-config`를 저장 공간처럼 씀 |
| `volumeMounts:` `mountPath: /config` | 그것을 컨테이너의 `/config` 폴더에 붙임(Docker `-v`와 같은 모양) |

```bash
kubectl apply -f cm-file.yaml
kubectl exec cm-file -- ls /config
kubectl exec cm-file -- cat /config/DB_HOST
```

**이렇게 나오면 성공**

```
DB_HOST
DB_NAME
DB_USER
db
```

- **키마다 파일이 하나씩** 생기고, 파일 내용이 값입니다(`/config/DB_HOST` = `db`)
- 환경변수와 다른 점: ConfigMap을 바꾸면 **실행 중인 파드의 파일도 1~2분 뒤 바뀝니다**(다시 시작하지 않아도). 확인 문제 1에서 같이 봅니다. 다만 앱이 바뀐 파일을 다시 읽는지는 앱에 따라 다릅니다

`cm-file`은 확인 문제 1에서 쓰고, 그 뒤 지웁니다(정리).

## 끝났는지 확인
- ☐ `kubectl get pods`에 `api`·`db`·`web`이 `1/1 Running`
- ☐ `kubectl logs deploy/api`에 `connected to database at db`
- ☐ port-forward 중 `curl localhost:8088/api/todos`로 넣은 할 일이 보였다
- ☐ `kubectl exec cm-file -- cat /config/DB_HOST`에 `db`

## 정리
- todo(api·db·web), ConfigMap·Secret은 **실습 8·11에서 계속 씁니다**. 지우지 마세요
- `cm-file`은 확인 문제 1 뒤 지웁니다: `kubectl delete pod cm-file`(30초쯤)

## 확인 문제
1. `todo-config.yaml`의 `DB_HOST: db`를 `DB_HOST: dbx`로 고쳐 `kubectl apply -f todo-config.yaml` 하세요. `kubectl exec deploy/api -- env | grep DB_HOST`의 값은 바로 바뀌나요? `kubectl rollout restart deployment/api` 뒤 api 로그는 어떻게 되나요? 그 사이 9단계의 `cm-file`에서 `kubectl exec cm-file -- cat /config/DB_HOST`를 1분쯤 간격으로 쳐 보세요. 이쪽은 언제 바뀌나요? 확인한 뒤 `db`로 되돌리고 다시 `rollout restart` 합니다.
2. 6단계에서 본 `DB_SERVICE_HOST=10.96.…`의 IP는 무엇의 IP인가요? `kubectl get service`에서 찾아보세요.
