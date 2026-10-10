[← 실습 6](./06-RBAC-파드를-읽기만-하는-계정.md) · [목차](../클라우드-보안-실습.md) · [실습 8 →](./08-Pod-Security-Admission-라벨-하나로-거부되게.md)

# 실습 7. NetworkPolicy — db는 api만

**무엇을 하나요**: 실습 1에서 다른 네임스페이스의 파드도 todo의 db에 닿는 것을 봤습니다. todo의 연결은 **web → api → db** 두 길뿐이니, NetworkPolicy로 **전부 막은 뒤 이 두 길만 엽니다.** 단계마다 누가 닿고 누가 막히는지 시험합니다. (교안 08장)

**필요한 것**: todo, 실습 1의 other 시험 파드 `t`.

> **바로 가기** · [1. 지금은 누구나 db에 닿음](#1단계-지금은-누구나-db에-닿음) · [2. 전부 막기](#2단계-전부-막기) · [3. 필요한 길만 열기](#3단계-필요한-길만-열기) · [4. 화면으로 확인](#4단계-화면으로-확인) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 지금은 누구나 db에 닿음

todo의 web·api 이미지에도 `nc`가 들어 있어 파드 안에서 바로 시험할 수 있습니다.

```bash
cd ~/sec
kubectl -n todo exec deploy/web -- nc -z -w 3 db 5432 && echo 열림 || echo 막힘
kubectl -n todo exec deploy/api -- nc -z -w 3 db 5432 && echo 열림 || echo 막힘
kubectl -n other exec t -- nc -z -w 3 db.todo 5432 && echo 열림 || echo 막힘
```

**이 명령은**: 위에서부터 ① web → db ② api → db ③ other의 t → db. 같은 네임스페이스 안에서는 Service 이름(`db`)만, 다른 네임스페이스에서는 `db.todo`로 부릅니다.

**이렇게 나오면 성공**: 세 줄 모두 `열림`

```
열림
열림
열림
```

**왜 문제인가**: db에 닿아야 하는 것은 **api 하나**입니다. 화면(web)이나 상관없는 네임스페이스의 파드가 DB 포트에 닿을 이유가 없습니다.

## 2단계. 전부 막기

```bash
nano deny-all.yaml
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: todo
spec:
  podSelector: {}
  policyTypes: [Ingress]
```

| 줄 | 뜻 |
|---|---|
| `kind: NetworkPolicy` · `namespace: todo` | todo 네임스페이스에 거는 네트워크 규칙 |
| `podSelector: {}` | 빈 선택자 = todo의 **모든 파드**에 적용 |
| `policyTypes: [Ingress]` | 들어오는 연결(Ingress)에 대한 규칙. 아래에 허용 목록(`ingress:`)이 없으니 **들어오는 것 전부 막음** |

```bash
kubectl apply -f deny-all.yaml
kubectl -n todo exec deploy/api -- nc -z -w 3 db 5432 && echo 열림 || echo 막힘
kubectl -n todo exec deploy/web -- wget -qO- -T 3 http://api:3000/api/todos
```

**이렇게 나오면 성공**: 앱 안의 연결까지 모두 막힙니다(이것이 맞음).

```
networkpolicy.networking.k8s.io/deny-all created
command terminated with exit code 1
막힘
wget: download timed out
command terminated with exit code 1
```

- api → db도, web → api도 막혔습니다. 지금 todo는 **동작하지 않는 상태**입니다. 다음 단계에서 필요한 길만 엽니다

## 3단계. 필요한 길만 열기

```bash
nano allow.yaml
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-from-web
  namespace: todo
spec:
  podSelector:
    matchLabels:
      app: api
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: web
    ports:
    - port: 3000
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-from-api
  namespace: todo
spec:
  podSelector:
    matchLabels:
      app: db
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api
    ports:
    - port: 5432
```

**이 파일은** — `---`로 나눈 정책 두 개입니다. 둘은 이름과 라벨만 다르고 모양이 같습니다.

| 줄 | 뜻 |
|---|---|
| `podSelector: matchLabels: app: api` | 이 정책이 **지키는 파드** = 라벨 `app: api`(api 파드) |
| `ingress: - from: - podSelector: matchLabels: app: web` | 들어와도 되는 쪽 = **같은 네임스페이스**의 라벨 `app: web` 파드 |
| `ports: - port: 3000` | 그것도 3000번으로만 |
| 둘째 정책 `db-from-api` | db(`app: db`)에는 api(`app: api`)만, 5432번으로만 |

- 라벨(`app: web` 등)은 `todo.yaml`의 각 Deployment `template.metadata.labels`에 적힌 것입니다. `kubectl -n todo get pods --show-labels`로 볼 수 있습니다

```bash
kubectl apply -f allow.yaml
kubectl -n todo get networkpolicy
kubectl -n todo exec deploy/api -- nc -z -w 3 db 5432 && echo 열림 || echo 막힘
kubectl -n todo exec deploy/web -- nc -z -w 3 db 5432 && echo 열림 || echo 막힘
kubectl -n other exec t -- nc -z -w 3 db.todo 5432 && echo 열림 || echo 막힘
kubectl -n todo exec deploy/web -- wget -qO- -T 3 http://api:3000/api/todos; echo
```

**이렇게 나오면 성공**: api → db `열림`, web → db `막힘`, other → db `막힘`, 그리고 할 일 목록

```
networkpolicy.networking.k8s.io/api-from-web created
networkpolicy.networking.k8s.io/db-from-api created
NAME           POD-SELECTOR   AGE
api-from-web   app=api        2s
db-from-api    app=db         2s
deny-all       <none>         40s
열림
command terminated with exit code 1
막힘
command terminated with exit code 1
막힘
[{"id":1,"title":"secure api"}]
```

**왜 그런가**: NetworkPolicy는 **허용 목록**입니다. 정책이 고른 파드는 "목록에 있는 것만" 들어올 수 있고, 정책이 여러 개면 허용이 **더해집니다**(합집합). 예를 들어 db 파드에는 `deny-all`(허용 없음)과 `db-from-api`(api에서 5432만 허용) 두 정책이 걸려 있고, 둘을 더하면 "api에서 5432만"이 됩니다. "막는 규칙"을 따로 쓰는 것이 아니라, 전부 막는 정책(`deny-all`) 위에 필요한 허용을 하나씩 더하는 방식입니다.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| api → db가 `막힘` | `allow.yaml`의 라벨·포트 오타, 또는 들여쓰기 | `kubectl -n todo describe networkpolicy db-from-api`의 `Allowing ingress traffic` 아래 확인 |
| other → db가 `열림` | 정책이 적용되지 않음(`namespace: todo` 빠짐 등) | `kubectl -n todo get networkpolicy`에 세 개가 있는지 |
| 할 일 목록 대신 `wget: download timed out` | `api-from-web`이 없거나 포트 오타 | 위와 같이 확인 |

</details>

## 4단계. 화면으로 확인

브라우저로도 확인합니다. **터미널 1**:

```bash
kubectl -n todo port-forward svc/web 8088:80
```

**터미널 2**:

```bash
curl -s localhost:8088 | head -3
curl -s localhost:8088/api/todos; echo
```

**이렇게 나오면 성공**: Kubernetes 실습 7과 같은 화면

```
<!doctype html>
<html lang="ko">
<head>
[{"id":1,"title":"secure api"}]
```

브라우저: PORTS 탭에서 `8088` 전달 → `http://localhost:8088` → 할 일 추가·삭제. 다 봤으면 터미널 1에서 **Ctrl+C**.

- `deny-all`이 web도 막는데 화면이 열리는 이유: `port-forward`는 네트워크를 거치지 않고 노드에서 파드 안으로 바로 이어 주는 **관리용 통로**라 NetworkPolicy가 걸리지 않습니다. 다른 파드(예: Ingress)에서 web으로 들어오게 하려면 web 쪽 허용 정책을 하나 더 씁니다(미션 2의 Traefik → frontend)

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `Unable to listen on port 8088: … address already in use` | 8088을 다른 것(Kubernetes 과목의 port-forward 등)이 씀 | 그 터미널에서 Ctrl+C, 또는 `8089:80`처럼 다른 번호 |

</details>

## 끝났는지 확인

- ☐ 정책 전 세 시험이 모두 `열림`
- ☐ `deny-all` 뒤 api → db도 `막힘`
- ☐ `allow.yaml` 뒤 api → db `열림`, web → db `막힘`, other → db `막힘`
- ☐ 브라우저(또는 curl)에서 todo가 그대로 동작

## 정리

정책 세 개는 **그대로 둡니다**(todo가 지켜지는 상태). other의 `t`는 미션 2에서도 씁니다.

정책 규칙을 정리하면 이렇습니다.

| 상황 | 결과 |
|---|---|
| 정책이 하나도 없음 | 전부 허용 — 1단계의 세 줄 모두 `열림` |
| `podSelector: {}` + `policyTypes: [Ingress]` + 규칙 없음 | 이 네임스페이스로 들어오는 것 전부 차단 — 2단계의 `deny-all`, api → db도 `막힘` |
| 정책 여러 개 | **합집합**(허용이 더해짐). "막는 규칙"은 따로 없음 — db = `deny-all` + `db-from-api` → api의 5432만 |
| `from`에 `podSelector`만 | **같은 네임스페이스**의 그 라벨 파드만 — other의 `t`에 `app=api`를 붙여도 막힘(확인 문제 1) |

## 확인 문제

1. other의 `t`에 라벨 `app=api`를 붙이면(`kubectl -n other label pod t app=api`) db에 닿을까요? 시험한 뒤 라벨을 지웁니다(`kubectl -n other label pod t app-`). 다른 네임스페이스의 파드를 허용하려면 `from`에 무엇을 더 적어야 할까요?
2. `deny-all`만 지우면(`kubectl -n todo delete networkpolicy deny-all`) web → db는 어떻게 될까요? web → api, other → web(`web.todo 80`)은요? 확인한 뒤 `kubectl apply -f deny-all.yaml`로 되돌립니다.
