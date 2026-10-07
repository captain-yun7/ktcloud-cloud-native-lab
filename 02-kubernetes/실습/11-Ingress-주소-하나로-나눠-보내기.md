[← 실습 10](./10-requests와-limits-얼마나-쓰나.md) · [목차](../Kubernetes-실습.md) · [실습 12 →](./12-Helm-Online-Boutique를-한-번에.md)

# 실습 11. Ingress — 주소 하나로 나눠 보내기

**무엇을 하나요**: Ingress 컨트롤러(Traefik)를 설치하고, 규칙 하나로 `hello.localhost`는 hello로, `todo.localhost`는 todo 화면(web)으로 보냅니다. port-forward 없이 VM의 80번 하나로 두 앱에 들어갑니다. (교안 09장)

**필요한 것**: Service `hello`(실습 6), todo의 Service `web`(실습 7).

**왜 필요한가요**: 지금까지 클러스터 밖에서 앱에 들어가는 길은 port-forward(실습 6)와 NodePort(실습 6 7단계)였습니다. 앱이 2개면 괜찮지만 **10개라면** 이렇게 됩니다.

| 방법 | 밖에서 부르는 주소 | 앱이 10개면 |
|---|---|---|
| port-forward | `localhost:8000` — 내 VM에서만, 켜 둔 동안만 | 터미널 10개를 켜 둠. 다른 사람은 못 들어옴 |
| NodePort | `노드 IP:30080` | 30000번대 포트 번호 10개를 사용자가 기억해야 함 |
| LoadBalancer | 외부 IP | 외부 IP 10개 — 클라우드 비용도 10개 |
| **Ingress** | `hello.localhost`·`todo.localhost`처럼 **이름** | 입구 하나(80번)에서 이름·경로로 10개에 나눔 |

웹 서비스 주소가 `shop.example.com`, `shop.example.com/api`처럼 이름과 경로로 나뉘는 것이 Ingress가 하는 일입니다.

> **바로 가기** · [1. Ingress 컨트롤러 설치](#1단계-ingress-컨트롤러-설치) · [2. Ingress 규칙 쓰기](#2단계-ingress-규칙-쓰기) · [3. 이름으로 들어가 보기](#3단계-이름으로-들어가-보기) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. Ingress 컨트롤러 설치

```bash
cd ~/ktcloud-cloud-native-lab/lab
make ingress
kubectl get pods -n traefik
```

**이 명령은**: `make ingress` = Ingress 규칙을 읽고 실제로 요청을 나눠 주는 프로그램(Ingress 컨트롤러) **Traefik**을 Helm으로 설치(Helm은 실습 12). 10초쯤 걸립니다.

**이렇게 나오면 성공**

```
NAME                CONTROLLER                      PARAMETERS   AGE
traefik (default)   traefik.io/ingress-controller   <none>       6s
```
```
NAME                       READY   STATUS    RESTARTS   AGE
traefik-694bbc456d-bzcxq   1/1     Running   0          6s
```

- Ingress **규칙**(YAML)만으로는 아무 일도 일어나지 않습니다. 규칙을 읽고 요청을 나눠 주는 **컨트롤러**가 있어야 합니다. 예전에 많이 쓰던 ingress-nginx는 2026-03 개발이 끝나 이 과정은 Traefik을 씁니다
- kind 클러스터는 만들 때부터 **VM의 80번 → 노드의 80번**을 이어 두었습니다(`lab/kind/lite.yaml`). Traefik이 그 80번에서 기다립니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `make: *** No rule to make target 'ingress'.  Stop.` | `lab` 폴더가 아닌 곳, 또는 옛 저장소 | `cd ~/ktcloud-cloud-native-lab/lab`, `git pull` |

</details>

## 2단계. Ingress 규칙 쓰기

```bash
mkdir -p ~/ktcloud-cloud-native-lab/lab/k8s/ingress
cd ~/ktcloud-cloud-native-lab/lab/k8s/ingress
nano ing.yaml
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: lab
spec:
  rules:
  - host: hello.localhost
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello
            port:
              number: 80
  - host: todo.localhost
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
```

**이 파일은**

| 줄 | 뜻 |
|---|---|
| `kind: Ingress` · `name: lab` | 들어오는 길의 규칙 묶음 |
| `rules:` 아래 `- host: hello.localhost` | 요청한 **주소(호스트 이름)** 가 `hello.localhost`이면 |
| `path: /`, `pathType: Prefix` | `/`로 시작하는 모든 경로를 |
| `backend.service.name: hello`, `port.number: 80` | Service `hello`의 80번으로 보냄(파드가 아니라 **Service**를 가리킴) |
| 두 번째 `- host: todo.localhost` | `todo.localhost`는 Service `web`(80)으로 |

```bash
kubectl apply -f ing.yaml
kubectl get ingress
```

```
ingress.networking.k8s.io/lab created
NAME   CLASS     HOSTS                            ADDRESS   PORTS   AGE
lab    traefik   hello.localhost,todo.localhost             80      0s
```

## 3단계. 이름으로 들어가 보기

```bash
curl hello.localhost
curl todo.localhost | head -5
curl todo.localhost/api/todos
curl nothing.localhost
```

**이렇게 나오면 성공**

```
hello, docker
<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <title>todo</title>
[{"id":1,"title":"keep me"}]
404 page not found
```

- `*.localhost`는 어느 컴퓨터에서나 **자기 자신**(127.0.0.1)을 가리키는 이름입니다. 그래서 VM의 80번 → 노드의 80번 → Traefik으로 들어가고, Traefik이 요청의 **이름**(`hello.localhost`인지 `todo.localhost`인지)을 보고 나눠 보냅니다
- 규칙에 없는 이름(`nothing.localhost`)은 Traefik이 `404 page not found`
- todo 화면의 `/api/` 요청은 web(nginx)이 다시 api로 넘깁니다(실습 7)

규칙이 실제로 어느 파드로 이어지는지 봅니다.

```bash
kubectl describe ingress lab | grep -A4 Rules
```

```
Rules:
  Host             Path  Backends
  ----             ----  --------
  hello.localhost
                   /   hello:80 (10.244.0.77:3000,10.244.0.78:3000,10.244.0.79:3000)
```

브라우저로 보기: VS Code **PORTS** 탭에서 `80`을 전달하고, 브라우저 주소창에 `http://hello.localhost:<Forwarded Address의 포트>`, `http://todo.localhost:<포트>`를 입력합니다(노트북에서 80번을 쓸 수 없으면 PORTS가 다른 번호를 줍니다).

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 모든 주소가 `404 page not found` | 1단계 `make ingress` 전에 규칙만 만듦, 또는 규칙의 `host` 오타 | `kubectl get pods -n traefik`, `kubectl get ingress`의 `HOSTS` 확인 |
| `curl: (7) Failed to connect to hello.localhost port 80` | Traefik이 없거나 클러스터가 꺼짐 | 1단계, [시작하기 전에 6](./00-시작하기-전에.md#6-클러스터가-떠-있는지-확인-실습-2부터-매번) |
| `Service Unavailable` 또는 응답 없음 | `backend.service.name`·`port`가 실제 Service와 다름 | `kubectl get service`의 이름·포트와 맞춤 |

</details>

## 끝났는지 확인
- ☐ `curl hello.localhost`에 `hello, docker`
- ☐ `curl todo.localhost/api/todos`에 할 일 목록
- ☐ `curl nothing.localhost`에 `404 page not found`

## 정리
- Traefik(`make ingress`)은 **다른 과목에서도 씁니다**. 지우지 마세요. Ingress `lab`은 두어도 됩니다

## 확인 문제
1. `ing.yaml`에 규칙을 하나 더해 `hi.localhost`로 들어온 요청도 hello로 가게 하세요. `curl hi.localhost`로 확인합니다.
2. `curl localhost`(이름 없이)는 무엇이 나오나요? 왜 그럴까요?
