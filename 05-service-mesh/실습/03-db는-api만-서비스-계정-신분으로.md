[← 실습 2](./02-todo에-주입하고-mTLS-성공률-보기.md) · [목차](../서비스-메시-실습.md) · [실습 4 →](./04-Linkerd-지우고-Istio-todo-api-카나리.md)

# 실습 3. db는 api만 — 서비스 계정 신분으로

**무엇을 하나요**: 클라우드 보안 실습 7에서 NetworkPolicy로 풀었던 질문 "db에는 api만 들어오게"를 이번에는 **메시 정책**으로 풉니다. 먼저 지금은 todo 안의 아무 파드나, 다른 네임스페이스의 파드도 비밀번호만 알면 db를 읽는 것을 봅니다. 그다음 api에 **자기 서비스 계정**을 주고, "계정 api의 인증서를 가진 연결만 받는다"는 정책을 db에 겁니다. 라벨을 api로 꾸민 파드까지 막히는지 시험합니다. (교안 03장)

**필요한 것**: 실습 2의 todo(모두 `2/2`, Linkerd 주입).

> **바로 가기** · [1. 지금은 누구나 db에 닿음](#1단계-지금은-누구나-db에-닿음) · [2. 신분 보기 — 모두 default](#2단계-신분-보기--모두-default) · [3. api에 자기 서비스 계정](#3단계-api에-자기-서비스-계정) · [4. 정책 — db는 api 신분만](#4단계-정책--db는-api-신분만) · [5. 다시 시험 — 라벨만 api인 파드도 막힘](#5단계-다시-시험--라벨만-api인-파드도-막힘) · [6. db 프록시 기록 보기](#6단계-db-프록시-기록-보기) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 지금은 누구나 db에 닿음

```bash
mkdir -p ~/mesh && cd ~/mesh
kubectl create namespace other
kubectl -n todo run psql --rm -it --restart=Never --image=postgres:17-alpine --env=PGPASSWORD=todo-pass -- psql -h db -U todo -d todo -c "SELECT * FROM todos;"
kubectl -n other run psql --rm -it --restart=Never --image=postgres:17-alpine --env=PGPASSWORD=todo-pass -- psql -h db.todo -U todo -d todo -c "SELECT * FROM todos;"
```

**이 명령은**: 잠깐 쓰고 지우는(`--rm`) postgres 파드를 띄워 `psql`로 db에 질의. 첫 줄은 todo 안(주입 표시가 있어 **메시 안**), 둘째 줄은 새 네임스페이스 other(**메시 밖**). 다른 네임스페이스의 Service는 `db.todo`로 부릅니다. 비밀번호 `todo-pass`는 todo.yaml의 연습용 Secret에 적힌 값입니다.

**이렇게 나오면 성공**: 두 곳 모두 할 일 목록이 보입니다(내용은 사람마다 다름).

```
 id |   title
----+-----------
  1 | 메시 공부
(1 row)

pod "psql" deleted from todo namespace
```

- db에 들어와야 하는 것은 **api 하나**입니다. 지금은 비밀번호만 알면 메시 안이든 밖이든 누구나 읽습니다
- `If you don't see a command prompt, try pressing enter.` 같은 줄이 섞여 나와도 괜찮습니다

## 2단계. 신분 보기 — 모두 default

```bash
linkerd viz edges deploy -n todo -o wide | grep -v prometheus
```

**이 명령은**: 실습 2의 edges에 열 두 개(`CLIENT_ID` 보낸 쪽 신분, `SERVER_ID` 받은 쪽 신분)를 더해 봄. `grep -v prometheus` = viz 자신의 줄은 뺌.

**이렇게 나오면 성공**: 신분이 모두 `default.todo`.

```
SRC          DST    SRC_NS        DST_NS   CLIENT_ID                SERVER_ID      SECURED
api          db     todo          todo     default.todo             default.todo   √
load         web    todo          todo     default.todo             default.todo   √
web          api    todo          todo     default.todo             default.todo   √
```

- 메시의 신분은 파드의 **서비스 계정** 이름으로 정합니다. todo.yaml은 계정을 정하지 않아 모든 파드가 계정 `default`를 씁니다. 이대로는 db가 web과 api를 신분으로 구별할 수 없습니다

## 3단계. api에 자기 서비스 계정

```bash
kubectl -n todo create serviceaccount api
kubectl -n todo set serviceaccount deploy api api
kubectl -n todo rollout status deploy/api
```

40초쯤 뒤:

```bash
linkerd viz edges deploy -n todo -o wide | grep -v prometheus
```

**이 명령은**: 계정 `api`를 만들고, Deployment api의 파드가 그 계정을 쓰게 바꿈(파드가 다시 만들어짐). 새 api 파드의 프록시는 `api.todo` 인증서를 받습니다.

**이렇게 나오면 성공**: api가 보낼 때(`api → db`) CLIENT_ID, api가 받을 때(`web → api`) SERVER_ID가 `api.todo`.

```
SRC          DST    SRC_NS        DST_NS   CLIENT_ID                SERVER_ID      SECURED
api          db     todo          todo     api.todo                 default.todo   √
load         web    todo          todo     default.todo             default.todo   √
web          api    todo          todo     default.todo             api.todo       √
```

## 4단계. 정책 — db는 api 신분만

```bash
nano db-policy.yaml
```

```yaml
apiVersion: policy.linkerd.io/v1beta3
kind: Server
metadata: {name: db, namespace: todo}
spec:
  podSelector:
    matchLabels: {app: db}
  port: 5432
---
apiVersion: policy.linkerd.io/v1alpha1
kind: MeshTLSAuthentication
metadata: {name: api-only, namespace: todo}
spec:
  identityRefs:
  - kind: ServiceAccount
    name: api
---
apiVersion: policy.linkerd.io/v1alpha1
kind: AuthorizationPolicy
metadata: {name: db-from-api, namespace: todo}
spec:
  targetRef:
    group: policy.linkerd.io
    kind: Server
    name: db
  requiredAuthenticationRefs:
  - group: policy.linkerd.io
    kind: MeshTLSAuthentication
    name: api-only
```

| 리소스 | 이 파일에서 하는 일 |
|---|---|
| Server `db` | **어디를** 지키나 — 라벨 `app: db` 파드의 5432번. Server가 생기면 그 포트는 허용한 것 말고 모두 거부 |
| MeshTLSAuthentication `api-only` | **누구를** — 서비스 계정 `api`의 인증서를 가진 쪽 |
| AuthorizationPolicy `db-from-api` | **허용** — Server `db`에 `api-only`만 들어오게 |

```bash
kubectl apply -f db-policy.yaml
kubectl -n todo get server
```

**이렇게 나오면 성공**

```
server.policy.linkerd.io/db created
meshtlsauthentication.policy.linkerd.io/api-only created
authorizationpolicy.policy.linkerd.io/db-from-api created
NAME   PORT   PROTOCOL   ACCESS POLICY
db     5432   unknown    deny
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `error parsing db-policy.yaml` | 들여쓰기·탭 | 스페이스 2칸. `- kind:` 아래 `name:`은 `kind`와 같은 칸 |
| `no matches for kind "Server"` | Linkerd CRD가 없음(실습 1 4단계) | `linkerd check` |

</details>

## 5단계. 다시 시험 — 라벨만 api인 파드도 막힘

```bash
kubectl -n todo exec deploy/load -c curl -- curl -s -w " %{http_code}\n" http://web/api/todos
kubectl -n todo run psql --rm -it --restart=Never --image=postgres:17-alpine --env=PGPASSWORD=todo-pass -- psql -h db -U todo -d todo -c "SELECT * FROM todos;"
kubectl -n other run psql --rm -it --restart=Never --image=postgres:17-alpine --env=PGPASSWORD=todo-pass -- psql -h db.todo -U todo -d todo -c "SELECT * FROM todos;"
kubectl -n todo run fake --labels=app=api --rm -it --restart=Never --image=postgres:17-alpine --env=PGPASSWORD=todo-pass -- psql -h db -U todo -d todo -c "SELECT * FROM todos;"
```

**이 명령은**: ① 앱 길(web → api → db)이 그대로 되는지 ② 1단계의 두 psql ③ 라벨을 `app=api`로 붙여 api인 척하는 파드 `fake`.

**이렇게 나오면 성공**: ①만 되고 나머지 셋은 끊깁니다.

```
[{"id":1,"title":"메시 공부"}] 200
```
```
psql: error: connection to server at "db" (10.96.149.231), port 5432 failed: server closed the connection unexpectedly
	This probably means the server terminated abnormally
	before or while processing the request.
```

| 누가 db에 | 정책 전 (1단계) | 정책 후 (지금) | 보안 실습 7의 NetworkPolicy라면 |
|---|---|---|---|
| api (계정 api) | 됨 | **됨** | 됨 |
| todo의 psql (계정 default) | 됨 | 끊김 | 막힘(시간 초과) |
| other의 psql (메시 밖) | 됨 | 끊김 | 막힘(시간 초과) |
| fake (라벨 `app=api`, 계정 default) | — | **끊김** | **됨** — 라벨로 고르므로 |

- NetworkPolicy는 **라벨**을 보고, 메시 정책은 **인증서에 적힌 신분**을 봅니다. 라벨은 파드를 만드는 사람이 마음대로 붙일 수 있지만, 계정 api의 인증서는 계정 api로 뜬 파드만 받습니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| ①이 `500`이거나 오류 | api를 계정 api로 바꾸지 않았음(3단계) — api도 막힘 | 3단계 후 `kubectl -n todo rollout restart deploy/api` |
| psql이 여전히 목록을 보여 줌 | 정책을 안 넣었거나 이름 오타 | `kubectl -n todo get server,authorizationpolicy,meshtlsauthentication` |
| `pods "psql" already exists` | 앞 파드가 남음 | `kubectl -n todo delete pod psql` (other도 같음) |

</details>

## 6단계. db 프록시 기록 보기

```bash
kubectl -n todo logs deploy/db -c linkerd-proxy | grep "Connection denied" | tail -3
```

**이 명령은**: db 파드의 프록시 컨테이너(`linkerd-proxy`) 기록에서 거부한 연결만 봄.

**이렇게 나오면 성공**: 거부한 연결마다 한 줄(길어서 줄이 넘어갑니다).

```
… Connection denied server.group=policy.linkerd.io server.kind=server server.name=db tls=Some(Established { client_id: Some(ClientId(Dns(Name("default.todo.serviceaccount.identity.linkerd.cluster.local")))), … }) client=10.244.1.16:33314
… Connection denied server.group=policy.linkerd.io server.kind=server server.name=db tls=None(NoClientHello) client=10.244.1.17:59588
```

- 첫 줄 = 메시 안 파드(인증서는 있지만 이름이 `default.todo`), 둘째 줄 = 메시 밖 파드(`tls=None` — 인증서 자체가 없음). 막은 쪽은 db 앱이 아니라 **db 옆 프록시**입니다

## 끝났는지 확인
- ☐ 정책 전 todo·other의 psql이 할 일 목록을 읽음
- ☐ `-o wide`에서 api의 신분이 `default.todo` → `api.todo`
- ☐ 정책 후 웹 요청은 `200`, psql 두 곳과 `fake`는 `server closed the connection unexpectedly`
- ☐ db 프록시 기록에 `Connection denied`

## 정리
- 정책·계정은 그대로 둡니다. 실습 4에서 Linkerd를 지우면 정책도 함께 사라집니다
- 네임스페이스 `other`는 실습 4 정리에서 지웁니다

## 확인 문제
1. 6단계 기록에서 todo 안의 psql과 other의 psql 줄은 `tls=` 부분이 어떻게 다른가요? 왜 다른가요?
2. 5단계 표의 마지막 줄 — 보안 실습 7의 NetworkPolicy는 왜 `fake`를 통과시키나요? 메시 정책은 무엇을 보고 막나요?
