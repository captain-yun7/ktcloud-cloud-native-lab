[← 실습 7](./07-CORS.md) · [목차](../API-Gateway-실습.md) · [미션 →](../미션/01-Online-Boutique-앞문.md)

# 실습 8. HTTPS

**무엇을 하나요**: 지금 입구 8080은 **HTTP(평문)**라서, 요청에 실린 API 키가 오가는 길에서 글자 그대로 보입니다. 먼저 그것을 패킷을 떠서 직접 봅니다. 그다음 인증서를 만들어 입구에 **HTTPS 리스너**를 더하고(입구에서 암호를 풀어 앱에는 그대로 넘기는 **TLS 종료**), 같은 요청이 암호문이 되어 키가 안 보이는 것을 확인합니다. 마지막에 HTTP로 온 손님을 HTTPS 주소로 **넘겨 보내는(리다이렉트)** 규칙을 붙입니다. (교안 07장)

**필요한 것**: 실습 1의 입구 `front`(`~/apigw/gateway.yaml`), 실습 1~6의 HTTPRoute(`todo`, `todo-api`, `todo-me`, `flaky`).

> **바로 가기** · [1. HTTP로 보내면 — 키가 그대로 보임](#1단계-http로-보내면--키가-그대로-보임) · [2. 인증서 만들기](#2단계-인증서-만들기) · [3. HTTPS 리스너 더하고 8443으로 부르기](#3단계-https-리스너-더하고-8443으로-부르기) · [4. HTTPS로 보내면 — 키가 안 보임](#4단계-https로-보내면--키가-안-보임) · [5. HTTP는 HTTPS로 넘겨 보내기](#5단계-http는-https로-넘겨-보내기) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. HTTP로 보내면 — 키가 그대로 보임

VM 안에서 8080으로 가는 패킷을 하나 떠서(tcpdump), 그 안에 API 키가 보이는지 봅니다.

```bash
cd ~/apigw
(sleep 2; curl -s -o /dev/null -H "x-api-key: key-bbb" todo.localhost:8080/api/todos) &
sudo timeout 5 tcpdump -lni lo -A -c 1 'tcp dst port 8080 and greater 120' 2>/dev/null | grep -a "x-api-key"
```

**이 명령은**: 첫 줄 = 2초 뒤에 키를 넣어 API를 부르도록 뒤에서(`&`) 걸어 둠. 둘째 줄 = 그동안 VM 안의 길(`lo`)에서 8080으로 가는 데이터 패킷 하나를 떠서 글자로(`-A`) 보고, 그중 `x-api-key` 줄만.

**이렇게 나오면 성공**(보이는 것이 문제): 키가 글자 그대로

```
x-api-key: key-bbb
```

- 같은 길 위의 누구든(공유 와이파이, 중간 장비) 이 키를 보고 team-b인 척 부를 수 있습니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `sudo: a password is required` | sudo 비밀번호를 묻는 VM | 질문합니다 |
| 아무것도 안 나옴 | 5초 안에 요청이 안 감(첫 줄을 안 붙여 넣음) | 두 줄을 이어서 다시 |
| 결과가 `[1]+ Done …` 줄만 | 뒤에서 돌던 curl이 끝났다는 알림 — 정상 | 그 위 줄을 봄 |

</details>

## 2단계. 인증서 만들기

수업용 발급 기관(CA)을 하나 만들고, 그 CA로 `todo.localhost`의 인증서를 만듭니다. 인증서와 개인 키는 입구가 읽을 수 있게 **Secret**에 넣습니다.

```bash
mkdir -p ~/apigw/tls && cd ~/apigw/tls
openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj "/CN=lab-ca" -keyout ca.key -out ca.crt 2>/dev/null
openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj "/CN=todo.localhost" -addext "subjectAltName=DNS:todo.localhost" -CA ca.crt -CAkey ca.key -keyout todo.key -out todo.crt 2>/dev/null
ls
openssl x509 -in todo.crt -noout -subject -issuer -ext subjectAltName
openssl verify -CAfile ca.crt todo.crt
kubectl -n gateway create secret tls todo-tls --cert=todo.crt --key=todo.key
cd ~/apigw
```

**이 명령은**: 셋째 줄 = CA(이름 `lab-ca`)의 개인 키와 인증서. 넷째 줄 = `todo.localhost`의 개인 키와 인증서를 만들고 CA로 서명. 그다음 = 파일 목록, 인증서의 이름·발급자, CA로 확인, 입구 네임스페이스(`gateway`)에 TLS Secret `todo-tls`로 넣기.

**이렇게 나오면 성공**

```
ca.crt  ca.key  todo.crt  todo.key
subject=CN = todo.localhost
issuer=CN = lab-ca
X509v3 Subject Alternative Name: 
    DNS:todo.localhost
todo.crt: OK
secret/todo-tls created
```

| 파일 | 뜻 | 누가 갖나 |
|---|---|---|
| `ca.key` | CA의 개인 키 — 인증서에 서명 | 발급 기관만(**절대 나눠 주지 않음**) |
| `ca.crt` | CA의 인증서(공개) | 손님(curl의 `--cacert`) |
| `todo.key` | `todo.localhost`의 개인 키 | 입구만(Secret) |
| `todo.crt` | `todo.localhost`의 인증서 — CA가 서명 | 입구(Secret)가 손님에게 보여 줌 |

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `req: Unrecognized flag CA` | 오래된 openssl(1.1) | `openssl version`을 적어 질문합니다(수업 VM은 3.0) |
| `todo.crt: OK`가 아니고 `unable to get local issuer certificate` | 넷째 줄의 `-CA ca.crt -CAkey ca.key`를 빠뜨림 | 넷째 줄 다시 |
| `error: failed to create secret secrets "todo-tls" already exists` | 이미 만듦 | 그대로 진행(다시 만들려면 `kubectl -n gateway delete secret todo-tls` 후) |

</details>

## 3단계. HTTPS 리스너 더하고 8443으로 부르기

**가. 리스너 더하기** — 실습 1의 `gateway.yaml` 맨 아래, `- name: http` 리스너와 같은 칸에 HTTPS 리스너를 더합니다.

```bash
nano gateway.yaml
```

```yaml
  - name: https
    protocol: HTTPS
    port: 443
    hostname: todo.localhost
    tls:
      mode: Terminate
      certificateRefs:
      - name: todo-tls
    allowedRoutes:
      namespaces:
        from: All
```

| 줄 | 뜻 |
|---|---|
| `protocol: HTTPS` · `port: 443` | 암호화된 요청을 받는 창구(Envoy 안쪽 번호) |
| `hostname: todo.localhost` | 이 이름으로 온 요청만 — 이름마다 다른 인증서를 쓸 수 있음(미션) |
| `tls.mode: Terminate` | 입구에서 암호를 풀고 앱에는 그대로 넘김 |
| `certificateRefs: - name: todo-tls` | 2단계의 Secret |

```bash
kubectl apply -f gateway.yaml
kubectl -n gateway wait gateway/front --for=condition=Programmed --timeout=60s
kubectl -n gateway get gateway front -o jsonpath='{range .status.listeners[*]}{.name} {.attachedRoutes}{"\n"}{end}'
kubectl -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=front
```

**이렇게 나오면 성공**: 리스너 `https`에 경로 4개가 붙음, Envoy Service에 `443` 포트가 생김

```
gateway.gateway.networking.k8s.io/front configured
gateway.gateway.networking.k8s.io/front condition met
http 4
https 4
NAME                           TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
envoy-gateway-front-19c8d80b   NodePort   10.96.232.153   <none>        80:30080/TCP,443:30152/TCP   13m
```

**나. 8443으로 잇기** — VM의 8443을 Envoy의 443에 잇습니다. 연결이 끊겨도 1초 뒤 다시 잇도록 되풀이해 둡니다(이 터미널을 닫으면 끝납니다).

```bash
SVC=$(kubectl -n envoy-gateway-system get svc -l gateway.envoyproxy.io/owning-gateway-name=front -o name)
while true; do kubectl -n envoy-gateway-system port-forward $SVC 8443:443; sleep 1; done > /dev/null 2>&1 &
sleep 3
curl -sS https://todo.localhost:8443/
curl -s --cacert tls/ca.crt -H "x-api-key: key-bbb" https://todo.localhost:8443/api/health; echo
curl -s --cacert tls/ca.crt -o /dev/null -w "%{http_code}\n" https://todo.localhost:8443/
curl -sv --cacert tls/ca.crt -o /dev/null https://todo.localhost:8443/ 2>&1 | grep -E "SSL connection|subject:|issuer:"
```

**이 명령은**: Envoy Service 이름을 `SVC`에 담고, VM 8443 → Service 443 잇기를 뒤에서(`&`) 되풀이(`while true`). 그다음 = CA를 안 알려 주고 부르기 · CA를 알려 주고(`--cacert`) API와 화면 부르기 · 주고받은 인증서 정보(`-v`) 중 세 줄.

**이렇게 나오면 성공**: CA 없이는 `(60)` 오류, CA를 알려 주면 `200`. 앱은 하나도 안 고쳤는데 HTTPS로 답함

```
curl: (60) SSL certificate problem: unable to get local issuer certificate
More details here: https://curl.se/docs/sslcerts.html
...
{"ok":true,"version":2}
200
* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384 / X25519 / RSASSA-PSS
*  subject: CN=todo.localhost
*  issuer: CN=lab-ca
```

| | `https://todo.localhost:8443` |
|---|---|
| `--cacert` 없이 | `curl: (60)` — 이 인증서를 서명한 `lab-ca`를 curl이 모름 |
| `--cacert tls/ca.crt` | `200` — `lab-ca`를 믿으니 `todo.localhost` 인증서도 믿음 |
| 앱 | 그대로(평문으로 받음) |

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `curl: (7) Failed to connect to todo.localhost port 8443` | 잇기가 안 떠 있음(터미널을 닫음), 또는 방금 끊겨 다시 잇는 중 | 3초 뒤 다시. 그래도면 나의 첫 세 줄 |
| `curl: (35) … SSL_ERROR_SYSCALL` | 리스너가 아직 준비 전, 또는 `hostname` 오타 | 10초 뒤, `hostname: todo.localhost` |
| `curl: (60) … certificate subject name … does not match` | 인증서 이름 칸(SAN) 없음·오타 | 2단계 넷째 줄 다시 → Secret 지우고 다시 만듦 |
| `https 0` | 리스너가 Secret을 못 찾음 | `kubectl -n gateway get gateway front -o yaml`의 리스너 status `ResolvedRefs`, Secret 네임스페이스 `gateway` |
| `curl: (60)`이 `--cacert`를 줘도 | 경로 오타(`~/apigw`에서 `tls/ca.crt`) | `pwd`가 `~/apigw`인지 |

</details>

## 4단계. HTTPS로 보내면 — 키가 안 보임

1단계와 같은 일을 8443(HTTPS)으로 합니다. 이번엔 `x-api-key`가 몇 번 나오는지 셉니다.

```bash
(sleep 2; curl -s -o /dev/null --cacert tls/ca.crt -H "x-api-key: key-bbb" https://todo.localhost:8443/api/todos) &
sudo timeout 6 tcpdump -lni lo -A -c 5 'tcp dst port 8443 and greater 120' 2>/dev/null | grep -ac "x-api-key"
```

**이렇게 나오면 성공**: `0` — 같은 요청인데 패킷 어디에도 키가 글자로 없음

```
0
```

| | 1단계 HTTP(8080) | 4단계 HTTPS(8443) |
|---|---|---|
| 길 위의 패킷 | `x-api-key: key-bbb`가 그대로 | 암호문 — `x-api-key` 0번 |
| 앱이 받는 것 | 같음 | 같음(입구가 풀어서 넘김) |

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `0`인데 정말 패킷을 떴는지 궁금함 | — | `\| grep -ac "x-api-key"`를 `\| head -3`으로 바꿔 보면 `IP6 ::1.… > ::1.8443` 줄과 알아볼 수 없는 글자 |
| `1` | 8443이 아니라 8080으로 부름 | 첫 줄의 주소가 `https://…:8443` |

</details>

## 5단계. HTTP는 HTTPS로 넘겨 보내기

**가. 넘겨 보내기 규칙만 붙여 보기**

```bash
nano todo-redirect.yaml
```

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: todo-redirect
  namespace: todo
spec:
  parentRefs:
  - name: front
    namespace: gateway
    sectionName: http
  hostnames: ["todo.localhost"]
  rules:
  - filters:
    - type: RequestRedirect
      requestRedirect:
        scheme: https
        port: 8443
        statusCode: 301
```

| 줄 | 뜻 |
|---|---|
| `sectionName: http` | 입구의 `http` 창구에만 붙음 |
| `RequestRedirect` | 앱에 보내지 않고 손님에게 "이 주소로 가세요"(`301` + `location`) |
| `scheme: https` · `port: 8443` | 새 주소는 `https://todo.localhost:8443/…`(경로는 그대로) |

```bash
kubectl apply -f todo-redirect.yaml
sleep 3
curl -s -o /dev/null -w "%{http_code}\n" todo.localhost:8080/
kubectl -n todo get httproute todo-redirect -o jsonpath='{range .status.parents[0].conditions[*]}{.type}={.status}{"\n"}{end}'
```

**이렇게 나오면 성공**(안 먹히는 것이 정상): 여전히 `200`, 상태에 `RouteRulesOverlap=True` — 기존 경로들이 아직 `http` 창구에도 붙어 있어 겹치고, 먼저 있던 쪽이 이깁니다

```
httproute.gateway.networking.k8s.io/todo-redirect created
200
Accepted=True
ResolvedRefs=True
RouteRulesOverlap=True
```

**나. 기존 경로를 https 창구로 옮기기** — 실습 1~6에서 만든 todo의 경로 넷을 `sectionName: https`로 바꿉니다.

```bash
for r in todo todo-api todo-me flaky; do
  kubectl -n todo patch httproute $r --type=merge -p '{"spec":{"parentRefs":[{"name":"front","namespace":"gateway","sectionName":"https"}]}}'
done
sleep 3
kubectl -n gateway get gateway front -o jsonpath='{range .status.listeners[*]}{.name} {.attachedRoutes}{"\n"}{end}'
curl -s -D - -o /dev/null todo.localhost:8080/api/health | head -2
curl -sL --cacert tls/ca.crt -w " %{http_code} %{num_redirects}\n" -H "x-api-key: key-bbb" todo.localhost:8080/api/health
curl -s --cacert tls/ca.crt -o /dev/null -w "%{http_code}\n" https://todo.localhost:8443/flaky
```

**이 명령은**: 네 경로의 "붙을 입구"를 `front`의 `https` 창구로 바꿈. 그다음 = 창구별 경로 수, HTTP로 부른 응답의 첫 두 줄, 넘겨 보낸 주소를 따라가서(`-L`) 받은 결과와 넘겨 보낸 횟수, flaky도 https로.

**이렇게 나오면 성공**: HTTP는 `301`과 새 주소, `-L`로 따라가면 `200`(넘겨 보내기 1번)

```
httproute.gateway.networking.k8s.io/todo patched
httproute.gateway.networking.k8s.io/todo-api patched
httproute.gateway.networking.k8s.io/todo-me patched
httproute.gateway.networking.k8s.io/flaky patched
http 1
https 4
HTTP/1.1 301 Moved Permanently
location: https://todo.localhost:8443/api/health
{"ok":true,"version":2} 200 1
200
```

| | 가. 넘겨 보내기만 | 나. 경로를 https로 옮긴 뒤 |
|---|---|---|
| `http` 창구 | 기존 경로 4 + 넘겨 보내기(겹침) | 넘겨 보내기 1 |
| `https` 창구 | 기존 경로 4 | 기존 경로 4 |
| `todo.localhost:8080/…` | `200`(평문 그대로) | `301` → `https://todo.localhost:8443/…` |

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 나에서도 `200` | 네 경로 중 하나라도 `http`에 남음 | `kubectl get httproute -A -o custom-columns=NAME:.metadata.name,SECTION:.spec.parentRefs[0].sectionName` — todo 쪽이 모두 `https`(redirect만 `http`) |
| `-L`이 `curl: (60)` | `--cacert` 빠짐 | 그대로 |
| `-L`이 `curl: (7) … port 8443` | 8443 잇기가 끊김 | 3초 뒤 다시, 그래도면 3단계 나의 첫 세 줄 |
| `-L`이 `401` | 키 헤더 빠짐 | `-H "x-api-key: key-bbb"` |
| `Error from server (NotFound): httproutes … "flaky" not found` | 실습 6을 건너뜀 | 그 줄만 무시 |

</details>

## 끝났는지 확인
- ☐ 1단계 tcpdump에 `x-api-key: key-bbb`
- ☐ 2단계 `todo.crt: OK`, Secret `todo-tls`
- ☐ 3단계 CA 없이 `curl: (60)`, `--cacert`로 `200`, `issuer: CN=lab-ca`
- ☐ 4단계 HTTPS 패킷에서 `x-api-key` `0`번
- ☐ 5단계 `todo.localhost:8080` → `301` → `-L`로 `200`

## 정리
- 모두 둡니다. 미션 과제 5가 같은 CA(`~/apigw/tls/ca.key`)로 쇼핑몰 인증서를 만들고, 같은 port-forward(8443)를 씁니다
- 이제 `todo.localhost:8080/…`는 모두 `301`입니다. 앞 실습의 명령을 다시 하려면 `curl -sL --cacert ~/apigw/tls/ca.crt …` 또는 주소를 `https://todo.localhost:8443/…`로
- 8443 잇기는 터미널을 닫으면 끝납니다. 새 터미널에서는 3단계 나의 첫 세 줄을 다시

## 확인 문제
1. `curl -s --cacert tls/ca.crt -o /dev/null -w "%{http_code}\n" --resolve shop.localhost:8443:127.0.0.1 https://shop.localhost:8443/`처럼 이름만 `shop.localhost`로 바꿔 8443을 부르면 어떻게 될까요? 왜 그런가요? (힌트: 3단계 리스너의 `hostname`)
2. 2단계의 인증서는 30일짜리입니다. 30일 뒤에는 무슨 일이 생기고, 실서비스에서는 누가 이것을 챙기나요?
