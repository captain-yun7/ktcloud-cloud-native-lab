[← 실습 2](./02-경로-헤더-가중치.md) · [목차](../API-Gateway-실습.md) · [실습 4 →](./04-JWT.md)

# 실습 3. API 키

**무엇을 하나요**: todo의 `/api`(HTTPRoute `todo-api`)에 **API 키 검사**를 붙입니다. 키가 없거나 틀리면 게이트웨이가 401로 막고, 맞으면 "누가 불렀는지"(`x-client-id`)만 앱에 넘깁니다. 키 자체는 앱까지 가지 않습니다. 먼저 정책 없이 아무나 들어오고, 아무 키나 아무 이름이나 앱까지 그대로 가는 것을 봅니다. (교안 04장)

**필요한 것**: 실습 2의 HTTPRoute `todo-api`(→ v2), v2의 `/api/me`.

> **바로 가기** · [1. 키 없이 — 아무나, 아무 이름이나](#1단계-키-없이--아무나-아무-이름이나) · [2. 키 목록과 정책 쓰기](#2단계-키-목록과-정책-쓰기) · [3. 키 없이, 틀린 키로, 맞는 키로](#3단계-키-없이-틀린-키로-맞는-키로) · [4. 앱이 받은 것 — 이름만, 키는 없음](#4단계-앱이-받은-것--이름만-키는-없음) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 키 없이 — 아무나, 아무 이름이나

```bash
cd ~/apigw
curl -s -o /dev/null -w "%{http_code}\n" todo.localhost:8080/api/todos
curl -s -H "x-api-key: aaa" todo.localhost:8080/api/me; echo
curl -s -H "x-client-id: boss" todo.localhost:8080/api/me; echo
```

**이 명령은**: 첫째 = 키 없이 할 일 목록. 둘째 = 아무 키(`aaa`)를 넣고 앱이 받은 헤더를 봄. 셋째 = "나는 boss다"라는 이름 헤더를 직접 넣어 봄.

**이렇게 나오면 성공**

```
200
{"version":2,"gateway":"front","client":null,"user":null,"apiKey":"aaa"}
{"version":2,"gateway":"front","client":"boss","user":null,"apiKey":null}
```

- 키가 없어도 할 일 목록이 나옵니다. 누구나 `POST`로 할 일을 넣고 `DELETE`로 지울 수도 있습니다
- 넣은 키가 앱까지 그대로 갑니다(`"apiKey":"aaa"`). 앱 로그나 추적 기록에 키가 남을 수 있습니다
- 이름 헤더를 꾸미면 앱은 그대로 믿습니다(`"client":"boss"`)

## 2단계. 키 목록과 정책 쓰기

```bash
nano apikey.yaml
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: api-keys
  namespace: todo
stringData:
  team-a: key-aaa
  team-b: key-bbb
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: apikey
  namespace: todo
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: todo-api
  apiKeyAuth:
    credentialRefs:
    - name: api-keys
    extractFrom:
    - headers: ["x-api-key"]
    forwardClientIDHeader: x-client-id    # 앱에는 키 대신 "누구인지"만
    sanitize: true                        # 키 자체는 앱으로 넘기지 않는다
```

**이 파일은**: 두 개를 한 파일에(`---`로 나눔).

| 부분 | 뜻 |
|---|---|
| Secret `api-keys` | **클라이언트 이름: 키**. `team-a`의 키는 `key-aaa` |
| `targetRefs:` | 이 정책을 **붙일** HTTPRoute — `todo-api`(= `/api`). 화면(`/`)에는 안 붙음 |
| `extractFrom.headers` | 키를 `x-api-key` 헤더에서 꺼냄 |
| `forwardClientIDHeader` | 맞으면 앱에 `x-client-id: team-a`를 넣어 넘김 |
| `sanitize: true` | 키 값은 앱으로 안 넘김 |

```bash
kubectl apply -f apikey.yaml
kubectl -n todo get securitypolicy apikey -o jsonpath='{.status.ancestors[0].conditions[0].reason}'; echo
```

**이렇게 나오면 성공**

```
secret/api-keys created
securitypolicy.gateway.envoyproxy.io/apikey created
Accepted
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 둘째 명령이 빈 줄 | `targetRefs`의 `name` 오타 — 붙을 HTTPRoute를 못 찾음 | `kubectl -n todo get httproute` |
| `no matches for kind "SecurityPolicy"` | `apiVersion` 오타 | `gateway.envoyproxy.io/v1alpha1` |
| Secret만 생기고 정책이 없음 | `---` 줄이 빠짐 | 파일 가운데 `---` 확인 |

</details>

## 3단계. 키 없이, 틀린 키로, 맞는 키로

```bash
curl -s -w " %{http_code}\n" todo.localhost:8080/api/todos
curl -s -w " %{http_code}\n" -H "x-api-key: nope" todo.localhost:8080/api/todos
curl -s -w " %{http_code}\n" -H "x-api-key: key-aaa" todo.localhost:8080/api/todos
curl -s -o /dev/null -w "%{http_code}\n" todo.localhost:8080/
curl -s -o /dev/null -w "%{http_code}\n" todo.localhost:8080/v1/todos
```

**이 명령은**: 같은 주소를 키 없이 · 틀린 키로 · 맞는 키로 부르고 본문 뒤에 상태 코드를 붙임. 넷째 = 화면(`/`)은 어떤지, 마지막 = 실습 2 6단계의 버전 주소를 키 없이.

**이렇게 나오면 성공**

```
Client authentication failed. 401
Client authentication failed. 401
[{"id":1,"title":"모니터링 공부"},{"id":2,"title":"지표 달기"}] 200
200
401
```

- 401은 **게이트웨이가** 돌려준 것입니다. 앱까지 가지 않았습니다(실습 5에서 숫자로 확인)
- 화면(`/`)은 정책을 붙이지 않은 HTTPRoute `todo`라 그대로 200
- `/v1/todos`도 401 — 버전 경로는 같은 HTTPRoute `todo-api` 안의 규칙이라 정책이 함께 걸립니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 첫째가 `200` | 정책 적용 전 | 5초 뒤 다시 |
| 셋째가 `401` | 헤더 이름·키 값 오타 | `x-api-key: key-aaa` 그대로 |
| 마지막(`/`)도 `401` | 정책 `targetRefs`가 `todo`(화면)를 가리킴 | `name: todo-api`로 고쳐 apply |

</details>

## 4단계. 앱이 받은 것 — 이름만, 키는 없음

```bash
curl -s -H "x-api-key: key-aaa" todo.localhost:8080/api/me; echo
curl -s -H "x-api-key: key-aaa" -H "x-client-id: team-b" todo.localhost:8080/api/me; echo
curl -s -H "x-api-key: key-bbb" todo.localhost:8080/api/me; echo
```

**이 명령은**: 첫째 = 맞는 키로 앱이 받은 헤더를 봄. 둘째 = 맞는 키에 **남의 이름**(`team-b`)을 꾸며 넣어 봄. 셋째 = team-b의 키로.

**이렇게 나오면 성공**

```
{"version":2,"gateway":"front","client":"team-a","user":null,"apiKey":null}
{"version":2,"gateway":"front","client":"team-a","user":null,"apiKey":null}
{"version":2,"gateway":"front","client":"team-b","user":null,"apiKey":null}
```

| 요청 | 정책 전 (1단계) | 정책 후 |
|---|---|---|
| 키 없음 | `200` | `401` — 게이트웨이가 막음 |
| 아무 키(`aaa`) | `200`, 앱이 키를 받음(`"apiKey":"aaa"`) | `401` |
| 맞는 키 | — | `200`, 앱은 이름만(`"client":"team-a"`, `"apiKey":null`) |
| 이름을 꾸밈(`x-client-id`) | 앱이 믿음(`"boss"`) | 키의 주인 이름으로 덮어씀(`team-a`) |

- 브라우저에서 `http://todo.localhost:<포트>`를 새로 고쳐 보세요. 화면은 뜨지만 목록 자리에 `api 연결 실패: HTTP 401`이 보입니다. 화면 안의 자바스크립트도 `/api/todos`를 부르는데, 키가 없는 손님이기 때문입니다. 사람이 쓰는 화면은 보통 로그인 토큰(실습 4)으로, 프로그램은 키로 나눕니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `"client"`에 키 값(`key-aaa`)이 보임 | Secret의 이름·키를 거꾸로 씀(`key-aaa: team-a`) | `이름: 키` 순서로 고쳐 apply |
| `"apiKey":"key-aaa"` | `sanitize: true`가 빠짐 | 줄 추가 후 apply |
| `Cannot GET /api/me` | 실습 2의 5단계(v2로 다 옮기기)를 안 함 | 실습 2의 5단계 |

</details>

## 끝났는지 확인
- ☐ 정책 전 키 없이 `200`, 앱이 `"apiKey":"aaa"`·`"client":"boss"`를 받음
- ☐ 키 없음·틀린 키 `401`, `key-aaa`는 `200`
- ☐ 맞는 키 + 꾸민 이름 → 앱은 `"client":"team-a"`, `"apiKey":null`
- ☐ 화면(`/`)은 `200`

## 정리
- 모두 둡니다. 실습 5가 이 정책이 붙여 주는 `x-client-id`로 횟수를 셉니다

## 확인 문제
1. `apikey.yaml`의 Secret에 `team-c: key-ccc`를 한 줄 더해 apply한 뒤 `key-ccc`로 `/api/me`를 불러 보세요. 앱이 받은 `client`는? 앱이나 정책을 고쳤나요?
2. `-H "X-API-KEY: key-aaa"`처럼 헤더 이름을 대문자로 보내면 통과할까요?
