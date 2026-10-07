[← 실습 7](./07-todo를-쿠버네티스에-ConfigMap과-Secret.md) · [목차](../Kubernetes-실습.md) · [실습 9 →](./09-Probe-준비됐나-살아-있나.md)

# 실습 8. postgres 데이터를 PVC에

**무엇을 하나요**: 지금 db 파드를 지우면 할 일 데이터가 모두 사라지는 것을 먼저 봅니다. 그다음 **PVC**(저장 공간 요청서)로 저장 공간을 받아 postgres의 데이터 폴더에 붙이고, 파드를 지워도 데이터가 남는 것을 확인합니다. Docker 실습 13의 볼륨 `db-data`가 하던 일입니다. (교안 07장)

**필요한 것**: 실습 7의 todo(api·db·web). 터미널 두 개.

먼저 **터미널 1**에서 port-forward를 다시 켜 둡니다(실습 7에서 껐다면).

```bash
kubectl port-forward svc/web 8088:80
```

db가 **빈 저장 공간으로 새로 만들어질 때**(1단계·4단계)는 아래 네 줄로 api를 다시 시작합니다. 이유는 2단계에서 봅니다.

```bash
kubectl rollout status deployment/db          # 새 db 파드가 준비될 때까지 기다림
kubectl rollout restart deployment/api        # api를 새로 시작 (새 DB에 다시 연결하고 표를 만듦)
kubectl rollout status deployment/api         # api가 바뀔 때까지 기다림
kubectl logs deploy/api                       # 마지막 줄이 todo api listening on port 3000 이면 준비 끝
```

> **바로 가기** · [1. db 파드를 지우면 — 데이터가 사라짐](#1단계-db-파드를-지우면--데이터가-사라짐) · [2. api도 다시 시작해야 하는 이유](#2단계-api도-다시-시작해야-하는-이유) · [3. 저장 공간을 주는 곳 — StorageClass](#3단계-저장-공간을-주는-곳--storageclass) · [4. PVC를 만들고 db에 붙이기](#4단계-pvc를-만들고-db에-붙이기) · [5. 다시 db 파드를 지우면 — 데이터가 남음](#5단계-다시-db-파드를-지우면--데이터가-남음) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. db 파드를 지우면 — 데이터가 사라짐

**터미널 2**:

```bash
cd ~/ktcloud-cloud-native-lab/lab/k8s/todo
curl -X POST -H 'Content-Type: application/json' -d '{"title":"keep me"}' localhost:8088/api/todos
curl localhost:8088/api/todos
kubectl delete pod -l app=db
kubectl rollout status deployment/db
kubectl exec deploy/db -- psql -U todo -c 'select * from todos'
```

**이 명령은**
- `kubectl delete pod -l app=db` = db 파드를 지움 → Deployment가 새 db 파드를 만듦(실습 4)
- `kubectl exec deploy/db -- psql -U todo -c '…'` = db 파드 안에서 postgres 명령 도구 `psql`로 할 일 표(`todos`)를 직접 조회

**이렇게 나오면 성공** — 넣은 할 일이 보였다가, 새 db에서는 **`keep me`가 없음**. 마지막 줄은 둘 중 하나입니다.

```
{"id":…,"title":"keep me"}
[…,{"id":…,"title":"keep me"}]
pod "db-75cbd648f8-f9s8k" deleted from default namespace
deployment "db" successfully rolled out
```
```
ERROR:  relation "todos" does not exist
LINE 1: select * from todos
                      ^
command terminated with exit code 1
```
또는
```
 id | title
----+-------
(0 rows)
```

- 데이터는 db **컨테이너 안**의 폴더(`/var/lib/postgresql/data`)에 있었습니다. 파드가 새로 만들어지면 컨테이너도 새것이라 그 안의 파일은 사라집니다(Docker 실습 10과 같음)
- `relation "todos" does not exist` = `todos`라는 표가 없다. 할 일뿐 아니라 api가 만든 **표까지** 사라진 것입니다
- `(0 rows)` = 표는 있는데 비어 있음. api가 다시 시작하면서(예: 2단계의 `rollout restart`를 먼저 한 경우) 새 DB에 **빈 표**를 다시 만든 경우입니다. api는 시작할 때만 표를 만들고, DB가 바뀌어도 스스로 꺼지지는 않습니다(2026-10-04 앱 수정 뒤 RESTARTS 0). 어느 쪽이든 넣은 할 일은 사라졌습니다

## 2단계. api도 다시 시작해야 하는 이유

```bash
kubectl get pods -l app=api
kubectl rollout restart deployment/api
kubectl rollout status deployment/api
kubectl logs deploy/api
curl localhost:8088/api/todos
```

**이렇게 나오면 성공**: 마지막 `curl`에 `[]`(빈 목록). `502 Bad Gateway`면 api가 아직 준비 중이니 몇 초 뒤 다시.

- todo api는 **시작할 때 한 번** DB에 연결하고 표를 만듭니다(`lab/docker/todo/api/app.js`). DB가 **빈** 새것으로 바뀌면 표가 없으니, api를 다시 시작해야 새 DB에 표를 만듭니다. 그래서 db가 비어서 새로 생길 때 위의 네 줄을 씁니다
- `kubectl logs deploy/api`에 `database connection lost: …` 줄이 보일 수 있습니다. db 파드가 바뀌며 api가 붙잡고 있던 연결이 끊겼다는 기록이고, api는 꺼지지 않고 다음 요청 때 새로 연결합니다(정상)
- `kubectl rollout restart` = 파일을 바꾸지 않고 파드만 새로 만들어 다시 시작(롤링 업데이트와 같은 방식)

## 3단계. 저장 공간을 주는 곳 — StorageClass

```bash
kubectl get storageclass
```

```
NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
standard (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  10m
```

- kind 클러스터에는 `standard`라는 저장 공간 제공자가 기본으로 있습니다. PVC로 "1Gi 주세요"라고 하면 이것이 노드 안에 폴더를 만들어 줍니다(실습 2 확인 문제의 `local-path-provisioner`)
- 클라우드에서는 같은 자리에 클라우드 디스크(예: AWS EBS)를 만들어 주는 StorageClass가 있습니다

## 4단계. PVC를 만들고 db에 붙이기

`db.yaml`과 같은 Deployment `db`에 저장 공간을 붙인 새 파일을 씁니다(Service는 `db.yaml`의 것을 그대로 씀).

```bash
nano db-pvc.yaml
```

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: db-data
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: postgres
        image: postgres:17-alpine
        env:
        - name: POSTGRES_USER
          value: todo
        - name: POSTGRES_DB
          value: todo
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: todo-secret
              key: DB_PASSWORD
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: db-data
```

**이 파일은** — 위는 PVC, 아래는 `db.yaml`의 Deployment에 맨 아래 7줄(`volumeMounts`, `volumes`)을 더한 것입니다.

| 줄 | 뜻 | Docker에서 |
|---|---|---|
| `kind: PersistentVolumeClaim` · `name: db-data` | 저장 공간 **요청서**. 이름 `db-data` | `volumes: db-data:` |
| `accessModes: ReadWriteOnce` | 노드 한 대에서 읽고 쓰기 | — |
| `storage: 1Gi` | 1Gi(약 1GB) 주세요 | — |
| `volumes:` → `name: data`, `claimName: db-data` | 이 파드가 쓸 저장 공간 `data` = PVC `db-data` | — |
| `volumeMounts:` → `mountPath: /var/lib/postgresql/data` | 그 저장 공간을 컨테이너의 이 폴더에 연결 | `-v db-data:/var/lib/postgresql/data` |

```bash
kubectl apply -f db-pvc.yaml
kubectl get pvc
kubectl rollout status deployment/db
kubectl get pvc
kubectl get pv
```

**이렇게 나오면 성공**

```
persistentvolumeclaim/db-data created
deployment.apps/db configured
```
```
NAME      STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
db-data   Pending                                      standard       <unset>                 0s
```
```
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
db-data   Bound    pvc-5a261445-59f2-402e-b8aa-c61d7df055a0   1Gi        RWO            standard       <unset>                 4s
```
```
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM             STORAGECLASS   …
pvc-5a261445-59f2-402e-b8aa-c61d7df055a0   1Gi        RWO            Delete           Bound    default/db-data   standard       …
```

- 처음에는 `Pending`, db 파드가 이 PVC를 쓰기 시작하면 `Bound`(연결됨)가 됩니다(StorageClass의 `WaitForFirstConsumer` = 쓰는 파드가 생길 때 만듦)
- `kubectl get pv` = 실제로 만들어진 저장 공간(PV). PVC가 요청서라면 PV는 받은 물건입니다
- `deployment.apps/db configured` = 같은 Deployment `db`를 바꿨으므로 db 파드가 새로 만들어졌습니다. 새 저장 공간은 비어 있으니 api를 다시 시작합니다

```bash
kubectl rollout restart deployment/api
kubectl rollout status deployment/api
kubectl logs deploy/api
curl -X POST -H 'Content-Type: application/json' -d '{"title":"keep me"}' localhost:8088/api/todos
curl localhost:8088/api/todos
```

**이렇게 나오면 성공**: `{"id":1,"title":"keep me"}`, `[{"id":1,"title":"keep me"}]`. (`502`면 몇 초 뒤 다시)

## 5단계. 다시 db 파드를 지우면 — 데이터가 남음

```bash
kubectl delete pod -l app=db
kubectl rollout status deployment/db
kubectl exec deploy/db -- psql -U todo -c 'select * from todos'
curl localhost:8088/api/todos
```

- 이번에는 api를 **다시 시작하지 않습니다**. 표와 데이터가 저장 공간에 그대로 있으니 api는 새 db 파드에 다시 연결만 하면 됩니다
- `curl`이 `502`나 오류면 db가 막 바뀐 직후라서입니다. 몇 초 뒤 다시

**이렇게 나오면 성공** — 새 db 파드에서도 할 일이 그대로

```
 id |  title
----+---------
  1 | keep me
(1 row)
```
```
[{"id":1,"title":"keep me"}]
```

- 파드는 새것이지만 `/var/lib/postgresql/data`는 PVC의 저장 공간이라 그대로 붙었습니다. 파드의 수명과 데이터의 수명이 나뉜 것입니다

다 봤으면 터미널 1의 port-forward를 **Ctrl+C**.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| PVC가 계속 `Pending` | 이 PVC를 쓰는 파드가 아직 없음(정상), 또는 Deployment 쪽 `claimName` 오타 | `kubectl get pods -l app=db`가 `Running`인지, `claimName: db-data`인지 |
| db 파드가 `Pending`, Events에 `persistentvolumeclaim "…" not found` | `claimName`과 PVC 이름이 다름 | 둘을 `db-data`로 맞춤 |
| `curl`이 `500`·`Internal Server Error` (db를 빈 저장 공간으로 바꾼 뒤) | api를 다시 시작하지 않아 새 DB에 표가 없음 | `kubectl rollout restart deployment/api` |
| `curl`이 `502 Bad Gateway` | api가 막 다시 시작하는 중 | 몇 초 뒤 다시. `kubectl logs deploy/api`의 마지막 줄이 `todo api listening on port 3000`인지 |

</details>

## 끝났는지 확인
- ☐ PVC 없이 db 파드를 지웠을 때 `keep me`가 사라졌다(`relation "todos" does not exist` 또는 `(0 rows)`)
- ☐ `kubectl get pvc`에 `db-data   Bound   …   1Gi`
- ☐ PVC를 붙인 뒤에는 db 파드를 지워도 `keep me`가 남아 있었다

## 정리
- todo는 **실습 11(Ingress)에서 다시 씁니다**. 지우지 마세요. 이제 db는 `db-pvc.yaml`의 것입니다(`db.yaml`을 다시 apply하면 PVC가 빠진 db로 돌아가니 주의)

## 확인 문제
1. `kubectl delete deployment db`로 Deployment를 통째로 지운 뒤 `kubectl get pvc`를 보세요. PVC는 어떻게 됐나요? `kubectl apply -f db-pvc.yaml`로 다시 만들고 `rollout status`가 끝난 뒤 `psql`로 `todos`를 조회하면 무엇이 나오나요?
2. PV의 실제 파일은 어디에 있을까요? `docker exec lab-control-plane ls /var/local-path-provisioner`를 실행해 보고, 폴더 이름을 `kubectl get pv`의 이름과 비교하세요.
