[← 실습 6](./06-Loki와-LogQL.md) · [목차](../모니터링-실습.md) · [실습 8 →](./08-경보와-SLO.md)

# 실습 7. 한 요청이 지나간 길 — Tempo

**무엇을 하나요**: 손님 요청 **하나**가 어느 서비스를 어떤 순서로 몇 ms씩 거쳤는지 보는 **트레이스**를 켭니다. 먼저 지표와 로그만으로는 "주문 한 번에 걸린 52ms를 누가 썼나"에 답할 수 없는 것을 봅니다. 트레이스를 저장하는 **Tempo**를 설치하고, Istio 사이드카가 요청마다 기록(스팬)을 만들어 Tempo로 보내게 한 뒤, Grafana에서 todo 요청 하나와 쇼핑몰 주문 하나를 읽습니다. 마지막에 **이어지지 않은 트레이스**를 찾아 이유를 봅니다. (교안 07장)

**필요한 것**: 실습 6까지, [미션 1](../미션/01-shop-골든-시그널-대시보드.md)의 과제 1(shop 사이드카 지표 — 1단계에서 씀), 브라우저의 Grafana 화면.

> **바로 가기** · [1. 트레이스 없이 — 누가 시간을 썼나 모름](#1단계-트레이스-없이--누가-시간을-썼나-모름) · [2. Tempo 설치 — make tracing](#2단계-tempo-설치--make-tracing) · [3. Istio에 보낼 곳 등록](#3단계-istio에-보낼-곳-등록) · [4. 추적 켜기 — Telemetry](#4단계-추적-켜기--telemetry) · [5. todo 요청 하나 보기](#5단계-todo-요청-하나-보기) · [6. 쇼핑몰 주문 하나 읽기](#6단계-쇼핑몰-주문-하나-읽기) · [7. 이어지지 않은 트레이스](#7단계-이어지지-않은-트레이스) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 트레이스 없이 — 누가 시간을 썼나 모름

쇼핑몰에서 **주문**(`/cart/checkout`) 한 번이 얼마나 걸렸는지 로그에서 찾습니다.

```bash
kubectl -n shop logs deploy/frontend | grep '"http.req.path":"/cart/checkout"' | grep "request complete" | tail -1
```

**이 명령은**: frontend 로그에서 주문 요청이 끝난 줄 중 마지막 하나.

**이렇게 나오면 성공**

```
{"http.req.id":"ac824bae-…","http.req.method":"POST","http.req.path":"/cart/checkout",…,"http.resp.status":200,"http.resp.took_ms":52,"message":"request complete",…}
```

이번에는 Prometheus **Query**에 서비스별 p95를 넣습니다(미션 1의 사이드카 지표).

```promql
histogram_quantile(0.95, sum by (le, destination_workload) (rate(istio_request_duration_milliseconds_bucket{reporter="destination", namespace="shop"}[5m])))
```

**이렇게 나오면 성공**: checkoutservice 약 66, frontend 약 50, recommendationservice 약 9 … (ms)

| 묻고 싶은 것 | 로그 | 지표 | 트레이스 (4단계부터) |
|---|---|---|---|
| 주문 한 번에 몇 ms | 52ms (frontend 합계만) | — | 52ms와 그 안의 구간 |
| 그 52ms 중 checkout은? 결제(payment)는? | 없음 | 서비스마다 p95 — 다른 요청들의 값 | 같은 요청의 checkout 구간, payment 구간 |
| frontend가 누구를 어떤 순서로 불렀나 | 없음 | 없음 | 스팬 순서 그대로 |

## 2단계. Tempo 설치 — make tracing

```bash
cd ~/ktcloud-cloud-native-lab/lab
make tracing              # 약 30초
```

**이 명령은**: 트레이스를 저장하는 Tempo를 `monitoring` 네임스페이스에 설치합니다. 설정 파일은 `lab/monitoring/tempo-values.yaml`. Grafana에는 데이터 소스 `Tempo`가 실습 1 때 미리 등록돼 있습니다.

**이렇게 나오면 성공**

```
tempo-0                                                 1/1     Running   0          28s
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `make: *** No rule to make target 'tracing'.` | 저장소가 옛날 것(실습 1의 `git pull` 전) | `cd ~/ktcloud-cloud-native-lab && git pull && cd lab` 후 다시. Grafana에 Tempo 데이터 소스가 없으면 `make monitoring`도 한 번 더 |

</details>

## 3단계. Istio에 보낼 곳 등록

```bash
cat monitoring/istio-tracing.yaml
istioctl install -f istio/istio.yaml -f monitoring/istio-tracing.yaml -y
kubectl -n istio-system get cm istio -o jsonpath='{.data.mesh}' | grep -A4 extensionProviders
```

**이 명령은**: 첫 줄 = 덧붙일 설정 내용 보기. 둘째 줄 = 서비스 메시 과목에서 설치한 설정(`istio/istio.yaml`) 위에 **스팬 보낼 곳**을 덧붙여 다시 설치(이미 있는 것은 그대로). 셋째 줄 = 메시 설정에 들어갔는지 확인.

**이렇게 나오면 성공**

```
spec:
  meshConfig:
    extensionProviders:
    - name: tempo
      opentelemetry:
        service: tempo.monitoring.svc.cluster.local
        port: 4317
...
✔ Installation complete
extensionProviders:
- name: tempo
  opentelemetry:
    port: 4317
    service: tempo.monitoring.svc.cluster.local
```

- 이것은 **이름 등록**까지입니다("tempo라는 곳이 4317번에 있다"). 아직 아무 스팬도 보내지 않습니다

## 4단계. 추적 켜기 — Telemetry

```bash
cd ~/mon && nano tracing.yaml
```

```yaml
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: mesh-default
  namespace: istio-system
spec:
  tracing:
  - providers:
    - name: tempo
    randomSamplingPercentage: 100
```

| 줄 | 뜻 |
|---|---|
| `kind: Telemetry` | Istio 리소스 — 사이드카가 무엇을 기록할지 |
| `namespace: istio-system` | Istio의 기본 네임스페이스에 두면 **메시 전체**(todo·shop 모두)에 적용 |
| `providers: - name: tempo` | 3단계에서 등록한 이름 |
| `randomSamplingPercentage: 100` | 요청의 100%를 기록(실습용 — 운영에서는 일부만) |

```bash
kubectl apply -f tracing.yaml
```

**이렇게 나오면 성공**: `telemetry.telemetry.istio.io/mesh-default created`. 1분 안에 Tempo에 트레이스가 쌓이기 시작합니다(5단계에서 확인).

## 5단계. todo 요청 하나 보기

Grafana → **Explore** → 데이터 소스 **Tempo** → 쿼리 종류 **TraceQL** → 아래를 넣고 **Run query**.

```traceql
{resource.service.name="api.todo"}
```

**이 쿼리는**: 스팬 중에 서비스 이름이 `api.todo`(네임스페이스 todo의 api)인 것이 들어 있는 트레이스.

**이렇게 나오면 성공**: 트레이스 목록(Root service `load.todo`, 4~7ms). 하나를 누르면 오른쪽에 막대 4개가 계단처럼.

| 스팬 (위에서부터) | 누가 만든 것 | 걸린 시간 (강사 VM) |
|---|---|---|
| `load.todo` → `web.todo…:80` (CLIENT) | 손님 load의 사이드카 — 보낼 때 | 5.5ms |
| `web.todo` ← (SERVER) | web의 사이드카 — 받을 때 | 4.6ms |
| `web.todo` → `api.todo…:3000` (CLIENT) | web의 사이드카 — api에 보낼 때 | 3.4ms |
| `api.todo` ← (SERVER) | api의 사이드카 — 받을 때 | 2.7ms |

- 요청 하나가 `load → web → api`를 지나간 길이 한 화면에 보입니다. 아래 막대는 위 막대 **안에** 들어 있습니다 — api가 2.7ms를 쓰는 동안 web은 기다렸습니다
- db는 PostgreSQL(HTTP가 아님)이라 스팬이 없습니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 데이터 소스 목록에 Tempo가 없음 | 실습 1을 옛 저장소로 설치함 | `git pull` 후 `make monitoring` |
| `No data` / 빈 목록 | 4단계 직후, 또는 시간 범위가 과거 | 1분 뒤, 오른쪽 위 Last 15 minutes |
| Tempo 데이터 소스 오류 `connection refused` | 2단계를 안 함 | `make tracing` |

</details>

## 6단계. 쇼핑몰 주문 하나 읽기

```traceql
{span.http.url =~ ".*cart/checkout.*"}
```

**이 쿼리는**: 주소에 `cart/checkout`(주문)이 든 스팬이 있는 트레이스.

**이렇게 나오면 성공**: Root service `loadgenerator.shop`, 50~60ms 트레이스. 하나를 열면 스팬이 30개 넘게 계단으로.

| 구간 (강사 VM 한 트레이스, 스팬 36개 · 58ms) | 걸린 시간 |
|---|---|
| frontend가 받은 주문 요청 전체 | 57.5ms |
| └ frontend → checkoutservice `PlaceOrder` | 31.6ms |
| 　└ checkout → cart `GetCart` · productcatalog `GetProduct` 2번 · shipping `GetQuote` · payment `Charge` · shipping `ShipOrder` · cart `EmptyCart` · email `SendOrderConfirmation` | 각 1.5~4.8ms, **차례로** |
| └ frontend → recommendation(→ productcatalog) · productcatalog 5번 · currency | 각 1~7ms |

- 주문 한 번에 checkout이 **다른 서비스 다섯 곳을 차례로** 부르는 것, 그 시간이 더해져 31.6ms가 된 것이 보입니다. 1단계의 로그(52ms 합계)와 지표(서비스별 p95)로는 볼 수 없던 것입니다

## 7단계. 이어지지 않은 트레이스

4단계에서 켠 지 몇 분 지난 뒤 넣습니다.

```traceql
{rootServiceName="checkoutservice.shop"}
```

**이 쿼리는**: 트레이스의 **맨 처음(뿌리) 스팬**을 checkoutservice가 만든 것. 손님 요청은 loadgenerator에서 시작하므로, 정상이라면 이런 트레이스는 없어야 합니다.

**이렇게 나오면 성공**: 몇 개가 나옴. 하나를 열면 스팬이 **2개**뿐 — checkout → currency `Convert`(1~2ms).

- 6단계 주문 트레이스에는 currency가 없었습니다. checkout은 주문 중에 currency(환율 변환)를 부르지만, 그 호출에는 **트레이스 번호를 넘기지 않아** 사이드카가 새 트레이스를 시작한 것입니다
- 사이드카는 스팬을 만들 뿐, 서비스 **안에서** 받은 번호를 다음 호출에 실어 보내는 것은 앱 코드의 일입니다. 앱이 번호를 넘기지 않는 곳에서는 트레이스가 끊깁니다

| | 번호를 넘기는 호출 (대부분) | 넘기지 않는 호출 (checkout → currency) |
|---|---|---|
| Tempo에서 | 한 트레이스 안의 계단 | 따로 떨어진 2스팬 트레이스, 뿌리가 checkout |
| 주문 한 번의 전체 시간 | 다 보임 | currency 구간이 빠져 보임 |

## 끝났는지 확인
- ☐ 1단계에서 로그는 합계만, 지표는 서비스별 값만 있는 것을 봄
- ☐ `tempo-0` `Running`, 3단계에서 `extensionProviders`에 `tempo`
- ☐ todo 트레이스에서 스팬 4개(load → web → api)를 봄
- ☐ 주문 트레이스에서 checkout이 여러 서비스를 차례로 부르는 것을 봄
- ☐ 뿌리가 checkoutservice인 2스팬 트레이스를 찾음

## 정리
- Tempo와 Telemetry는 남겨 둡니다(미션 2에서 씀)

## 확인 문제
1. 홈 화면(`/`) 요청의 트레이스를 찾아 currencyservice 스팬이 몇 개인지 세어 보세요. 왜 그렇게 많을까요? 힌트: `{span.http.url =~ ".*frontend/$"}`
2. 100ms보다 오래 걸린 트레이스를 찾는 TraceQL을 써 보세요. 지금은 몇 개인가요?
