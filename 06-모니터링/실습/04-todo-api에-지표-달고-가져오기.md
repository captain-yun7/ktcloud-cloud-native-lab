[← 실습 3](./03-PromQL-기본.md) · [목차](../모니터링-실습.md) · [실습 5 →](./05-todo-대시보드-만들기.md)

# 실습 4. todo-api에 지표 달고 가져오기

**무엇을 하나요**: todo-api 코드에 **직접 지표를 다는** 몇 줄을 넣어 `/metrics` 주소를 만들고, 이미지를 새로 만들어 배포한 뒤, **ServiceMonitor**로 Prometheus가 가져가게 합니다. 먼저 지금의 todo-api에는 `/metrics`가 없어 Prometheus에 앱 지표가 하나도 없는 것을 봅니다. 마지막에 사이드카 지표(실습 3)에는 없는 **경로별** 숫자를 봅니다. (교안 04장)

**필요한 것**: 실습 3까지(todo `2/2`, `~/mon` 폴더), VM 도커.

> **바로 가기** · [1. 지표 없이 — /metrics가 없음](#1단계-지표-없이--metrics가-없음) · [2. 소스 복사하고 prom-client 넣기](#2단계-소스-복사하고-prom-client-넣기) · [3. app.js에 지표 코드 넣기](#3단계-appjs에-지표-코드-넣기) · [4. 이미지 빌드와 배포](#4단계-이미지-빌드와-배포) · [5. Service 이름표와 포트 이름](#5단계-service-이름표와-포트-이름) · [6. ServiceMonitor 쓰고 적용](#6단계-servicemonitor-쓰고-적용) · [7. 앱 지표로 질의 — 사이드카가 모르는 경로](#7단계-앱-지표로-질의--사이드카가-모르는-경로) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 지표 없이 — /metrics가 없음

```bash
kubectl -n todo exec deploy/load -c curl -- curl -s -w " %{http_code}\n" http://api:3000/metrics
```

**이 명령은**: 손님 파드 안에서 todo-api의 `/metrics` 주소를 부르고, 끝에 응답 코드를 붙여 보여 줌.

**이렇게 나오면 성공** — 그런 주소가 없습니다

```
<!DOCTYPE html>
...
<pre>Cannot GET /metrics</pre>
...
 404
```

Prometheus **Query**에도 넣어 봅니다.

```promql
todo_http_requests_total
```

**이렇게 나오면 성공**: `Empty query result`.

| | 지금 (앱 지표 없음) | 7단계 뒤 (앱 지표 있음) |
|---|---|---|
| `/metrics` | 404 | 요청 수·처리 시간 숫자 |
| Prometheus의 todo-api 숫자 | 사이드카가 센 것뿐(응답 코드별) | 앱이 센 것 — **경로별**(`/api/todos` GET·POST) |
| 프로젝트에서 "우리 서비스 지표" | 만들 방법을 모름 | 이 실습의 몇 줄 |

## 2단계. 소스 복사하고 prom-client 넣기

```bash
cp -r ~/ktcloud-cloud-native-lab/lab/docker/todo/api ~/mon/api-metrics
cd ~/mon/api-metrics
docker run --rm -u $(id -u):$(id -g) -e HOME=/tmp -v "$PWD":/app -w /app node:22-alpine npm install prom-client@15.1.3 --save-exact --package-lock-only
grep -n prom-client package.json
```

**이 명령은**: 첫 줄 = todo-api 소스를 `~/mon/api-metrics`로 통째로 복사(원본은 그대로). 셋째 줄 = VM에는 Node.js가 없으므로 **Node 컨테이너를 잠깐 띄워** 지표 라이브러리 `prom-client`를 의존성 목록(`package.json`·`package-lock.json`)에 추가. 마지막 줄 = 추가됐는지 확인.

**이렇게 나오면 성공**

```
up to date, audited 87 packages in 797ms
...
found 0 vulnerabilities
12:    "prom-client": "15.1.3"
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `cp: cannot stat …` | 실습 저장소 경로가 다름 | `ls ~/ktcloud-cloud-native-lab/lab/docker/todo/api` |
| `EACCES: permission denied` | `-u …`·`-e HOME=/tmp`를 빠뜨림 | 셋째 줄을 그대로 다시 |
| `cp: … api-metrics/api` 처럼 한 단계 더 들어감 | `~/mon/api-metrics`가 이미 있었음 | `rm -rf ~/mon/api-metrics` 후 첫 줄부터 |

</details>

## 3단계. app.js에 지표 코드 넣기

```bash
nano app.js
```

`app.use(express.json());` 줄을 찾아 **바로 아래**에 다음을 붙여 넣고 저장합니다(**Ctrl+O → Enter → Ctrl+X**).

```js
// --- 지표: Prometheus가 가져갈 /metrics (모니터링 실습 4) ---
const client = require('prom-client');
const requests = new client.Counter({
  name: 'todo_http_requests_total',
  help: 'todo-api가 받은 요청 수',
  labelNames: ['method', 'route', 'code'],
});
const duration = new client.Histogram({
  name: 'todo_http_request_duration_seconds',
  help: 'todo-api가 요청 하나를 처리한 시간(초)',
  labelNames: ['method', 'route'],
});
app.use((req, res, next) => {
  const end = duration.startTimer();
  res.on('finish', () => {
    const route = req.route ? req.route.path : 'none';
    requests.inc({ method: req.method, route, code: res.statusCode });
    end({ method: req.method, route });
  });
  next();
});
app.get('/metrics', async (req, res) => {
  res.type(client.register.contentType).send(await client.register.metrics());
});
```

| 부분 | 뜻 |
|---|---|
| `new client.Counter({…})` | 늘기만 하는 숫자 하나. 이름 `todo_http_requests_total`, 이름표 셋(방법·경로·응답 코드) |
| `new client.Histogram({…})` | 걸린 시간을 구간별로 세는 숫자. 구간은 라이브러리 기본값(0.005초 ~ 10초) |
| `app.use((req, res, next) => {…})` | **모든 요청**마다 도는 함수. 시작할 때 시계를 켜고(`startTimer`), 응답이 끝나면(`finish`) 요청 수 +1, 걸린 시간 기록 |
| `req.route.path` | Express가 맞춘 경로 틀(`/api/todos`, `/api/todos/:id`) |
| `app.get('/metrics', …)` | 지금까지 센 숫자를 글자로 돌려주는 주소 |

확인합니다.

```bash
grep -n "prom-client\|app.use\|/metrics" app.js
```

**이렇게 나오면 성공**: `express.json()` 다음 줄부터 지표 코드가 있음.

```
16:app.use(express.json());
18:const client = require('prom-client');
29:app.use((req, res, next) => {
38:app.get('/metrics', async (req, res) => {
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 줄 번호가 문서와 다름 | 빈 줄이 하나 더 들어감 | 순서만 맞으면 됨(`express.json` → `prom-client` → `app.use` → `/metrics`) |
| `/metrics` 줄이 `/api/health`보다 아래 | 붙여 넣은 자리가 다름 | 동작은 하지만 문서대로 옮기는 것을 권장 |

</details>

## 4단계. 이미지 빌드와 배포

```bash
docker build -t todo-api:metrics .
kind load docker-image todo-api:metrics --name lab
kubectl -n todo set image deploy/api api=todo-api:metrics
kubectl -n todo rollout status deploy/api
kubectl -n todo exec deploy/load -c curl -- curl -s http://api:3000/metrics | grep todo_http_requests_total
```

**이 명령은**: 고친 소스로 이미지 `todo-api:metrics`를 만들어 노드에 넣고, api Deployment의 이미지를 바꿈(파드가 새로 만들어짐). 마지막 줄 = 1단계와 같은 주소를 다시 부름.

**이렇게 나오면 성공**: `successfully rolled out`, 그리고 `/metrics`에 숫자.

```
deployment "api" successfully rolled out
# HELP todo_http_requests_total todo-api가 받은 요청 수
# TYPE todo_http_requests_total counter
todo_http_requests_total{method="GET",route="/api/todos",code="200"} 15
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `npm error … prom-client` (빌드 중) | 2단계를 안 함(목록에 없음) | 2단계 셋째 줄 |
| api 파드가 `CrashLoopBackOff`, 로그에 `SyntaxError` | 3단계 붙여 넣기가 깨짐 | `kubectl -n todo logs deploy/api` 첫 줄을 보고 `nano app.js`로 고친 뒤 빌드부터 다시. 다시 만든 같은 태그는 `set image` 대신 `kubectl -n todo rollout restart deploy/api` |
| `ErrImageNeverPull` | `kind load`를 빠뜨림 | 둘째 줄 후 `kubectl -n todo rollout restart deploy/api` |
| 마지막 줄이 아무것도 안 나옴 | 막 떠서 아직 요청을 못 셈 | 5초 뒤 다시 |

</details>

## 5단계. Service 이름표와 포트 이름

ServiceMonitor는 **Service의 이름표**로 Service를 찾고, **포트 이름**으로 포트를 고릅니다. 지금 api Service에는 둘 다 없습니다.

```bash
kubectl -n todo get svc api --show-labels
kubectl -n todo label svc api app=api
kubectl -n todo patch svc api -p '{"spec":{"ports":[{"port":3000,"name":"http"}]}}'
kubectl -n todo get svc api --show-labels -o wide
kubectl -n todo get svc api -o jsonpath='{.spec.ports}'; echo
```

**이 명령은**: 첫 줄 = 지금 이름표(LABELS 칸). 둘째 줄 = Service에 이름표 `app=api`. 셋째 줄 = 3000번 포트에 이름 `http`. 마지막 두 줄 = 확인.

**이렇게 나오면 성공**: LABELS가 `<none>` → `app=api`, 포트에 `"name":"http"`.

```
NAME   TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)    AGE     LABELS
api    ClusterIP   10.96.48.59   <none>        3000/TCP   6m31s   <none>
service/api labeled
service/api patched
...                                                               app=api
[{"name":"http","port":3000,"protocol":"TCP","targetPort":3000}]
```

## 6단계. ServiceMonitor 쓰고 적용

```bash
cd ~/mon && nano todo-api-servicemonitor.yaml
```

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: todo-api
  namespace: todo
spec:
  selector:
    matchLabels:
      app: api
  endpoints:
  - port: http
    path: /metrics
    interval: 15s
```

| 줄 | 뜻 |
|---|---|
| `kind: ServiceMonitor` | "이 Service 뒤 파드들의 숫자를 가져가라" |
| `selector.matchLabels: app: api` | 5단계에서 붙인 Service 이름표 |
| `port: http` · `path: /metrics` | 5단계의 포트 이름, 3단계에서 만든 주소 |

```bash
kubectl apply -f todo-api-servicemonitor.yaml
```

**이렇게 나오면 성공**: `servicemonitor.monitoring.coreos.com/todo-api created`. 1~2분 안에 **Target health**에 `serviceMonitor/todo/todo-api/0` `UP`(주소 `http://<파드 IP>:3000/metrics`).

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 2분이 지나도 안 보임 | `matchLabels` 또는 `port:` 이름이 Service와 다름 | 5단계 확인 명령과 `cat todo-api-servicemonitor.yaml` 비교 |
| `DOWN`, 오류 `404` | 3단계 코드가 없거나 `path` 오타 | 4단계 마지막 줄 |
| `DOWN`, 오류 `connection reset by peer` | todo에 Istio mTLS STRICT가 걸려 있음 | 확인 문제 2 |

</details>

## 7단계. 앱 지표로 질의 — 사이드카가 모르는 경로

할 일 추가를 두 번 해 봅니다. 한 번은 제목 없이(거절), 한 번은 제대로.

```bash
L="kubectl -n todo exec deploy/load -c curl --"
$L curl -s -X POST -H "Content-Type: application/json" -d '{"title":""}' http://web/api/todos; echo
$L curl -s -X POST -H "Content-Type: application/json" -d '{"title":"지표 달기"}' http://web/api/todos; echo
```

**이렇게 나오면 성공**: `{"error":"title is required"}`, `{"id":2,"title":"지표 달기"}`

30초쯤 뒤 Prometheus **Query**에 하나씩 넣습니다.

```promql
todo_http_requests_total
sum by (route) (rate(todo_http_requests_total[1m]))
histogram_quantile(0.95, sum by (le) (rate(todo_http_request_duration_seconds_bucket{route="/api/todos"}[5m])))
```

**이렇게 나오면 성공**

| 쿼리 | 결과 (강사 VM) |
|---|---|
| 첫째 | 4줄 — GET `/api/todos` 200, GET `/metrics` 200, POST `/api/todos` 400, POST `/api/todos` 201 |
| 둘째 | `/api/todos` 약 1, `/metrics` 약 0.067 (= 15초에 한 번, Prometheus가 가져가는 요청) |
| 셋째 | 약 `0.0048` (초) = 4.8ms |

이번에는 실습 3의 사이드카 지표로 같은 api를 봅니다.

```promql
sum by (response_code) (istio_requests_total{namespace="todo", reporter="destination", destination_workload="api"})
```

| | 사이드카 지표 (`istio_requests_total`) | 앱 지표 (`todo_http_requests_total`) |
|---|---|---|
| 누가 세나 | 파드 앞의 Envoy — 코드 수정 없음 | 앱 코드(3단계의 몇 줄) |
| 응답 코드 | 있음 | 있음 |
| **경로**(목록 GET인지 추가 POST인지) | 없음 | 있음 — `route`, `method` |
| 앱 안에서만 아는 것(예: "추가된 할 일 수") | 못 셈 | 코드에 counter를 하나 더 만들면 셈 |

## 끝났는지 확인
- ☐ 1단계에서 `/metrics` 404를 봄
- ☐ 4단계 `/metrics`에 `todo_http_requests_total`이 나옴
- ☐ Target health에 `serviceMonitor/todo/todo-api/0` `UP`
- ☐ 7단계 첫 쿼리에 경로·코드별 줄이 나옴

## 정리
- `~/mon/api-metrics`, 이미지 `todo-api:metrics`, ServiceMonitor는 남겨 둡니다(실습 5·6에서 씀)

## 확인 문제
1. Ingress 컨트롤러 Traefik도 스스로 지표를 냅니다(Service `traefik-metrics`, 9100번). `kubectl -n traefik get svc traefik-metrics --show-labels`로 이름표를 보고 ServiceMonitor를 만들어, Prometheus에서 `sum by (code) (rate(traefik_entrypoint_requests_total{entrypoint="web"}[1m]))`가 나오게 해 보세요. 포트 이름은 `kubectl -n traefik get svc traefik-metrics -o jsonpath='{.spec.ports}'`로 봅니다.
2. (생각해 보기) todo에 Istio mTLS를 **STRICT**(평문 거부)로 걸면 `serviceMonitor/todo/todo-api/0`은 어떻게 될까요? `podMonitor/todo/istio-sidecars/0`(실습 3)은요? 왜 다를까요?
