[← 실습 2](./02-Grafana-기본-대시보드.md) · [목차](../모니터링-실습.md) · [실습 4 →](./04-todo-api에-지표-달고-가져오기.md)

# 실습 3. PromQL 기본

**무엇을 하나요**: todo의 Istio 사이드카가 센 요청 숫자를 Prometheus가 가져가게 한 뒤, PromQL로 거르고(라벨), 초당 값으로 바꾸고(rate), 묶어서 합치고(sum by), 지연 p95를 구하고(histogram_quantile), 큰 것만 고릅니다(topk). 먼저 사이드카에는 숫자가 있는데 Prometheus에는 없는 것을 봅니다. (교안 03장)

**필요한 것**: 실습 1의 todo(`2/2`)와 설치, Prometheus **Query** 탭(또는 Grafana **Explore**).

> **바로 가기** · [1. 사이드카 지표 없이 — 빈 결과](#1단계-사이드카-지표-없이--빈-결과) · [2. PodMonitor로 사이드카 지표 가져오기](#2단계-podmonitor로-사이드카-지표-가져오기) · [3. 라벨로 거르기 — 누적 카운터](#3단계-라벨로-거르기--누적-카운터) · [4. 초당 증가량 — rate](#4단계-초당-증가량--rate) · [5. 묶어서 합치기 — sum by](#5단계-묶어서-합치기--sum-by) · [6. 지연 — histogram_quantile](#6단계-지연--histogram_quantile) · [7. 지금 값 — Gauge와 topk](#7단계-지금-값--gauge와-topk) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 사이드카 지표 없이 — 빈 결과

todo 파드에는 Istio 사이드카가 붙어 있고, 사이드카는 요청을 셉니다. 사이드카 안의 숫자판을 직접 열어 봅니다.

```bash
kubectl -n todo exec deploy/api -c istio-proxy -- curl -s localhost:15090/stats/prometheus | grep "^istio_requests_total" | cut -c1-150
```

**이 명령은**: api 파드의 사이드카(`-c istio-proxy`) 안에서 숫자판 주소(15090번 `/stats/prometheus`)를 읽고, 요청 수 줄만 골라(`grep`) 앞 150글자만 보여 줌(`cut`).

**이렇게 나오면 성공** — 줄이 몇 개 있습니다

```
istio_requests_total{reporter="destination",source_workload="web",source_canonical_service="web",source_canonical_revision="latest",source_workload_namespace="todo",source_p
...
```

이제 Prometheus **Query**에 넣어 봅니다.

```promql
istio_requests_total{namespace="todo"}
```

**이렇게 나오면 성공**: `Empty query result` — 사이드카 안에는 있는데 Prometheus에는 없습니다. 실습 1의 6단계 목록(22개)에 사이드카가 없기 때문입니다.

## 2단계. PodMonitor로 사이드카 지표 가져오기

```bash
mkdir -p ~/mon && cd ~/mon && nano istio-podmonitor.yaml
```

아래를 붙여 넣고 **Ctrl+O → Enter → Ctrl+X**.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: istio-sidecars
  namespace: todo
spec:
  selector:
    matchLabels:
      security.istio.io/tlsMode: istio
  podMetricsEndpoints:
  - port: http-envoy-prom
    path: /stats/prometheus
    interval: 15s
```

| 줄 | 뜻 |
|---|---|
| `kind: PodMonitor` | "이 파드들의 숫자를 가져가라" — Prometheus Operator가 읽음 |
| `namespace: todo` | todo 네임스페이스의 파드만 |
| `selector.matchLabels` | 사이드카가 붙은 파드에 Istio가 자동으로 붙이는 이름표 |
| `port: http-envoy-prom` · `path: /stats/prometheus` | 사이드카의 숫자판(15090번)의 포트 **이름**과 경로 |
| `interval: 15s` | 15초마다 |

```bash
kubectl apply -f istio-podmonitor.yaml
```

**이렇게 나오면 성공**: `podmonitor.monitoring.coreos.com/istio-sidecars created`. **1~2분 뒤** Prometheus **Status → Target health**에 `podMonitor/todo/istio-sidecars/0`이 4개 `UP`, 1단계 쿼리에 줄이 나옵니다.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `no matches for kind "PodMonitor"` | 실습 1의 설치가 안 끝남 | 실습 1의 4단계 |
| 2분이 지나도 대상이 안 생김 | 라벨·포트 이름 오타 | `kubectl -n todo get pods --show-labels`에서 `security.istio.io/tlsMode=istio` 확인, `cat istio-podmonitor.yaml` |
| 대상이 `DOWN`, 오류에 `404` | `path` 빠짐(기본 `/metrics`로 감) | `path: /stats/prometheus` |

</details>

## 3단계. 라벨로 거르기 — 누적 카운터

```promql
istio_requests_total{namespace="todo", reporter="destination", destination_workload="api"}
```

**이 쿼리는**: 사이드카가 센 요청 수 중 **받은 쪽**이 센 것(`reporter="destination"`), 받은 서비스가 api인 것만. 30초 뒤에 **Execute**를 한 번 더 누릅니다.

**이렇게 나오면 성공**: 응답 코드(`response_code`)마다 한 줄, `200` 줄 값이 누를 때마다 커짐.

| response_code | 처음 | 30초 뒤 |
|---|---|---|
| 200 | 270 | 300 |
| 201 | 1 | 1 |
| 503 | 5 | 5 |

- 이 숫자는 파드가 뜬 뒤 **지금까지의 합계**입니다. 줄지 않고 늘기만 하는 숫자 = **counter**(이름이 `_total`로 끝남)
- 201은 실습 1에서 할 일을 넣은 요청, 503은 todo를 띄울 때 api가 db를 기다리는 동안 들어온 요청입니다

## 4단계. 초당 증가량 — rate

```promql
rate(istio_requests_total{namespace="todo", reporter="destination", destination_workload="api"}[1m])
```

**이 쿼리는**: `[1m]` = 최근 1분 동안의 값들, `rate(…)` = 그동안 **1초에 얼마나 늘었나**.

**이렇게 나오면 성공**: `200` 줄이 `1` 근처, 나머지는 `0`.

| | 3단계 — rate 없이 (누적) | 4단계 — rate |
|---|---|---|
| 값 | 270 → 300 (계속 커짐) | `1` — 1초에 1번 |
| 뜻 | 파드가 뜬 뒤 지금까지 몇 번 | **지금** 1초에 몇 번 |
| Graph 탭 모양 | 오르기만 하는 선 | 바쁘면 오르고 한가하면 내려가는 선 |

- `load` 파드가 1초에 한 번 부르니 1이 맞습니다. 지금은 503이 안 생기므로 503 줄은 0입니다

## 5단계. 묶어서 합치기 — sum by

```promql
sum by (destination_workload) (rate(istio_requests_total{namespace="todo", reporter="destination"}[1m]))
sum by (response_code) (rate(istio_requests_total{namespace="todo", reporter="destination"}[1m]))
```

**이 쿼리는**: 첫 줄 = 받은 서비스별로 더함. 둘째 줄 = 응답 코드별로 더함. 결과에는 `by (…)`에 적은 이름표만 남습니다.

**이렇게 나오면 성공**

```
{destination_workload="api"}  1
{destination_workload="web"}  1
```
```
{response_code="200"}  2
{response_code="201"}  0
{response_code="503"}  0
```

- web 1번 → api 1번. 둘째 쿼리의 200이 2인 것은 web과 api가 받은 것을 **함께** 더했기 때문입니다

## 6단계. 지연 — histogram_quantile

```promql
histogram_quantile(0.95, sum by (le, destination_workload) (rate(istio_request_duration_milliseconds_bucket{namespace="todo", reporter="destination"}[1m])))
```

**이 쿼리는**: `_bucket` = "몇 ms 안에 끝난 요청이 몇 개"를 구간(`le`)마다 센 숫자(**histogram**). `histogram_quantile(0.95, …)` = 거기서 p95(빠른 순으로 95번째)를 계산. 서비스별로 보려고 `le`와 `destination_workload`를 남김.

**이렇게 나오면 성공**: 서비스마다 ms 숫자 하나.

```
{destination_workload="api"}  4.8
{destination_workload="web"}  6.3
```

구간이 어떻게 생겼는지 보려면 아래를 넣어 봅니다(`response_code="200"` 줄만 보면 됨).

```promql
istio_request_duration_milliseconds_bucket{namespace="todo", reporter="destination", destination_workload="api"}
```

| le (ms 이하) | 0.5 | 1 | 5 | 10 | 25 | … |
|---|---|---|---|---|---|---|
| 요청 수 (누적) | 0 | 59 | 294 | 299 | 300 | 300 |

- 300개 중 95%(285번째)는 1~5ms 구간 안에 있습니다. p95 4.8ms는 그 구간 안을 비율로 짐작한 값입니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `Empty query result` 또는 `NaN` | `sum by`에서 `le`를 뺌, 또는 범위에 요청이 없음 | `by (le, …)`, `[5m]` |
| `parse error: …` | 괄호 짝이 안 맞음 | 문서에서 다시 복사 |

</details>

## 7단계. 지금 값 — Gauge와 topk

```promql
topk(3, sum by (pod) (container_memory_working_set_bytes{namespace="shop", container!=""}))
```

**이 쿼리는**: shop 컨테이너 메모리(지금 값)를 파드별로 합친 뒤 큰 3개만 남김. 메모리는 늘었다 줄었다 하는 **지금 값**(gauge)이라 `rate` 없이 씁니다. `container!=""` = 컨테이너 이름이 빈 줄(파드 전체 합계 줄)은 빼기.

**이렇게 나오면 성공**: 세 줄, 맨 위가 adservice(약 1.4억 바이트 = 약 137Mi).

| 지표 종류 | 예 | 쓰는 법 |
|---|---|---|
| counter (누적, 줄지 않음) | `istio_requests_total` | `rate()` / `increase()`를 씌워서 |
| gauge (지금 값) | `container_memory_working_set_bytes` | 그대로 |
| histogram (구간별 개수) | `istio_request_duration_milliseconds_bucket` | `histogram_quantile()` |

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 값이 두 배쯤 크게 나옴 | `container!=""`를 빠뜨려 파드 합계 줄이 섞임 | `container!=""` 넣기 |

</details>

## 끝났는지 확인
- ☐ 1단계에서 사이드카 안에는 숫자가 있고 Prometheus에는 없는 것을 봄
- ☐ Target health에 `podMonitor/todo/istio-sidecars/0` 4개 `UP`
- ☐ 4단계 rate가 1 근처
- ☐ 6단계 p95가 서비스마다 숫자로 나옴

## 정리
- `~/mon/istio-podmonitor.yaml`과 PodMonitor는 남겨 둡니다(실습 5·6·7에서 씀)

## 확인 문제
1. todo에서 **보낸 쪽**(`reporter="source"`)으로 센 초당 요청 수를 보낸 서비스(`source_workload`)별로 구해 보세요. 어떤 서비스가 나오나요?
2. 5단계 첫 쿼리에서 `sum by`를 빼고 `rate(…)`만 남기면 줄이 몇 개 나오나요? 왜 늘어나나요?
