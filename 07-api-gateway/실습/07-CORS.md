[← 실습 6](./06-타임아웃-재시도-서킷-브레이커.md) · [목차](../API-Gateway-실습.md) · [실습 8 →](./08-HTTPS.md)

# 실습 7. CORS

**무엇을 하나요**: 파트너 회사의 화면(`http://partner.localhost:8080`)이 브라우저에서 우리 API(`todo.localhost:8080/api/todos`)를 부르려 합니다. 브라우저는 **출처(주소의 앞부분)가 다른** 화면에서 API를 부르면, API 쪽이 "이 출처는 허락함"이라고 답하지 않는 한 결과를 화면에 넘겨주지 않습니다. 이 규칙이 **CORS**입니다. curl로 브라우저가 보내는 것과 똑같은 요청(`Origin` 헤더, 미리 묻는 `OPTIONS`)을 보내 먼저 막히는 것을 보고, 키 정책에 CORS 설정을 더해 허락 표시가 붙는 것을 확인합니다. 마지막에 허락하지 않은 출처에도 **서버는 답한다**는 것, 즉 CORS는 키를 대신하지 못한다는 것을 봅니다. (교안 07장)

**필요한 것**: 실습 2의 HTTPRoute `todo-api`, 실습 3의 키 정책 `apikey`(`~/apigw/apikey.yaml`).

> **바로 가기** · [1. 다른 출처에서 부르면 — 허락 표시가 없음](#1단계-다른-출처에서-부르면--허락-표시가-없음) · [2. CORS 정책을 따로 만들면 — 안 붙음](#2단계-cors-정책을-따로-만들면--안-붙음) · [3. 키 정책에 CORS 더하기](#3단계-키-정책에-cors-더하기) · [4. 미리 묻기와 실제 요청 다시](#4단계-미리-묻기와-실제-요청-다시) · [5. 허락 안 한 출처 — 서버는 답한다](#5단계-허락-안-한-출처--서버는-답한다) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 다른 출처에서 부르면 — 허락 표시가 없음

브라우저가 파트너 화면에서 API를 부를 때 보내는 두 요청을 curl로 흉내 냅니다.

```bash
cd ~/apigw
O="Origin: http://partner.localhost:8080"
curl -s -D - -o /dev/null -H "$O" -H "x-api-key: key-bbb" todo.localhost:8080/api/todos | grep -i "^HTTP\|access-control"
curl -s -D - -X OPTIONS -H "$O" -H "Access-Control-Request-Method: GET" -H "Access-Control-Request-Headers: x-api-key" todo.localhost:8080/api/todos
```

**이 명령은**: 첫째 = 파트너 화면에서 온 것처럼(`Origin`) 키를 넣어 GET, 응답 헤더 중 상태 줄과 `access-control`로 시작하는 줄만. 둘째 = 브라우저가 진짜 요청 전에 보내는 **미리 묻기**(`OPTIONS`, "GET으로, `x-api-key`를 붙여도 되나요?").

**이렇게 나오면 성공**(막히는 것이 정상): GET은 `200`이지만 `access-control` 줄이 **없음**. 미리 묻기는 키가 없어 `401`

```
HTTP/1.1 200 OK
HTTP/1.1 401 Unauthorized
content-length: 29
content-type: text/plain
date: Thu, 22 Oct 2026 13:54:08 GMT

Client authentication failed.
```

- 데이터는 왔지만 허락 표시가 없어 **브라우저는 화면에 넘겨주지 않습니다**. 실제 브라우저였다면 미리 묻기가 401이라 진짜 요청은 보내지도 않았습니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 첫째가 `429` | 실습 5의 분당 5번 제한(team-b) | 1분 기다림 |
| 첫째가 `401` | `$O`가 빔(새 터미널) 또는 키 오타 | `O=…` 줄부터 다시 |
| 둘째가 `-X OPTIONS` 없이 GET처럼 나옴 | `-X OPTIONS` 빠짐 | 그대로 붙여 넣기 |

</details>

## 2단계. CORS 정책을 따로 만들면 — 안 붙음

CORS만 담은 정책을 새 파일로 따로 만들어 봅니다. 일부러 하는 실수입니다.

```bash
nano cors.yaml
```

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: cors
  namespace: todo
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: todo-api
  cors:
    allowOrigins: ["http://partner.localhost:8080"]
    allowMethods: ["GET", "POST"]
    allowHeaders: ["x-api-key", "content-type"]
    maxAge: 10m
```

```bash
kubectl apply -f cors.yaml
sleep 3
kubectl -n todo get securitypolicy cors -o yaml | sed -n '/conditions:/,/type:/p'
curl -s -o /dev/null -w "%{http_code}\n" -X OPTIONS -H "$O" -H "Access-Control-Request-Method: GET" -H "Access-Control-Request-Headers: x-api-key" todo.localhost:8080/api/todos
kubectl delete -f cors.yaml
```

**이렇게 나오면 성공**(안 붙는 것이 정상): 상태가 `Conflicted`, 미리 묻기는 그대로 `401`. 확인했으면 지웁니다

```
securitypolicy.gateway.envoyproxy.io/cors created
    conditions:
    - lastTransitionTime: "2026-10-22T13:54:09Z"
      message: Unable to target HTTPRoute todo-api, another SecurityPolicy has already
        attached to it
      observedGeneration: 1
      reason: Conflicted
      status: "False"
      type: Accepted
401
securitypolicy.gateway.envoyproxy.io "cors" deleted from todo namespace
```

- HTTPRoute `todo-api`에는 실습 3의 `apikey`가 먼저 붙어 있습니다. **HTTPRoute 하나에 SecurityPolicy는 하나**만 붙습니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 상태가 `Accepted`·`True` | 실습 3의 `apikey`가 없음(지움) | `kubectl -n todo get securitypolicy` — 실습 3의 2단계 |
| sed 결과가 빈 줄 | apply 직후 | 3초 뒤 다시 |

</details>

## 3단계. 키 정책에 CORS 더하기

실습 3의 `apikey.yaml` 맨 아래, `apiKeyAuth:`와 같은 칸에 `cors:`를 더합니다.

```bash
nano apikey.yaml
```

```yaml
  apiKeyAuth:
    credentialRefs:
    - name: api-keys
    extractFrom:
    - headers: ["x-api-key"]
    forwardClientIDHeader: x-client-id
    sanitize: true
  cors:
    allowOrigins: ["http://partner.localhost:8080"]
    allowMethods: ["GET", "POST"]
    allowHeaders: ["x-api-key", "content-type"]
    maxAge: 10m
```

```bash
kubectl apply -f apikey.yaml
kubectl -n todo get securitypolicy apikey -o jsonpath='{.status.ancestors[0].conditions[0].reason}'; echo
```

**이렇게 나오면 성공**

```
secret/api-keys unchanged
securitypolicy.gateway.envoyproxy.io/apikey configured
Accepted
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `unknown field "cors"` 또는 `spec.apiKeyAuth.cors` | `cors:`를 `apiKeyAuth:` 안쪽 칸에 넣음 | `cors:`는 `apiKeyAuth:`와 같은 칸(스페이스 2칸) |
| `Invalid value: "10"` | `maxAge`에 단위 없음 | `10m` |
| reason이 `Accepted`인데 4단계가 그대로 | apply 직후 | 5초 뒤 4단계 |

</details>

## 4단계. 미리 묻기와 실제 요청 다시

```bash
curl -s -D - -o /dev/null -X OPTIONS -H "$O" -H "Access-Control-Request-Method: GET" -H "Access-Control-Request-Headers: x-api-key" todo.localhost:8080/api/todos
curl -s -D - -H "$O" -H "x-api-key: key-bbb" todo.localhost:8080/api/todos | grep -i "^HTTP\|access-control\|모니터링"
```

**이렇게 나오면 성공**: 미리 묻기가 `200`이고 허락 헤더 넷. 실제 요청에도 `access-control-allow-origin`

```
HTTP/1.1 200 OK
access-control-allow-origin: http://partner.localhost:8080
access-control-allow-methods: GET, POST
access-control-allow-headers: x-api-key, content-type
access-control-max-age: 600
date: Thu, 22 Oct 2026 13:54:26 GMT
content-length: 0

HTTP/1.1 200 OK
access-control-allow-origin: http://partner.localhost:8080
[{"id":1,"title":"모니터링 공부"}]
```

| | 1단계(CORS 없음) | 4단계(CORS 있음) |
|---|---|---|
| 미리 묻기(`OPTIONS`, 키 없음) | `401` — 브라우저는 여기서 멈춤 | `200` + 허락 헤더 넷 |
| 실제 GET | 허락 표시 없음 → 브라우저가 결과를 안 넘김 | `access-control-allow-origin` → 화면이 읽음 |

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 미리 묻기가 여전히 `401` | 반영 전, 또는 `cors:`가 다른 정책에 들어감 | 5초 뒤, 3단계 reason |
| `access-control-allow-origin`이 없음 | `$O`의 출처와 `allowOrigins`가 한 글자라도 다름(끝 `/`, 포트) | `http://partner.localhost:8080` 그대로 |
| 둘째가 `429` | 분당 5번(team-b) | 1분 기다림 |

</details>

## 5단계. 허락 안 한 출처 — 서버는 답한다

```bash
E="Origin: http://evil.localhost:8080"
curl -s -D - -H "$E" -H "x-api-key: key-bbb" todo.localhost:8080/api/todos | grep -i "^HTTP\|access-control\|모니터링"
curl -s -D - -o /dev/null -X OPTIONS -H "$E" -H "Access-Control-Request-Method: GET" -H "Access-Control-Request-Headers: x-api-key" todo.localhost:8080/api/todos | grep -i "^HTTP\|access-control"
curl -s -w " %{http_code}\n" -H "$O" todo.localhost:8080/api/todos
```

**이 명령은**: 첫째 = 허락 안 한 출처에서 키를 넣어 GET. 둘째 = 같은 출처의 미리 묻기. 셋째 = 허락한 출처지만 **키 없이** GET.

**이렇게 나오면 성공**: 허락 안 한 출처도 데이터는 `200`으로 옴 — 허락 표시(`access-control-allow-origin`)만 없음. 허락한 출처라도 키가 없으면 `401`

```
HTTP/1.1 200 OK
[{"id":1,"title":"모니터링 공부"}]
HTTP/1.1 200 OK
access-control-allow-methods: GET, POST
access-control-allow-headers: x-api-key, content-type
access-control-max-age: 600
Client authentication failed. 401
```

| | 허락한 출처 | 허락 안 한 출처 |
|---|---|---|
| 서버 응답(curl) | `200` + 데이터 + 허락 표시 | `200` + 데이터, 허락 표시 없음 |
| 브라우저 화면 | 읽음 | 못 읽음(CORS 오류) |
| 키 없이 | `401` | `401` |

- **CORS는 브라우저가 지키는 규칙**입니다. 서버는 누구에게나 답하고, 브라우저가 허락 표시를 보고 화면에 넘길지 정합니다. curl은 그런 규칙이 없습니다. 누가 부를 수 있는지는 **키(실습 3)·토큰(실습 4)**이 지킵니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 첫째에 `access-control-allow-origin`이 있음 | `allowOrigins`를 `"*"`로 씀 | 3단계 파일 그대로 |
| 첫째가 `429` | 분당 5번(team-b) | 1분 기다림 |

</details>

## 끝났는지 확인
- ☐ 1단계 미리 묻기 `401`, GET에 허락 표시 없음
- ☐ 2단계 따로 만든 `cors` 정책이 `Conflicted` — 지움
- ☐ 3단계 `apikey` 정책 `Accepted`
- ☐ 4단계 미리 묻기 `200` + 허락 헤더 넷, GET에 `access-control-allow-origin: http://partner.localhost:8080`
- ☐ 5단계 허락 안 한 출처도 데이터 `200`(허락 표시 없음), 키 없이 `401`

## 정리
- `apikey.yaml`(CORS 포함)은 둡니다. 2단계의 `cors.yaml`은 지웠습니다

## 확인 문제
1. 파트너 화면이 할 일을 지우려고(`DELETE /api/todos/1`) 미리 묻기를 보내면 브라우저는 진짜 요청을 보낼까요? `Access-Control-Request-Method: DELETE`로 미리 묻기를 보내 응답의 `access-control-allow-methods`를 확인해 보세요.
2. 파트너가 화면 주소를 `https://partner.localhost:8443`으로 바꿨습니다. 지금 정책 그대로면 허락될까요? 왜 그런가요?
