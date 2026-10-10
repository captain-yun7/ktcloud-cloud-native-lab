[← 시작하기 전에](./00-시작하기-전에.md) · [목차](../클라우드-보안-실습.md) · [실습 2 →](./02-Trivy로-todo-api-이미지-스캔.md)

# 실습 1. 빈틈 세 개 직접 보기 — root · 열린 네트워크 · 토큰

**무엇을 하나요**: Kubernetes 과목에서 만든 todo를 **`securityContext`·NetworkPolicy 같은 설정 없이** 네임스페이스 `todo`에 띄우고, 쿠버네티스 기본값 그대로일 때 생기는 빈틈 세 개를 직접 확인합니다. ① 앱이 root로 돈다 ② 다른 네임스페이스에서도 db에 닿는다 ③ 파드 안에 API 서버용 토큰이 들어 있다. 이 실습은 **찾기만** 합니다. 막는 방법은 실습 3부터 하나씩 배웁니다. (교안 02장)

**필요한 것**: [시작하기 전에](./00-시작하기-전에.md#시작하기-전에) 3·4(도구, todo 이미지).

> **바로 가기** · [1. todo를 todo 네임스페이스에 띄우기](#1단계-todo를-todo-네임스페이스에-띄우기) · [2. 빈틈 1 — 누구 권한으로 도나](#2단계-빈틈-1--누구-권한으로-도나) · [3. 빈틈 2 — 다른 네임스페이스에서 db에 닿나](#3단계-빈틈-2--다른-네임스페이스에서-db에-닿나) · [4. 빈틈 3 — 파드 안의 토큰](#4단계-빈틈-3--파드-안의-토큰) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. todo를 todo 네임스페이스에 띄우기

```bash
mkdir -p ~/sec && cd ~/sec
cp ~/ktcloud-cloud-native-lab/03-클라우드-보안/todo.yaml .
grep -n "kind:" todo.yaml
kubectl apply -f todo.yaml
```

**이 명령은**
- `mkdir -p ~/sec && cd ~/sec` = 이 과목 작업 폴더를 만들고 들어감
- `cp … .` = 받은 `todo.yaml`을 지금 폴더(`.`)로 복사
- `grep -n "kind:" todo.yaml` = 파일 안에 무엇이 들었는지 `kind:` 줄만 번호와 함께 봄
- `kubectl apply -f todo.yaml` = 파일 안의 것을 한 번에 만듦

**이렇게 나오면 성공**

```
5:kind: Namespace
11:kind: Secret
19:kind: ConfigMap
30:kind: PersistentVolumeClaim
42:kind: Deployment
80:kind: Service
91:kind: Deployment
121:kind: Service
133:kind: Deployment
154:kind: Service
namespace/todo created
secret/todo-secret created
configmap/todo-config created
persistentvolumeclaim/db-data created
deployment.apps/db created
service/db created
deployment.apps/api created
service/api created
deployment.apps/web created
service/web created
```

`todo.yaml`은 Kubernetes 실습 7·8에서 만든 것(ConfigMap · Secret · PVC · web/api/db의 Deployment와 Service)을 **네임스페이스 `todo` 하나에 모은 것**입니다. 새로 쓴 것은 맨 위 `kind: Namespace`와, 모든 것에 붙은 `namespace: todo` 한 줄뿐입니다. 보안 설정은 일부러 하나도 넣지 않았습니다.

20초쯤 뒤 확인합니다.

```bash
kubectl -n todo get pods
kubectl -n todo logs deploy/api
kubectl -n todo exec deploy/web -- wget -qO- -T 3 http://api:3000/api/todos
echo
```

**이 명령은**: `-n todo` = todo 네임스페이스에서. 마지막 `exec` 줄 = web 파드 안에서 `wget`으로 api에 할 일 목록을 물음(브라우저 없이 앱이 도는지 보는 방법, 이 과목 내내 씀). `echo` = 줄 바꿈만.

**이렇게 나오면 성공**: 세 파드가 `1/1 Running`, api 로그 끝에 `connected to database at db`, 마지막 줄 `[]`(아직 할 일이 없음)

```
NAME                   READY   STATUS    RESTARTS   AGE
api-7bcdc699f-gmv69    1/1     Running   0          20s
db-86878656ff-nkmlv    1/1     Running   0          20s
web-5bdd6887b7-llw4z   1/1     Running   0          20s
waiting for database at db (1/15): connect ECONNREFUSED 10.96.49.153:5432
…
connected to database at db
todo api listening on port 3000
[]
```

- `waiting for database …` 줄은 db가 먼저 뜨는 동안 api가 기다린 기록입니다. 마지막에 `connected`가 나오면 정상입니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `cp: cannot stat '…/03-클라우드-보안/todo.yaml'` | 저장소를 최신으로 안 받음 | `cd ~/ktcloud-cloud-native-lab && git pull` 후 다시 |
| api·web이 `ErrImagePull` / `ImagePullBackOff` | 클러스터 안에 todo 이미지가 없음 | [시작하기 전에 4](./00-시작하기-전에.md#4-todo-이미지-준비) 후 `kubectl -n todo delete pod --all` |
| `wget: server returned error: HTTP/1.1 500` | db가 다시 만들어져 테이블이 없음 | `kubectl -n todo rollout restart deployment/api` 후 20초 뒤 다시 |
| `wget: can't connect to remote host … Connection refused` | api가 아직 db를 기다리는 중 | 20초 뒤 다시 |

</details>

## 2단계. 빈틈 1 — 누구 권한으로 도나

```bash
kubectl -n todo exec deploy/api -- ps
kubectl -n todo exec deploy/api -- id
kubectl -n todo exec deploy/web -- ps
```

**이 명령은**: `ps` = 컨테이너 안에서 돌고 있는 프로그램 목록(`USER` 칸 = 누구 권한으로 도나). `id` = 지금 사용자의 번호.

**이렇게 나오면 성공**

```
PID   USER     TIME  COMMAND
    1 root      0:00 node app.js
   31 root      0:00 ps
uid=0(root) gid=0(root) groups=0(root),1(bin),2(daemon),3(sys),4(adm),6(disk),10(wheel),11(floppy),20(dialout),26(tape),27(video)
PID   USER     TIME  COMMAND
    1 root      0:00 nginx: master process nginx -g daemon off;
   35 nginx     0:00 nginx: worker process
…
```

**왜 그런가**: todo의 api 이미지(`FROM node:22-alpine`)는 사용자를 정하지 않았으니 **root(uid 0)** 로 돕니다. Dockerfile에 `USER`가 없으면 root가 기본값입니다. web의 nginx도 맨 위 프로그램(master)은 root입니다. 컨테이너는 노드와 같은 커널을 쓰므로, 컨테이너 밖 노드로 빠져나가는 일이 생기면 노드에서도 root가 됩니다(uid 1000이었다면 노드에서도 uid 1000 권한까지만). 그래서 **처음부터 root가 아니게** 만드는 것이 기본입니다(실습 3·4).

## 3단계. 빈틈 2 — 다른 네임스페이스에서 db에 닿나

다른 네임스페이스 `other`를 만들고, 그 안에 시험용 파드 `t`를 하나 계속 켜 둡니다. 실습 7과 미션 2에서도 이 파드로 시험합니다.

```bash
kubectl create namespace other
kubectl -n other run t --image=busybox:1.37 -- sleep infinity
kubectl -n other wait --for=condition=Ready pod/t
kubectl -n other exec t -- nc -z -w 3 db.todo 5432 && echo 열림 || echo 막힘
```

**이 명령은**
- `kubectl -n other run t --image=busybox:1.37 -- sleep infinity` = other에 파드 `t`를 만듦. busybox = 기본 도구만 든 작은 이미지, `sleep infinity` = 아무것도 안 하고 계속 켜져 있음(Kubernetes 실습 6의 `client`와 같음)
- `wait --for=condition=Ready` = 파드가 준비될 때까지 기다림
- `nc -z -w 3 호스트 포트` = 그 포트에 연결만 해 보고(데이터는 안 보냄) 3초 안에 되면 성공
- `db.todo` = **todo 네임스페이스의 db** Service(`서비스이름.네임스페이스`). 5432 = postgres 포트
- `&& echo 열림 || echo 막힘` = 앞 명령이 성공하면 `열림`, 실패하면 `막힘`

**이렇게 나오면 성공**

```
namespace/other created
pod/t created
pod/t condition met
열림
```

**왜 열려 있나**: 쿠버네티스는 **NetworkPolicy가 없으면 모든 파드가 모든 파드에 닿습니다.** 네임스페이스는 이름을 나누는 칸이지 네트워크를 막는 벽이 아닙니다. 그래서 todo와 아무 상관 없는 `other`의 파드도 DB 포트에 연결됩니다. 막는 방법은 실습 7(NetworkPolicy)입니다.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `Error from server (AlreadyExists): namespaces "other" already exists` | 이미 만듦 | 그대로 진행 |
| `Error from server (AlreadyExists): pods "t" already exists` | 이미 만듦 | 그대로 진행 |
| `막힘`과 함께 `command terminated with exit code 1` | 주소·포트 오타(`db.todo`, `5432`), 또는 db가 아직 안 뜸 | `kubectl -n todo get pods`로 db가 `Running`인지 보고 다시 |

</details>

## 4단계. 빈틈 3 — 파드 안의 토큰

```bash
kubectl -n todo exec deploy/api -- ls /var/run/secrets/kubernetes.io/serviceaccount
kubectl -n todo get pod -l app=api -o jsonpath='{.items[0].spec.serviceAccountName}'; echo
kubectl auth can-i list secrets -n todo --as=system:serviceaccount:todo:default
```

**이 명령은**
- 첫 줄 = api 파드 안의 서비스 계정 폴더를 봄. **서비스 계정** = 사람이 아니라 파드(프로그램)가 쓰는 계정. 따로 정하지 않으면 네임스페이스의 `default` 계정 토큰이 자동으로 들어갑니다
- 둘째 줄 = 이 파드가 어느 서비스 계정을 쓰는지(`-o jsonpath` = 출력에서 원하는 부분만, `-l app=api` = 라벨이 `app=api`인 파드)
- `kubectl auth can-i 동사 리소스 -n 네임스페이스 --as=계정` = 그 계정이 그 일을 할 수 있는지 클러스터에 물음(yes/no). 실습 6에서 다시 씁니다

**이렇게 나오면 성공**

```
ca.crt
namespace
token
default
no
```

**왜 확인하나**: `token`은 이 파드가 쿠버네티스 API 서버에 "나는 todo의 default 계정"이라고 증명하는 열쇠입니다. todo api는 API 서버를 쓰지 않으니 **필요 없는 열쇠**가 들어 있는 셈입니다. 지금은 default 계정에 권한이 거의 없어(`no`) 당장 위험하지 않지만, 누군가 이 계정에 권한을 주면 모든 파드의 토큰이 그 권한을 갖게 됩니다. 그래서 쓰지 않는 토큰은 끄고(실습 5), 권한은 최소로 줍니다(실습 6).

## 끝났는지 확인

- ☐ todo의 api·db·web이 `1/1 Running`, `wget …/api/todos`가 `[]`
- ☐ api의 `ps`에서 `node app.js`의 USER가 `root`
- ☐ other의 `t`에서 `db.todo 5432`가 `열림`
- ☐ api 파드 안에 `token`이 보이고, `can-i list secrets`가 `no`

## 정리

todo(네임스페이스 `todo`)와 other의 `t` 파드는 **이 과목 내내 씁니다**. 지우지 마세요.

## 확인 문제

1. db 파드에서도 `kubectl -n todo exec deploy/db -- ps`와 `kubectl -n todo exec deploy/db -- id`를 실행하세요. postgres 프로그램(`PID 1`)의 USER와 `id`의 결과가 다른 이유는 무엇일까요?
2. other의 `t`에서 `api.todo`의 3000번, `db.todo`의 **5433**번도 `nc -z -w 3 … && echo 열림 || echo 막힘`으로 시험하세요. 5433이 막힌 것은 "막아서"일까요?
