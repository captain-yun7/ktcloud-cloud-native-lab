[← 실습 5](./05-todo-대시보드-만들기.md) · [목차](../모니터링-실습.md) · [실습 7 →](./07-한-요청이-지나간-길-Tempo.md)

# 실습 6. Loki와 LogQL

**무엇을 하나요**: 실습 5에서 todo가 500을 낸 **이유**를 로그에서 찾습니다. 먼저 `kubectl logs`만으로 찾아 불편한 점을 보고, 파드 로그를 모으는 **Alloy**와 저장하는 **Loki**를 설치해 Grafana에서 **LogQL**로 찾습니다. 쇼핑몰(Online Boutique)의 JSON 로그는 필드로 거르고, 마지막에 파드를 지워도 Loki에는 로그가 남는지 봅니다. (교안 06장)

**필요한 것**: 실습 5까지(4단계에서 db 장애를 냈다가 되돌린 todo), 브라우저의 Grafana 화면.

**화면이 헷갈리면**: [실습 6 화면 가이드](./06-화면-가이드.md) — 3~7단계의 실제 Grafana 13 Explore 화면과 볼 곳(빨간 네모)

> **바로 가기** · [1. Loki 없이 — kubectl logs로 찾기](#1단계-loki-없이--kubectl-logs로-찾기) · [2. 설치 — make logging](#2단계-설치--make-logging) · [3. 이름표로 고르기](#3단계-이름표로-고르기) · [4. 본문으로 거르기 — 실습 5의 500 찾기](#4단계-본문으로-거르기--실습-5의-500-찾기) · [5. JSON 필드로 거르기](#5단계-json-필드로-거르기) · [6. 로그 줄 수를 지표처럼](#6단계-로그-줄-수를-지표처럼) · [7. 파드를 지워도 로그가 남나](#7단계-파드를-지워도-로그가-남나) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. Loki 없이 — kubectl logs로 찾기

실습 5의 4단계에서 todo가 500을 냈습니다. 지금까지 쓰던 `kubectl logs`로 흔적을 찾아봅니다.

```bash
kubectl -n todo logs deploy/web -c nginx --tail=2
kubectl -n todo logs deploy/web -c nginx | grep -c '" 500 '
kubectl -n todo logs deploy/api | grep -m1 -B1 -A3 ECONNRESET
```

**이 명령은**: 첫 줄 = web(nginx)의 마지막 로그 2줄(요청마다 한 줄). 둘째 줄 = 응답 코드 500인 줄 수(`grep -c` = 맞는 줄 수). 셋째 줄 = api 로그에서 `ECONNRESET`이 처음 나온 곳과 앞뒤 줄.

**이렇게 나오면 성공** (숫자는 사람마다 다름)

```
127.0.0.6 - - [16/Oct/2026:09:42:03 +0000] "GET /api/todos HTTP/1.1" 200 73 "-" "curl/8.16.0" "-"
127.0.0.6 - - [16/Oct/2026:09:42:04 +0000] "GET /api/todos HTTP/1.1" 200 73 "-" "curl/8.16.0" "-"
129
Error: read ECONNRESET
    at /app/node_modules/pg-pool/index.js:45:11
    at process.processTicksAndRejections (node:internal/process/task_queues:103:5)
    at async /app/app.js:45:20
```

- web은 "500을 돌려줬다"까지, api는 "db 연결이 끊겼다(`ECONNRESET`)"까지 압니다. 두 파드를 따로 열어 봐야 이어집니다

| 하고 싶은 것 | `kubectl logs`만 있을 때 | Loki (2단계부터) |
|---|---|---|
| 여러 앱의 로그 | 앱(파드)마다 명령을 따로 — shop에만 12개 | 이름표(`namespace="todo"`)로 한 번에, 시간순으로 |
| 500 세기 | 로그 모양에 맞춘 `grep` 문자열을 직접 짬 | `\|= " 500 "`, JSON이면 `\| json \| http_resp_status >= 500` |
| 지워진 파드의 로그 | 파드와 함께 **사라짐**(7단계) | 남아 있음 |

## 2단계. 설치 — make logging

```bash
cd ~/ktcloud-cloud-native-lab/lab
make logging              # 약 1분 30초
```

**이 명령은**: Loki와 Alloy를 `monitoring` 네임스페이스에 설치.

**이렇게 나오면 성공**: 1분 30초쯤 뒤 두 파드가 `Running`.

```
alloy-7dd8b6bc4f-bzvzj                                  2/2     Running   0          36s
loki-0                                                  2/2     Running   0          87s
```

| 구성 요소 | 하는 일 |
|---|---|
| Alloy | 쿠버네티스 API로 모든 파드의 로그를 읽어 이름표(namespace, pod, container, app)를 붙여 보냄 |
| Loki | 로그 저장. **본문이 아니라 이름표로** 찾아보기를 만들어서 가벼움 |
| Grafana | 데이터 소스 `Loki`가 미리 등록돼 있음 → **Explore**에서 조회 |

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `make: *** No rule to make target 'logging'.` | `lab` 폴더 밖 | 첫 줄부터 |
| 로그에 `failed to create fsnotify watcher: too many open files` 줄이 계속 보임 | 내 PC(로컬)에서 실습 중 — 파일 변화 감시 한도가 작음(서버 VM에는 미리 늘려 둠) | `sudo sysctl -w fs.inotify.max_user_instances=512` (PC를 다시 켜면 원래대로) |

</details>

## 3단계. 이름표로 고르기

Grafana → **Explore** → 위쪽 데이터 소스를 **Loki**로 → 쿼리 칸 오른쪽 **Code** → 아래를 넣고 **Run query**.

```logql
{namespace="todo", app="web", container="nginx"}
```

**이 쿼리는**: 이름표가 `namespace="todo"`, `app="web"`, `container="nginx"`인 로그 흐름 = web 파드의 nginx 로그.

**이렇게 나오면 성공**: `"GET /api/todos HTTP/1.1" 200 …` 줄이 시간순으로 나옴. 1초에 한 줄(손님 `load`).

- `container="nginx"`를 빼면 사이드카(`istio-proxy`) 로그 줄도 섞입니다

## 4단계. 본문으로 거르기 — 실습 5의 500 찾기

오른쪽 위 시간 범위를 **Last 1 hour**로 두고 하나씩 넣습니다.

```logql
{namespace="todo", app="web", container="nginx"} |= "\" 500 "
{namespace="todo", app="api"} |= "ECONNRESET"
```

**이 쿼리는**: `|=` = 본문에 이 글자가 **들어 있는** 줄만. 첫째 = web의 500 응답 줄, 둘째 = api의 db 연결 끊김 줄.

**이렇게 나오면 성공**: 두 쿼리 모두 실습 5 장애 시간대에 줄이 몰려 있음(강사 VM 각 129줄). 위쪽 막대 그래프에서 두 쿼리의 시간대가 겹칩니다.

- 실습 5의 대시보드는 "500이 94%"까지 말했습니다. 로그는 **"api가 db 연결을 못 해서(`ECONNRESET`)"** 라고 이유를 말합니다
- Loki를 설치하기 **전**의 로그인데도 보이는 것은 Alloy가 설치될 때 떠 있던 파드의 지난 로그를 처음부터 읽어 보냈기 때문입니다

## 5단계. JSON 필드로 거르기

쇼핑몰 frontend는 로그를 JSON 한 줄로 남깁니다.

```logql
{namespace="shop", app="frontend"} | json | http_resp_took_ms > 100
```

**이 쿼리는**: `| json` = JSON 로그를 필드로 풀기(`http.resp.took_ms` → 점이 `_`로 바뀌어 `http_resp_took_ms`), 그다음 처리에 100ms 넘게 걸린 요청만.

**이렇게 나오면 성공**: 몇 줄(강사 VM 최근 1시간 2줄 — 주문(`/cart/checkout`) 247ms, 상품 화면 158ms). 줄을 누르면 필드가 표로 펼쳐짐.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 데이터 소스 목록에 Loki가 없음 | 실습 1을 옛 저장소로 설치함 | `git pull` 후 `make monitoring` 한 번 더 |
| `No data` | 데이터 소스가 Prometheus로 돼 있음, 시간 범위가 짧음 | 위쪽 Loki, Last 1 hour |
| `parse error …` | `{}` 없이 시작했거나 따옴표 오타 | 반드시 `{namespace="…"}`로 시작 |

</details>

## 6단계. 로그 줄 수를 지표처럼

```logql
sum by (app) (count_over_time({namespace="shop"}[1m]))
```

**이 쿼리는**: shop 앱마다 1분 동안의 로그 줄 수. 로그를 숫자로 바꿔 그래프로 그림.

**이렇게 나오면 성공**: 앱마다 선이 하나씩, 11~12개. frontend·loadgenerator가 약 500으로 가장 많음.

## 7단계. 파드를 지워도 로그가 남나

api 파드를 지웁니다. Deployment가 새 파드를 곧바로 만듭니다.

```bash
OLD=$(kubectl -n todo get pods -l app=api -o name | cut -d/ -f2); echo $OLD
kubectl -n todo delete pod $OLD
kubectl -n todo rollout status deploy/api
kubectl -n todo logs $OLD
```

**이 명령은**: 첫 줄 = 지금 api 파드 이름을 `OLD`에 담고 보여 줌. 둘째·셋째 줄 = 그 파드를 지우고 새 파드가 뜰 때까지 기다림. 넷째 줄 = 지운 파드의 로그를 달라고 함.

**이렇게 나오면 성공**

```
api-545f9b5f76-fqsd5
pod "api-545f9b5f76-fqsd5" deleted from todo namespace
deployment "api" successfully rolled out
error: error from server (NotFound): pods "api-545f9b5f76-fqsd5" not found in namespace "todo"
```

`kubectl`로는 지운 파드의 로그를 볼 수 없습니다. 20초쯤 뒤 Grafana Explore(Loki)에서 봅니다.

```logql
sum by (pod) (count_over_time({namespace="todo", app="api"} |= "ECONNRESET" [1h]))
```

**이렇게 나오면 성공**: 지운 파드(`OLD`와 같은 이름) 줄이 그대로 — 강사 VM 129.

- Alloy가 로그를 받는 대로 Loki로 보냈기 때문에 파드가 없어져도 남습니다. 장애로 파드가 다시 만들어진 뒤에도 장애 때의 로그를 찾을 수 있는 이유입니다

## 끝났는지 확인
- ☐ Explore(Loki)에서 todo web 로그가 보임
- ☐ 4단계에서 web 500과 api `ECONNRESET`이 같은 시간대에 있는 것을 봄
- ☐ 7단계에서 지운 파드의 로그가 `kubectl logs`로는 안 보이고 Loki에는 남은 것을 봄

## 정리
- Loki·Alloy는 남겨 둡니다(실습 8·미션 2에서 장애 로그를 찾음)

## 확인 문제
1. 6단계 그래프에서 1분에 로그를 가장 많이 남기는 두 앱은 무엇인가요? 두 값이 비슷한 까닭은?
2. shop frontend 로그 중 **주문**(`/cart/checkout`) 요청만 골라 보세요. 힌트: `| json` 뒤에 `http_req_path`.
