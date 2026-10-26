[← 시작하기 전에](./00-시작하기-전에.md) · [목차](../API-Gateway-실습.md) · [실습 2 →](./02-경로-헤더-가중치.md)

# 실습 1. Envoy Gateway 설치와 첫 경로

**무엇을 하나요**: 클러스터에 API Gateway인 **Envoy Gateway**를 설치하고, 입구(**Gateway**) 하나와 경로 규칙(**HTTPRoute**) 하나를 만들어 `todo.localhost:8080`으로 todo를 엽니다. 먼저 지금은 todo를 바깥에서 부를 길이 없는 것을 보고, 입구만 있고 규칙이 없을 때(404)도 봅니다. 게이트웨이가 남긴 기록(로그)으로 요청 하나가 어디로 갔는지 확인하고, 마지막에 일부러 고장 낸 HTTPRoute의 상태(status)를 읽어 404·500의 원인을 찾습니다. (교안 02장)

**필요한 것**: 모니터링 과목이 끝난 클러스터([시작하기 전에 2](./00-시작하기-전에.md#2-클러스터가-떠-있는지-확인)).

> **바로 가기** · [1. 저장소를 최신으로, 8080 확인](#1단계-저장소를-최신으로-8080-확인) · [2. 입구 없이 — todo를 부를 길이 없음](#2단계-입구-없이--todo를-부를-길이-없음) · [3. Envoy Gateway 설치](#3단계-envoy-gateway-설치) · [4. Gateway만 만들고 불러 보기 — 404](#4단계-gateway만-만들고-불러-보기--404) · [5. HTTPRoute로 todo 열기](#5단계-httproute로-todo-열기) · [6. 브라우저로 열고 게이트웨이 로그 보기](#6단계-브라우저로-열고-게이트웨이-로그-보기) · [7. 고장 난 HTTPRoute 읽기 — 404와 500](#7단계-고장-난-httproute-읽기--404와-500) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 저장소를 최신으로, 8080 확인

```bash
cd ~/ktcloud-cloud-native-lab && git pull && cd lab
docker port lab-control-plane | grep 30080
```

**이 명령은**: 첫 줄 = 강사가 올린 새 파일(`api-gateway/` 폴더, `make envoy-gateway`)을 받고 `lab` 폴더로 들어감. 둘째 줄 = kind 노드의 30080번이 VM의 몇 번에 이어져 있는지 봄.

**이렇게 나오면 성공**: 프롬프트가 `lab@sNN:~/ktcloud-cloud-native-lab/lab$`, 둘째 줄 결과

```
30080/tcp -> 0.0.0.0:8080
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `error: Your local changes … would be overwritten by merge` | 저장소 안 파일을 직접 고침 | `git stash` 후 `git pull` |
| 둘째 줄이 아무것도 안 나옴 | 이 포트 설정이 들어가기 전에 만든 클러스터 | 질문합니다(강사가 임시 방법을 알려 줌) |

</details>

## 2단계. 입구 없이 — todo를 부를 길이 없음

```bash
curl -sS todo.localhost:8080
curl -s -o /dev/null -w "%{http_code}\n" todo.localhost
```

**이 명령은**: 첫 줄 = 이 과목의 입구 8080으로 todo를 부름. 둘째 줄 = 앞 과목의 입구(80, Traefik)로 부르고 상태 코드만 봄.

**이렇게 나오면 성공**(막히는 것이 정상)

```
curl: (56) Recv failure: Connection reset by peer
404
```

- 8080 뒤에는 아직 아무 프로그램도 없습니다. 80의 Traefik은 살아 있지만 `todo.localhost` 규칙(Ingress)이 없어 404입니다
- todo는 클러스터 안에서만(`load` 파드가 1초마다) 불리고 있습니다. 바깥 손님이 들어올 입구를 이번 실습에서 만듭니다

| | Ingress (쿠버네티스 실습 11) | Gateway API + Envoy Gateway (이 과목) |
|---|---|---|
| 이름·경로로 나눠 보내기 | 됨 | 됨 |
| 헤더로 고르기, 비율로 나누기 | 표준에 없음 (컨트롤러마다 annotation) | 표준 필드 (실습 2) |
| 키·토큰 검사, 횟수 제한 | 표준에 없음 | 정책을 붙임 (실습 3~5) |
| 누가 무엇을 적나 | 한 파일에 다 | 입구(운영자)와 경로(앱 팀)를 나눔 |

## 3단계. Envoy Gateway 설치

```bash
make envoy-gateway
kubectl get gatewayclass
```

**이 명령은**: 세 가지를 차례로 설치(약 30초).
1. Gateway API 리소스 종류(CRD)와 Envoy Gateway 정책 종류(SecurityPolicy 등)
2. 컨트롤러 `envoy-gateway` — HTTPRoute 같은 설정을 읽어 Envoy에 전달하는 파드 1개
3. GatewayClass `eg` — "Envoy Gateway로 입구를 만든다". Envoy를 노드의 **30080번**으로 열도록 설정

**이렇게 나오면 성공**: `eg` 줄의 `ACCEPTED`가 `True`

```
NAME                             READY   STATUS      RESTARTS   AGE
eg-gateway-helm-certgen-k4rpw    0/1     Completed   0          17s
envoy-gateway-5f8c9f5b6c-nr5zm   1/1     Running     0          7s
NAME           CONTROLLER                                      ACCEPTED   AGE
eg             gateway.envoyproxy.io/gatewayclass-controller   True       1s
istio          istio.io/gateway-controller                     True       19s
istio-remote   istio.io/unmanaged-gateway                      True       19s
```

- `istio`·`istio-remote`는 Istio가 만든 것입니다. Gateway API는 **규격**이고 그 규격을 읽는 프로그램(구현체)이 여럿입니다. 이 과목은 `eg`만 씁니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `make: *** No rule to make target 'envoy-gateway'.` | `lab` 폴더 밖이거나 `git pull`을 안 함 | 1단계 다시 |
| `eg`의 `ACCEPTED`가 `Unknown` | 컨트롤러가 아직 뜨는 중 | 10초 뒤 `kubectl get gatewayclass` |
| `provided port is already allocated` | 쿠버네티스 실습 6의 `hello-ext`(30080)가 남아 있음 | `kubectl delete svc hello-ext` 후 다시 |

</details>

## 4단계. Gateway만 만들고 불러 보기 — 404

```bash
mkdir -p ~/apigw && cd ~/apigw
kubectl create ns gateway
nano gateway.yaml
```

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: front
  namespace: gateway
spec:
  gatewayClassName: eg
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: All          # 다른 네임스페이스(todo, shop)의 HTTPRoute도 붙을 수 있게
```

| 줄 | 뜻 |
|---|---|
| `gatewayClassName: eg` | 3단계의 Envoy Gateway로 만듦 |
| `listeners:` 아래 `port: 80` | 이 입구가 받는 포트(Envoy 안쪽 번호. 바깥에서는 VM 8080으로 들어옴) |
| `allowedRoutes.namespaces.from: All` | 다른 네임스페이스의 HTTPRoute도 이 입구에 붙을 수 있음 |

```bash
kubectl apply -f gateway.yaml
kubectl -n gateway wait gateway/front --for=condition=Programmed --timeout=120s
kubectl -n envoy-gateway-system get pods
curl -s -D - todo.localhost:8080
```

**이 명령은**: 입구를 만들고, 준비될 때까지(`Programmed`) 기다린 뒤, Envoy 파드를 보고, 2단계와 같은 주소를 응답 헤더까지(`-D -`) 부름.

**이렇게 나오면 성공**: 파드가 하나 더(`envoy-gateway-front-…`, `2/2`), 그리고 404 — 이번에는 **Envoy가** 답함

```
gateway.gateway.networking.k8s.io/front condition met
NAME                                            READY   STATUS    RESTARTS   AGE
envoy-gateway-5f8c9f5b6c-nr5zm                  1/1     Running   0          69s
envoy-gateway-front-19c8d80b-7c7b4555d6-c75qv   2/2     Running   0          11s
HTTP/1.1 404 Not Found
date: Sat, 17 Oct 2026 14:50:49 GMT
content-length: 0
```

- 입구는 열렸지만 `todo.localhost`를 어느 Service로 보낼지 아무도 정하지 않았습니다. Gateway 파일에는 포트와 "어느 네임스페이스의 경로를 받을지"만 있고 경로는 없습니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `no matches for kind "Gateway"` | 3단계를 안 함 | 3단계 |
| `timed out waiting for the condition` | Envoy 파드가 이미지를 받는 중 | `kubectl -n envoy-gateway-system get pods`가 `2/2`가 될 때까지 기다림 |
| 여전히 `Connection reset by peer` | Envoy 파드가 아직 안 뜸, 또는 8080 매핑 없음 | 20초 뒤 다시, 1단계 둘째 줄 |

</details>

## 5단계. HTTPRoute로 todo 열기

```bash
nano todo-route.yaml
```

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: todo
  namespace: todo
spec:
  parentRefs:
  - name: front
    namespace: gateway
  hostnames: ["todo.localhost"]
  rules:
  - backendRefs:
    - name: web
      port: 80
```

| 줄 | 뜻 |
|---|---|
| `namespace: todo` | 앱과 같은 네임스페이스 — 앱 팀이 자기 자리에서 씀 |
| `parentRefs:` | 어느 입구에 붙을지 — `gateway` 네임스페이스의 `front` |
| `hostnames:` | 이 이름으로 온 요청만 받음 |
| `backendRefs:` | 보낼 곳 — Service `web` 80번(todo 화면, nginx) |

```bash
kubectl apply -f todo-route.yaml
kubectl -n todo get httproute todo -o jsonpath='{range .status.parents[0].conditions[*]}{.type}={.status}{"\n"}{end}'
curl -s todo.localhost:8080 | head -5
curl -s todo.localhost:8080/api/todos; echo
```

**이 명령은**: 경로 규칙을 만들고, 입구가 받아들였는지(`Accepted`)와 보낼 Service를 찾았는지(`ResolvedRefs`) 보고, todo 화면과 할 일 목록을 부름.

**이렇게 나오면 성공**

```
httproute.gateway.networking.k8s.io/todo created
Accepted=True
ResolvedRefs=True
<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <title>todo</title>
[{"id":1,"title":"모니터링 공부"},{"id":2,"title":"지표 달기"}]
```

- 할 일 목록은 사람마다 다릅니다(모니터링 과목에서 넣은 것)
- `/api/todos`도 web(nginx)이 받아 안에서 api로 넘겼습니다. 실습 2에서 이 길을 바꿉니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| jsonpath 결과가 빈 줄 | 아직 처리 전, 또는 `parentRefs`의 이름·네임스페이스 오타 | 5초 뒤 다시, 그래도 없으면 `kubectl -n todo describe httproute todo`의 Status |
| `ResolvedRefs=False` | `backendRefs`의 Service 이름·포트 오타 | `kubectl -n todo get svc` |
| curl이 `404` | `hostnames` 오타 | `todo.localhost` |
| curl이 `503`, 본문 `upstream connect error … connection termination` | todo에 Istio mTLS STRICT가 걸려 있음 | 질문합니다 |

</details>

## 6단계. 브라우저로 열고 게이트웨이 로그 보기

**가. 브라우저** — VS Code 아래 **PORTS** 탭에서 `8080`을 전달하고, 브라우저에서 `http://todo.localhost:<포트>`를 엽니다. 할 일을 하나 추가해 봅니다.

**나. 게이트웨이 로그** — 요청 하나가 어디로 갔는지 Envoy가 한 줄씩 남깁니다.

```bash
curl -s -o /dev/null todo.localhost:8080/api/todos
sleep 10
kubectl -n envoy-gateway-system logs -l gateway.envoyproxy.io/owning-gateway-name=front -c envoy --tail=20 | grep '"/api/todos"' | tail -1 | jq -c '{code: .response_code, path: ."x-envoy-origin-path", to: .upstream_host}'
kubectl -n todo get pods -o wide | grep web
```

**이 명령은**: 한 번 부르고 10초 기다린 뒤(로그는 몇 초 늦게 찍힘), 입구 `front`의 Envoy 로그 마지막 20줄 중 `/api/todos` 요청의 마지막 줄에서 응답 코드·경로·보낸 곳만 뽑아 봄. 마지막 줄 = web 파드의 IP.

**이렇게 나오면 성공**: `to`의 IP가 web 파드 IP와 같음

```
{"code":200,"path":"/api/todos","to":"10.244.1.12:80"}
web-5bdd6887b7-xh4tg    2/2     Running   0     27h   10.244.1.12   lab-worker   <none>   <none>
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 브라우저가 안 열림 | 8080이 아니라 80을 전달함, 포트 번호 오타 | PORTS 탭의 8080 줄 |
| 아무것도 안 나옴 | 로그가 아직 안 찍힘 | 10초 뒤 셋째 줄만 다시 |
| `jq: command not found` | jq가 없는 VM | `jq …` 부분을 빼고 JSON 한 줄을 그대로 읽음 |

</details>

## 7단계. 고장 난 HTTPRoute 읽기 — 404와 500

경로 규칙에 오타가 있으면 어떻게 보일까요? 5단계 파일을 복사해 **일부러 틀린** HTTPRoute를 만들고, 응답 코드와 상태(status)를 읽어 원인을 찾습니다. 주소는 `broken.localhost:8080`을 씁니다(todo는 그대로 둠).

**가. 이름(hostnames) 오타**

```bash
cd ~/apigw
cp todo-route.yaml broken.yaml
nano broken.yaml
```

두 군데를 바꿉니다: `name: todo` → `name: broken`, `hostnames: ["todo.localhost"]` → `hostnames: ["brokn.localhost"]`(일부러 `e`를 뺌).

```bash
kubectl apply -f broken.yaml
curl -s -o /dev/null -w "%{http_code}\n" broken.localhost:8080
kubectl -n todo get httproute broken -o jsonpath='{range .status.parents[0].conditions[*]}{.type}={.status}{"\n"}{end}'
kubectl get httproute -A
```

**이렇게 나오면 성공**(고장이 보이는 것이 정상): `404`인데 상태는 둘 다 `True`. `HOSTNAMES` 열에 오타가 보임

```
httproute.gateway.networking.k8s.io/broken created
404
Accepted=True
ResolvedRefs=True
NAMESPACE   NAME       HOSTNAMES             AGE
todo        broken     ["brokn.localhost"]   2s
todo        todo       ["todo.localhost"]    3m53s
...
```

- 입구는 이 규칙을 받아들였고(`Accepted`) 보낼 곳도 찾았지만(`ResolvedRefs`), 손님이 부른 이름 `broken.localhost`와 규칙의 이름이 다릅니다. **상태가 멀쩡한 404는 이름·경로를 비교**합니다

**나. 보낼 곳(backendRefs) 오타** — `nano broken.yaml`로 이름은 `broken.localhost`로 고치고, 이번에는 `- name: web`을 `- name: webb`로 바꿉니다.

```bash
kubectl apply -f broken.yaml
curl -s -o /dev/null -w "%{http_code}\n" broken.localhost:8080
kubectl -n todo get httproute broken -o yaml | sed -n '/^status:/,$p'
```

**이렇게 나오면 성공**: `500`, 상태 `ResolvedRefs`가 `False`이고 `message`에 이유

```
httproute.gateway.networking.k8s.io/broken configured
500
status:
  parents:
  - conditions:
    - lastTransitionTime: "2026-10-22T13:45:37Z"
      message: Route is accepted
      observedGeneration: 2
      reason: Accepted
      status: "True"
      type: Accepted
    - lastTransitionTime: "2026-10-22T13:45:37Z"
      message: 'Failed to process route rule 0 backendRef 0: service todo/webb not
        found.'
      observedGeneration: 2
      reason: BackendNotFound
      status: "False"
      type: ResolvedRefs
...
```

**다. 고치고 지우기** — `nano broken.yaml`로 `webb`를 `web`으로 되돌려 apply하면 `200`. 확인했으면 지웁니다.

```bash
kubectl apply -f broken.yaml
curl -s -o /dev/null -w "%{http_code}\n" broken.localhost:8080
kubectl delete -f broken.yaml
```

| 응답 | 먼저 볼 것 | 이번 원인 |
|---|---|---|
| `404`, 상태 둘 다 `True` | `kubectl get httproute -A`의 `HOSTNAMES`, 규칙의 `path` | 이름 오타 |
| `500`, `ResolvedRefs=False` | `-o yaml`의 `status` → `message` | Service 이름 오타 |
| 상태가 아예 빈 줄 | `parentRefs`(이름 `front`, 네임스페이스 `gateway`) | 입구를 못 찾음 |

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 상태가 빈 줄 | apply 직후 | 3초 뒤 다시 |
| 나에서 `404` | 이름을 `broken.localhost`로 안 고침 | 가의 오타를 먼저 고침 |
| `kubectl get httproute -A`에서 `todo`가 없어짐 | `name: todo`를 그대로 둬서 실습 1의 `todo`를 덮어씀 | `kubectl apply -f todo-route.yaml`로 되돌리고 `name: broken`으로 |

</details>

## 끝났는지 확인
- ☐ `kubectl get gatewayclass`에 `eg … True`
- ☐ Gateway만 있을 때 `todo.localhost:8080`이 `404`(`content-length: 0`)
- ☐ HTTPRoute 뒤 `todo.localhost:8080`에 todo 화면, `/api/todos`에 목록
- ☐ 게이트웨이 로그의 `to`가 web 파드 IP
- ☐ 고장 난 HTTPRoute: 이름 오타 `404`(상태 `True`), 보낼 곳 오타 `500`(`ResolvedRefs=False`), 지운 뒤 `todo`는 그대로

## 정리
- 7단계의 `broken`은 지웠습니다. 나머지는 모두 둡니다. 실습 2부터 이 입구(`front`)와 HTTPRoute `todo`를 씁니다

## 확인 문제
1. `curl -s -o /dev/null -w "%{http_code}\n" nothing.localhost:8080`은 무엇이 나올까요? 4단계의 404와 같은 이유인가요?
2. GatewayClass · Gateway · HTTPRoute 중 앱 팀이 자기 앱을 새로 열 때 만드는 것은 무엇인가요? 이 실습에서 만든 파일 둘 중 어느 쪽인가요?
