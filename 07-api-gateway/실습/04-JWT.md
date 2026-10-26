[← 실습 3](./03-API-키.md) · [목차](../API-Gateway-실습.md) · [실습 5 →](./05-속도-제한과-게이트웨이-지표.md)

# 실습 4. JWT

**무엇을 하나요**: "내 정보" 주소 `/api/me`를 따로 떼어 **JWT 검사**를 붙입니다. 사람(로그인한 사용자)은 키 대신 로그인 서버가 서명해 준 토큰을 보냅니다. 토큰 내용을 직접 열어 보고, 서명이 맞는 토큰만 통과하는 것과 토큰 안의 이름이 헤더로 앱에 넘어가는 것을 봅니다. 먼저 정책 없이 이름을 꾸며 보내거나 내용을 바꿔 친 토큰도 그대로 통과하는 것을 봅니다. (교안 04장)

**필요한 것**: 실습 2의 v2(`/api/me`), 실습 3의 키 정책.

> **바로 가기** · [1. 토큰 열어 보기](#1단계-토큰-열어-보기) · [2. 공개 키를 ConfigMap으로](#2단계-공개-키를-configmap으로) · [3. /api/me만 떼어 내기 — 정책 없이](#3단계-apime만-떼어-내기--정책-없이) · [4. JWT 정책 붙이기](#4단계-jwt-정책-붙이기) · [5. 토큰 없이, 가짜로, 진짜로](#5단계-토큰-없이-가짜로-진짜로) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 토큰 열어 보기

```bash
cd ~/apigw
TOK=$(cat ~/ktcloud-cloud-native-lab/lab/api-gateway/jwt/test.jwt)
cut -d. -f1 <<<"$TOK" | base64 -d 2>/dev/null; echo
cut -d. -f2 <<<"$TOK" | base64 -d 2>/dev/null; echo
```

**이 명령은**: 시험용 토큰을 변수 `TOK`에 넣고, 점(`.`)으로 나눈 첫째(헤더)와 둘째(내용) 부분을 base64로 풀어 봄.

**이렇게 나오면 성공**

```
{"alg":"RS256","typ":"JWT"}
{"sub":"1234567890","name":"John Doe","admin":true,"iat":1516239022}
```

- JWT = `헤더.내용.서명`. 내용은 **암호화가 아니라** base64 — 누구나 읽을 수 있습니다. 서명은 내용을 바꾸지 못하게 막는 것입니다
- 그래서 토큰 안에 비밀번호 같은 것은 넣지 않습니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `cat: …/test.jwt: No such file or directory` | 실습 1의 `git pull`을 안 함 | 실습 1의 1단계 |
| 아무것도 안 나옴 | `TOK=` 줄의 `$(`·`)` 빠짐 | `echo $TOK`에 점 두 개로 나뉜 긴 글자가 보이는지 |

</details>

## 2단계. 공개 키를 ConfigMap으로

```bash
kubectl -n todo create configmap jwks --from-file=jwks=$HOME/ktcloud-cloud-native-lab/lab/api-gateway/jwt/jwks.json
```

**이 명령은**: 서명을 확인할 **공개 키 목록(JWKS)** 을 ConfigMap `jwks`로 넣음. 서명용 개인 키는 토큰을 만드는 로그인 서버만 가집니다. 게이트웨이는 공개 키로 확인만 합니다.

**이렇게 나오면 성공**: `configmap/jwks created`

## 3단계. /api/me만 떼어 내기 — 정책 없이

`/api/me`만 받는 HTTPRoute를 하나 더 만듭니다. 아직 정책은 없습니다.

```bash
nano me-jwt.yaml
```

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: todo-me
  namespace: todo
spec:
  parentRefs:
  - name: front
    namespace: gateway
  hostnames: ["todo.localhost"]
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api/me
    backendRefs:
    - name: api-v2
      port: 3000
```

```bash
kubectl apply -f me-jwt.yaml
curl -s todo.localhost:8080/api/me; echo
curl -s -H "x-user-name: Kim Hacker" todo.localhost:8080/api/me; echo
curl -s -o /dev/null -w "%{http_code}\n" todo.localhost:8080/api/todos
```

**이렇게 나오면 성공**: 키 없이도 `/api/me`가 열리고, 꾸민 이름을 앱이 믿음. `/api/todos`는 여전히 키가 필요(401)

```
httproute.gateway.networking.k8s.io/todo-me created
{"version":2,"gateway":null,"client":null,"user":null,"apiKey":null}
{"version":2,"gateway":null,"client":null,"user":"Kim Hacker","apiKey":null}
401
```

- `/api/me`가 `/api`보다 긴 경로라 새 HTTPRoute `todo-me`가 받습니다. 실습 3의 키 정책은 `todo-api`에 붙어 있어 여기에는 **안 따라옵니다**(`"gateway":null`인 것도 같은 이유 — 실습 2의 헤더 손보기도 `todo-api`에 있음)

이번에는 토큰의 **내용만** 바꿔 친 가짜를 만들어 보냅니다.

```bash
H=$(cut -d. -f1 <<<"$TOK"); S=$(cut -d. -f3 <<<"$TOK")
P=$(echo -n '{"sub":"1234567890","name":"Kim Hacker"}' | base64 -w0 | tr '+/' '-_' | tr -d '=')
FAKE=$H.$P.$S
cut -d. -f2 <<<"$FAKE" | base64 -d 2>/dev/null; echo
curl -s -w " %{http_code}\n" -H "Authorization: Bearer $FAKE" todo.localhost:8080/api/me
```

**이 명령은**: 진짜 토큰의 헤더(`H`)와 서명(`S`)은 그대로 두고, 가운데 내용만 이름이 `Kim Hacker`인 것으로 바꿔 끼운 토큰 `FAKE`를 만듦(`tr`은 base64 글자를 JWT가 쓰는 글자로 바꾸는 것). 그 내용을 풀어 보고, 그 토큰으로 부름.

**이렇게 나오면 성공**

```
{"sub":"1234567890","name":"Kim Hacker"}
{"version":2,"gateway":null,"client":null,"user":null,"apiKey":null} 200
```

- 아무도 서명을 확인하지 않으니 바꿔 친 토큰도 통과합니다. 앱이 토큰 내용을 직접 읽어 이름을 쓴다면 `Kim Hacker`로 믿게 됩니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `/api/me`가 `Client authentication failed.` | `value: /api/me` 오타로 `todo-api`(키)가 받음 | `cat me-jwt.yaml` |
| `FAKE` 내용이 빈 줄 | 새 터미널이라 `TOK`가 빔 | 1단계 `TOK=` 줄부터 |

</details>

## 4단계. JWT 정책 붙이기

같은 파일 아래에 `---`와 SecurityPolicy를 더합니다.

```bash
nano me-jwt.yaml
```

파일 끝에 다음을 붙여 넣습니다.

```yaml
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: jwt
  namespace: todo
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: todo-me
  jwt:
    providers:
    - name: example
      localJWKS:
        type: ValueRef
        valueRef:
          group: ""
          kind: ConfigMap
          name: jwks
      claimToHeaders:
      - claim: name
        header: x-user-name
```

| 부분 | 뜻 |
|---|---|
| `targetRefs:` → `todo-me` | `/api/me`에만 붙임 |
| `localJWKS` → ConfigMap `jwks` | 2단계의 공개 키로 서명 확인 |
| `claimToHeaders` | 확인된 토큰의 `name` 값을 `x-user-name` 헤더로 앱에 넘김 |

```bash
kubectl apply -f me-jwt.yaml
kubectl -n todo get securitypolicy jwt -o jsonpath='{.status.ancestors[0].conditions[0].reason}'; echo
```

**이렇게 나오면 성공**

```
httproute.gateway.networking.k8s.io/todo-me configured
securitypolicy.gateway.envoyproxy.io/jwt created
Accepted
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| reason이 빈 줄 | `targetRefs` 이름 오타 | `name: todo-me` |
| `group: ""` 줄에서 오류 | 따옴표가 빠짐 | `group: ""` 그대로 |

</details>

## 5단계. 토큰 없이, 가짜로, 진짜로

```bash
curl -s -w " %{http_code}\n" todo.localhost:8080/api/me
curl -s -w " %{http_code}\n" -H "Authorization: Bearer a.b.c" todo.localhost:8080/api/me
curl -s -w " %{http_code}\n" -H "Authorization: Bearer $FAKE" todo.localhost:8080/api/me
curl -s -w " %{http_code}\n" -H "Authorization: Bearer $TOK" todo.localhost:8080/api/me
curl -s -w " %{http_code}\n" -H "Authorization: Bearer $TOK" -H "x-user-name: Kim Hacker" todo.localhost:8080/api/me
```

**이렇게 나오면 성공**

```
Jwt is missing 401
Jwt header is an invalid Base64url encoded 401
Jwt verification fails 401
{"version":2,"gateway":null,"client":null,"user":"John Doe","apiKey":null} 200
{"version":2,"gateway":null,"client":null,"user":"John Doe","apiKey":null} 200
```

| 요청 | 정책 전 (3단계) | 정책 후 |
|---|---|---|
| 토큰 없음 | `200` | `401` `Jwt is missing` |
| 내용을 바꿔 친 토큰 | `200` | `401` `Jwt verification fails` — 서명이 안 맞음 |
| 진짜 토큰 | — | `200`, 앱이 받은 `user`는 토큰 안의 `John Doe` |
| 이름 헤더를 꾸밈 | 앱이 믿음(`Kim Hacker`) | 토큰 값으로 바뀜(`John Doe`) |

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 진짜 토큰도 `Jwt is missing` | 새 터미널이라 `$TOK`가 빔 | 1단계 `TOK=` 줄 |
| 진짜 토큰이 `Jwt verification fails` | ConfigMap 키 이름이 `jwks`가 아님 | `kubectl -n todo get cm jwks -o jsonpath='{.data}' \| head -c 30` → `{"jwks":`로 시작해야 함. 아니면 지우고 2단계 |
| 첫째가 `200` | 정책 적용 전 | 5초 뒤 다시 |

</details>

## 끝났는지 확인
- ☐ 토큰 내용(`John Doe`)을 풀어 봄
- ☐ 정책 전 꾸민 이름·바꿔 친 토큰이 `200`
- ☐ 정책 후 토큰 없음·`a.b.c`·가짜 모두 `401`, 진짜는 `200` + `"user":"John Doe"`
- ☐ 진짜 토큰 + 꾸민 이름 → 앱은 `John Doe`

## 정리
- 모두 둡니다. 실습 5는 `/api/todos`(키)를 씁니다

## 확인 문제
1. 진짜 토큰의 **끝에 글자 하나**를 더해(`${TOK}x`) 부르면 무엇이 나올까요? 왜 그런가요?
2. (생각해 보기) 이 예제 토큰에는 만료 시각(`exp`)이 없습니다. 이 토큰이 유출되면 어떻게 될까요? 실습 3의 API 키와 비교해 보세요.
