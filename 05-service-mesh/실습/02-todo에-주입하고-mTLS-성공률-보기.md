[← 실습 1](./01-노드-3개-클러스터와-Linkerd-설치.md) · [목차](../서비스-메시-실습.md) · [실습 3 →](./03-db는-api만-서비스-계정-신분으로.md)

# 실습 2. todo에 주입하고 mTLS·성공률 보기

**무엇을 하나요**: todo(web → api → db)와 1초마다 할 일 목록을 부르는 `load`를 띄워, **주입 전에는 아무도 요청을 세지 않는 것**을 먼저 봅니다. 그다음 todo 네임스페이스에 **프록시를 주입**합니다. 앱 코드도 YAML의 컨테이너도 바꾸지 않았는데 성공률·요청 수·지연이 보이고, 서비스 사이 연결이 암호화(mTLS)되는 것을 확인합니다. (교안 02장)

**필요한 것**: 실습 1의 Linkerd(제어 영역 + viz).

> **바로 가기** · [1. todo 이미지 넣고 띄우기](#1단계-todo-이미지-넣고-띄우기) · [2. 주입 전 — 아무도 세지 않음](#2단계-주입-전--아무도-세지-않음) · [3. 주입 — 표시하고 다시 만들기](#3단계-주입--표시하고-다시-만들기) · [4. 성공률·지연·mTLS 보기](#4단계-성공률지연mtls-보기) · [5. 요청 하나하나 보기 — tap](#5단계-요청-하나하나-보기--tap) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. todo 이미지 넣고 띄우기

클러스터를 새로 만들었으므로 todo 이미지를 다시 넣습니다. 이미 VM에 있으면 빌드는 금방 끝납니다.

```bash
cd ~/ktcloud-cloud-native-lab/lab/docker/todo
docker build -t todo-api:v1 api
docker build -t todo-web:v1 web
kind load docker-image todo-api:v1 todo-web:v1 --name lab
kubectl apply -f ~/ktcloud-cloud-native-lab/03-클라우드-보안/todo.yaml
kubectl -n todo patch deploy db -p '{"spec":{"strategy":{"type":"Recreate","rollingUpdate":null}}}'
kubectl -n todo create deploy load --image=curlimages/curl:8.16.0 -- sh -c "while true; do curl -s -o /dev/null http://web/api/todos; sleep 1; done"
kubectl -n todo get pods
```

파드가 모두 `Running`이 되면 할 일을 하나 넣어 둡니다(실습 3에서 db를 읽을 때 씀).

```bash
kubectl -n todo exec deploy/load -- curl -s -X POST -H "Content-Type: application/json" -d '{"title":"메시 공부"}' http://web/api/todos; echo
```

**이 명령은**: todo 이미지 두 개를 만들어 클러스터 노드에 넣고(Kubernetes 실습 7과 같은 명령), 클라우드 보안 과목에서 쓴 todo 매니페스트(web·api·db)를 그대로 적용. `patch deploy db` = db를 다시 만들 때 **옛 파드를 먼저 끄고** 새 파드를 띄우게 바꿈(3단계에서 파드를 다시 만들 때 옛 db와 새 db가 같은 저장 공간을 동시에 쓰지 않게). 마지막 `create deploy load` = 1초마다 `http://web/api/todos`(할 일 목록)를 부르는 손님 역할 파드.

**이렇게 나오면 성공**: 파드 4개 모두 `1/1 Running` (강사 VM: 빌드 11초, `kind load` 8초)

```
NAME                    READY   STATUS    RESTARTS   AGE
api-7bcdc699f-kk5jz     1/1     Running   0          11s
db-86878656ff-88mtb     1/1     Running   0          11s
load-75d7b4fccd-v7kjk   1/1     Running   0          11s
web-5bdd6887b7-sr4xc    1/1     Running   0          11s
```
```
{"id":1,"title":"메시 공부"}
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| api·web이 `ErrImageNeverPull` 또는 `ImagePullBackOff` | `kind load`를 빠뜨림 | `kind load docker-image todo-api:v1 todo-web:v1 --name lab` 후 `kubectl -n todo rollout restart deploy` |
| `the path "…/todo.yaml" does not exist` | 저장소를 아직 안 받음 | `cd ~/ktcloud-cloud-native-lab && git pull` |
| `deployments.apps "load" already exists` | 두 번 실행 | 무시 |
| 할 일 넣기가 `502 Bad Gateway`·빈 응답 | api가 db를 기다리며 아직 뜨는 중 | 10초 뒤 다시 |

</details>

## 2단계. 주입 전 — 아무도 세지 않음

`load`가 1초마다 요청하고 있습니다. 30초쯤 기다린 뒤:

```bash
linkerd viz stat deploy -n todo
linkerd viz edges deploy -n todo
```

**이렇게 나오면 성공**

```
No traffic found.
No edges found.
```

- 요청은 1초마다 가고 있습니다. 그런데 **주입 전에는 아무도 세지 않습니다** — 성공률도, 요청 수도, 지연도, 암호화됐는지도 알 수 없습니다. 4단계에서 같은 두 명령을 주입 **후**에 다시 칩니다

## 3단계. 주입 — 표시하고 다시 만들기

```bash
kubectl annotate ns todo linkerd.io/inject=enabled
kubectl -n todo rollout restart deploy
kubectl -n todo get pods                     # 30초쯤 뒤 모두 2/2
kubectl -n todo get pod -l app=api -o jsonpath='{.items[0].spec.initContainers[*].name}'; echo
```

**이 명령은**: 네임스페이스 `todo`에 "여기 파드에는 프록시를 넣어라"라는 **주석**을 붙임. 주입은 파드가 **만들어질 때**만 일어나므로 `rollout restart`로 todo의 Deployment를 모두 다시 만듭니다. 마지막 줄 = api 파드에 끼워진 컨테이너 이름.

**이렇게 나오면 성공**: `READY`가 `1/1` → **`2/2`** (앱 + 프록시), 끼워진 이름 두 개.

```
NAME                   READY   STATUS    RESTARTS   AGE
api-57b79b94fb-nxrzc   2/2     Running   0          63s
db-b5ddd4dfb-wbf4x     2/2     Running   0          63s
load-d469f5865-srjsr   2/2     Running   0          63s
web-6fbbf5bcd8-7hg8t   2/2     Running   0          63s
```
```
linkerd-init linkerd-proxy
```

- `linkerd-proxy`가 프록시입니다. `initContainers`에 들어 있지만 끝나지 않고 앱과 함께 계속 돕니다(앱보다 먼저 시작하는 사이드카)
- db는 1단계에서 바꾼 방식대로 옛 파드가 먼저 꺼진 뒤 새로 떠서 몇 초 늦게 `2/2`가 됩니다. 그사이 `load`의 요청 몇 개는 실패합니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 계속 `1/1` | 주석만 붙이고 `rollout restart`를 안 함 | `kubectl -n todo rollout restart deploy` |
| `1/1`인데 restart도 했음 | 주석 이름 오타 | `kubectl get ns todo -o yaml`의 annotations 확인 → 고친 뒤 다시 restart |
| `1/1`과 `2/2`가 섞여 있음 | 옛 파드가 아직 끝나는 중(`Terminating`) | 20~30초 뒤 다시 |

</details>

## 4단계. 성공률·지연·mTLS 보기

30초쯤 기다린 뒤:

```bash
linkerd viz stat deploy -n todo
linkerd viz edges deploy -n todo
```

**이렇게 나오면 성공**

```
NAME   MESHED   SUCCESS      RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99   TCP_CONN
api       1/1   100.00%   1.1rps           1ms           1ms           1ms          3
db        1/1   100.00%   0.3rps           1ms           1ms           1ms          3
load      1/1   100.00%   0.3rps           1ms           1ms           1ms          1
web       1/1   100.00%   1.1rps           2ms           3ms           3ms          3
```
```
SRC          DST    SRC_NS        DST_NS   SECURED
prometheus   api    linkerd-viz   todo     √
...
api          db     todo          todo     √
load         web    todo          todo     √
web          api    todo          todo     √
```

- `SUCCESS` 성공률, `RPS` 초당 받은 요청 수, `LATENCY_P95` 지연 — **골든 지표**. web·api가 1초에 약 1번(`load`의 요청)
- edges의 마지막 `√` = SECURED, 그 화살표가 **mTLS로 암호화**됨. `load → web → api → db`가 todo의 호출 순서 그대로입니다
- `prometheus` 줄은 viz가 숫자를 가져가는 연결입니다

| | 주입 전 (2단계) | 주입 후 (지금) |
|---|---|---|
| READY | `1/1` | `2/2` |
| `viz stat` | `No traffic found.` | SUCCESS · RPS · 지연 |
| `viz edges` | `No edges found.` | `√` (mTLS) |
| 앱 코드 · 컨테이너 | — | 바꾼 것 없음 |

- **db는 HTTP가 아니라 postgres 연결(TCP)입니다.** 그래서 api → db는 "연결이 몇 개, 암호화됐나"(`TCP_CONN`, `√`)만 보이고, 요청 하나하나의 성공률·지연은 **web → api 구간**에서 의미가 있습니다

## 5단계. 요청 하나하나 보기 — tap

```bash
linkerd viz tap deploy/api -n todo        # 몇 줄 보고 Ctrl+C
```

**이 명령은**: api 프록시를 지나가는 요청을 실시간으로 한 줄씩 보여 줌.

**이렇게 나오면 성공**

```
req id=0:0 proxy=in  src=10.244.2.8:39198 dst=10.244.1.11:3000 tls=true :method=GET :authority=api:3000 :path=/api/todos
rsp id=0:0 proxy=in  src=10.244.2.8:39198 dst=10.244.1.11:3000 tls=true :status=200 latency=21975µs
end id=0:0 proxy=in  src=10.244.2.8:39198 dst=10.244.1.11:3000 tls=true duration=47µs response-length=0B
```

- `req` 요청, `rsp` 응답, `end` 끝. `tls=true` = 이 요청이 암호화됨, `:path=/api/todos` = web이 api에 보낸 경로, `:status=200` = 응답 코드. IP는 사람마다 다릅니다

## 끝났는지 확인
- ☐ 주입 전 `linkerd viz stat`이 `No traffic found.`
- ☐ `kubectl -n todo get pods`가 모두 `2/2`
- ☐ `linkerd viz edges deploy -n todo`에 `load → web → api → db` 모두 `√`
- ☐ `linkerd viz tap`에 `tls=true`

## 정리
- `todo`와 `load`는 실습 3·4·5에서 계속 씁니다. 지우지 마세요

## 확인 문제
1. 주입 **전**에는 `linkerd viz stat`이 `No traffic found.`였습니다. `load`는 그때도 1초마다 요청하고 있었는데 왜 안 보였을까요?
2. `linkerd viz edges deploy -n todo -o wide`를 쳐 보세요. `web → api`와 `api → db` 줄의 `CLIENT_ID`(보낸 쪽 신분)는 각각 무엇인가요? 두 값이 같다면, "db에는 api만 들어오게" 하려 할 때 무엇이 곤란할까요?
