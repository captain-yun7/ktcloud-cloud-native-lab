[← 실습 7](./07-한-요청이-지나간-길-Tempo.md) · [목차](../모니터링-실습.md) · [미션 2 →](../미션/02-장애-찾기-지표-로그-트레이스.md)

# 실습 8. 경보와 SLO

**무엇을 하나요**: 먼저 경보 없이 쇼핑몰에 장애를 내서 **아무도 알려 주지 않는** 것을 봅니다. 그다음 "frontend 5xx 비율이 1분 동안 10%를 넘으면" 켜지는 **경보 규칙**, 경보를 보낼 **길**, 받는 **곳**을 만들고, "요청의 99.5% 성공" 목표(**SLO**)의 **오류 예산 소진 속도**를 새 지표로 만듭니다. 같은 장애를 한 번 더 내서 경보가 켜지고 받는 곳에 도착하는 것, 소진 속도는 치솟는데 CPU는 오히려 줄어드는 것을 봅니다. (교안 08장)

**필요한 것**: 실습 6의 Loki, [미션 1](../미션/01-shop-골든-시그널-대시보드.md)의 과제 1(shop 사이드카 지표), `~/mon` 폴더.

**화면이 헷갈리면**: [실습 8 화면 가이드](./08-화면-가이드.md) — Rule health·Alerts 탭(pending → firing)·Alertmanager 실제 화면과 볼 곳(빨간 네모)

| 용어 | 뜻 | 예 |
|---|---|---|
| SLI | 재는 숫자 | frontend 요청 중 5xx가 아닌 비율 |
| SLO | 목표 | 한 달 99.5% |
| 오류 예산 | 목표가 허락하는 실패량 | 0.5% — 한 달 약 3.6시간 |
| 소진 속도 | 예산을 쓰는 빠르기 | 1 = 딱 한 달에 다 씀, 10 = 3일 만에 다 씀 |

> **바로 가기** · [1. 경보 없이 장애 내 보기](#1단계-경보-없이-장애-내-보기) · [2. 받는 곳·규칙·보내는 길 쓰기](#2단계-받는-곳규칙보내는-길-쓰기) · [3. SLO 기록 규칙 쓰기](#3단계-slo-기록-규칙-쓰기) · [4. 적용하고 평소 값 보기](#4단계-적용하고-평소-값-보기) · [5. 장애 내기 — 경보와 소진 속도](#5단계-장애-내기--경보와-소진-속도) · [6. 받는 곳 도착과 장애 로그](#6단계-받는-곳-도착과-장애-로그) · [7. 복구와 해제 알림](#7단계-복구와-해제-알림) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 경보 없이 장애 내 보기

지금은 기본 규칙만 있습니다. 이 상태에서 쇼핑몰에 장애를 내면 누가 알려 주는지 봅니다.

```bash
kubectl -n shop scale deploy productcatalogservice --replicas=0      # 장애 발생
```

**이 명령은**: 상품 목록 서비스 파드를 0개로 → frontend가 상품을 못 가져와 500을 냄. 브라우저로 `shop.localhost:<포트>`를 열어 보면 오류 화면이 나옵니다.

**1분 30초쯤 기다린 뒤** 확인합니다.

```bash
curl -s prometheus.localhost/api/v1/alerts | grep -o '"alertname":"[A-Za-z]*"'
curl -s alertmanager.localhost/api/v2/alerts | grep -o '"alertname":"[A-Za-z]*"'
```

**이 명령은**: Prometheus에 켜진 경보, Alertmanager에 받은 경보를 물어보고 이름만 뽑음. 브라우저의 Prometheus **Alerts** 탭, Alertmanager 화면과 같은 내용입니다.

**이렇게 나오면 성공**

```
"alertname":"Watchdog"
"alertname":"Watchdog"
```

지표에는 장애가 찍혀 있습니다. Prometheus **Query**에 넣어 봅니다.

```promql
sum(rate(istio_requests_total{reporter="destination", destination_workload="frontend", response_code=~"5.."}[1m])) / sum(rate(istio_requests_total{reporter="destination", destination_workload="frontend"}[1m]))
sum(rate(container_cpu_usage_seconds_total{namespace="shop", container!=""}[1m]))
```

**이렇게 나오면 성공**: 첫째 `0.8` 근처 — frontend가 받은 요청의 약 80%가 실패. 둘째(shop 전체 CPU)는 장애 전보다 **작음**.

| | 경보 규칙 없음 (지금) | 경보 규칙 있음 (5단계) |
|---|---|---|
| 장애를 아는 때 | 누군가 대시보드를 열어 볼 때, 또는 손님이 알려 줄 때 | 장애 후 약 2분에 받는 곳으로 알림 |
| 켜진 경보 | Watchdog뿐 | `FrontendErrorRateHigh` firing |
| CPU로 알 수 있나 | 오히려 줄어듦(118m → 50m) — CPU 경보는 안 켜짐 | 성공 비율로 검사 |

복구합니다.

```bash
kubectl -n shop scale deploy productcatalogservice --replicas=1      # 복구
kubectl -n shop rollout status deploy/productcatalogservice
```

**이렇게 나오면 성공**: `deployment "productcatalogservice" successfully rolled out`

## 2단계. 받는 곳·규칙·보내는 길 쓰기

파일 세 개를 씁니다.

```bash
cd ~/mon && nano alert-echo.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata: {name: alert-echo, namespace: monitoring}
spec:
  selector: {matchLabels: {app: alert-echo}}
  template:
    metadata: {labels: {app: alert-echo}}
    spec:
      containers:
      - name: echo
        image: mendhak/http-https-echo:42
        env: [{name: HTTP_PORT, value: "8080"}]
        ports: [{containerPort: 8080}]
---
apiVersion: v1
kind: Service
metadata: {name: alert-echo, namespace: monitoring}
spec:
  selector: {app: alert-echo}
  ports: [{name: http, port: 8080}]
```

**이 파일은**: 받은 요청을 그대로 로그로 찍는 echo 서버(Deployment + Service). 회사에서는 이 자리가 Slack·메일입니다. `{…}`·`[…]`는 같은 내용을 한 줄로 줄여 쓴 YAML입니다.

```bash
nano frontend-rule.yaml
```

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: shop-alerts
  namespace: shop
spec:
  groups:
  - name: shop
    rules:
    - alert: FrontendErrorRateHigh
      expr: |
        sum(rate(istio_requests_total{reporter="destination", destination_workload="frontend", response_code=~"5.."}[1m]))
          / sum(rate(istio_requests_total{reporter="destination", destination_workload="frontend"}[1m])) > 0.1
      for: 1m
      labels:
        severity: lab
      annotations:
        summary: "frontend 5xx 비율 {{ $value | humanizePercentage }}"
```

| 줄 | 뜻 |
|---|---|
| `alert: FrontendErrorRateHigh` | 경보 이름 |
| `expr:` | 조건 — 1단계 첫 쿼리 뒤에 `> 0.1`(10%보다 크면) |
| `for: 1m` | 조건이 **1분 동안 계속** 맞아야 켜짐 — 잠깐 튄 값으로 사람을 깨우지 않기 위해 |
| `labels: severity: lab` | 이름표. 다음 파일에서 이 이름표로 보낼 곳을 고름 |

```bash
nano alertmanager-config.yaml
```

```yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: AlertmanagerConfig
metadata:
  name: lab
  namespace: monitoring
spec:
  route:
    receiver: echo
    matchers:
    - name: severity
      value: lab
    groupWait: 10s
    repeatInterval: 5m
  receivers:
  - name: echo
    webhookConfigs:
    - url: http://alert-echo.monitoring:8080/
      sendResolved: true
```

**이 파일은**: `severity=lab` 경보를 echo 서버(`alert-echo.monitoring:8080`)로 보내라. `groupWait: 10s` = 첫 경보를 10초 모았다가 보냄, `repeatInterval: 5m` = 계속 켜져 있으면 5분마다 다시, `sendResolved: true` = 경보가 풀렸을 때도 알림.

## 3단계. SLO 기록 규칙 쓰기

```bash
nano slo-rules.yaml
```

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: shop-slo
  namespace: shop
spec:
  groups:
  - name: shop-slo
    rules:
    - record: shop:frontend_availability:ratio_rate5m
      expr: |
        sum(rate(istio_requests_total{reporter="destination", destination_workload="frontend", response_code!~"5.."}[5m]))
          / sum(rate(istio_requests_total{reporter="destination", destination_workload="frontend"}[5m]))
    - record: shop:frontend_error_budget_burn:rate5m
      # 1 = 예산을 딱 한 달에 다 쓰는 속도. 10 = 열 배 빠르게 쓰는 중
      expr: (1 - shop:frontend_availability:ratio_rate5m) / (1 - 0.995)
```

**이 파일은**: `record:` = 계산 결과를 **새 지표 이름으로 저장**(기록 규칙). 첫째 = 최근 5분 가용성(5xx가 **아닌** 비율 = SLI). 둘째 = 소진 속도 = (1 − 가용성) ÷ 오류 예산 0.005.

## 4단계. 적용하고 평소 값 보기

```bash
kubectl apply -f alert-echo.yaml -f frontend-rule.yaml -f alertmanager-config.yaml -f slo-rules.yaml
```

**이렇게 나오면 성공**: `… created` 다섯 줄(deployment, service, prometheusrule 2개, alertmanagerconfig).

**5분쯤 기다리는 동안**(1단계 장애가 5분 창에서 빠지고, Alertmanager가 새 길을 읽음) Prometheus **Alerts** 탭에서 `FrontendErrorRateHigh`가 **inactive**(꺼짐)인 것을 보고, **Query**에 넣어 봅니다.

```promql
shop:frontend_availability:ratio_rate5m
shop:frontend_error_budget_burn:rate5m
```

**이렇게 나오면 성공**: 가용성 `1` 근처, 소진 속도 `0`~`1` 사이(1단계 장애가 창 끝에 남아 있으면 조금 큼).

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `no matches for kind "AlertmanagerConfig"` | apiVersion 오타 | `monitoring.coreos.com/v1alpha1`(이것만 v1alpha1) |
| Alerts 탭에 `FrontendErrorRateHigh`가 없음 | 규칙 반영 전, 또는 `expr` 들여쓰기 깨짐 | 1분 뒤, **Status → Rule health**에 `shop-alerts`가 있는지, `cat frontend-rule.yaml` |
| 기록 규칙이 `Empty query result` | 반영 전, 이름 오타(`:`를 `_`로) | 1분 뒤, Rule health에서 이름 복사 |

</details>

## 5단계. 장애 내기 — 경보와 소진 속도

```bash
kubectl -n shop scale deploy productcatalogservice --replicas=0      # 장애 발생
```

Prometheus **Alerts** 탭을 몇 번 새로 고치고, **Query**에서 **Add query**로 칸을 두 개 만들어 아래를 넣고 **1분마다 Execute** — 3분 동안 표를 채웁니다.

```promql
shop:frontend_error_budget_burn:rate5m
sum(rate(container_cpu_usage_seconds_total{namespace="shop", container!=""}[5m]))
```

**이렇게 나오면 성공**: `FrontendErrorRateHigh`가 **inactive → pending → firing**, 소진 속도는 치솟고 CPU는 줄어듦.

| 장애 뒤 | 경보 (강사 VM) | 가용성 | 소진 속도 | shop CPU (5m) | 내 값 |
|---|---|---|---|---|---|
| 0초 | inactive | 0.996 | 0.8 | 0.137 | |
| 51초 | **pending** | | | | |
| 1분 | pending | 0.90 | 20 | 0.118 | |
| 1분 53초 | **firing** | | | | |
| 2분 | firing | 0.72 | 55 | 0.102 | |
| 3분 | firing | 0.56 | **88** | 0.087 | |

- 소진 속도 88 = 한 달 치 오류 예산을 **약 8시간**(30일 ÷ 88) 만에 다 쓰는 속도입니다. 그런데 CPU는 **줄었습니다**
- 소진 속도가 1분마다 조금씩 오르는 까닭은 `rate5m` = 최근 **5분**의 비율이라, 장애 구간이 5분 창을 조금씩 채우기 때문입니다

| 단계 | 뜻 |
|---|---|
| pending | 조건은 맞았다, `for: 1m` 기다리는 중 |
| firing | 1분 동안 계속 맞았다 → Alertmanager로 넘김 |

## 6단계. 받는 곳 도착과 장애 로그

firing이 되고 10~20초 뒤 echo 서버 로그를 봅니다.

```bash
kubectl -n monitoring logs deploy/alert-echo | grep -o '"alertname": "[A-Za-z]*"' | sort | uniq -c
```

**이 명령은**: echo 서버 로그에서 경보 이름만 뽑아(`grep -o`) 개수를 셈(`sort | uniq -c`). `"alertname":` 뒤에 띄어쓰기 한 칸이 있습니다 — echo 서버가 받은 내용을 보기 좋게 줄 바꿔 찍기 때문입니다.

**이렇게 나오면 성공** (앞의 숫자는 사람마다 다름 — 알림 한 번에 이름이 두 번 들어 있어 2부터)

```
      2 "alertname": "FrontendErrorRateHigh"
```

Grafana Explore(Loki)에서 장애 동안의 500 로그를 찾습니다(실습 6의 5단계와 같은 방법).

```logql
{namespace="shop", app="frontend"} | json | http_resp_status >= 500
```

**이렇게 나오면 성공**: 500 로그 줄이 여러 개(강사 VM 최근 10분 583줄). 이 줄에는 "500을 돌려줬다"까지만 있습니다. **왜**는 같은 요청 번호로 남긴 오류 줄에 있습니다.

```logql
{namespace="shop", app="frontend"} | json | severity="error"
```

**이렇게 나오면 성공**: `"message":"request error"` 줄, `"error"` 필드에 예를 들어 `could not retrieve product: rpc error: code = Unavailable desc = no healthy upstream` — 상품(product)을 가져오려는데 받아 줄 파드가 하나도 없다(`no healthy upstream`).

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 3분이 지나도 inactive | 장애를 안 냈거나 loadgenerator가 멈춤 | `kubectl -n shop get pods` |
| firing인데 echo 로그에 없음 | Alertmanager가 새 길을 아직 안 읽음, 또는 `severity: lab` 오타 | Alertmanager 화면에 경보가 있는지 → 있으면 `alertmanager-config.yaml`의 `url`·`matchers` |
| `error: … deployments.apps "alert-echo" not found` | 다른 네임스페이스에 만듦 | `-n monitoring` |

</details>

## 7단계. 복구와 해제 알림

```bash
kubectl -n shop scale deploy productcatalogservice --replicas=1      # 복구
kubectl -n shop rollout status deploy/productcatalogservice
```

3~4분 뒤 echo 로그에서 상태를 봅니다.

```bash
kubectl -n monitoring logs deploy/alert-echo | grep -o '"status": "[a-z]*"' | sort | uniq -c
```

**이렇게 나오면 성공**: `firing`과 `resolved`가 둘 다.

```
      2 "status": "firing"
      2 "status": "resolved"
```

| 복구 뒤 (강사 VM) | 경보 | 소진 속도 |
|---|---|---|
| 1분 | firing | 118 |
| 2분 | 꺼짐 | 105 |
| 3분 38초 | echo에 **resolved** 도착 | |
| 4분 | | 34 |
| 6분 | | **0** |

- 경보는 2분 안에 꺼지지만 소진 속도는 약 6분 걸려 0 근처로 돌아옵니다. 기록 규칙이 최근 **5분** 창이라 장애 구간이 창에서 다 빠져야 하기 때문입니다. 쇼핑몰은 평소에도 가끔 500을 내서 0이 아니라 0.2~0.3에 머물 수도 있습니다

## 끝났는지 확인
- ☐ 1단계에서 장애 중에도 켜진 경보가 Watchdog뿐이고 CPU는 줄어든 것을 봄
- ☐ 5단계에서 `FrontendErrorRateHigh`가 pending → firing, 소진 속도 표를 채움
- ☐ echo 로그에 `"alertname": "FrontendErrorRateHigh"`, 그리고 `"status": "resolved"`
- ☐ productcatalogservice를 `--replicas=1`로 되돌림

## 정리
- **productcatalogservice는 꼭 1개로 되돌립니다.** echo 서버·규칙·보내는 길은 남겨 둡니다(미션 2에서 씀)

## 확인 문제
1. **느려졌을 때** 알리는 경보 `FrontendLatencyHigh`를 만들어 보세요 — frontend의 p95 지연이 1분 동안 500ms를 넘으면 켜지고 echo로 갑니다. 파일 이름은 `~/mon/latency-rule.yaml`. 힌트: `frontend-rule.yaml`을 복사해 `metadata.name`, `alert`, `expr`만 바꿉니다. p95 식은 실습 3의 6단계.
2. 목표가 99.9%라면 한 달(30일) 오류 예산은 몇 분일까요? 5단계 3분의 실패율(가용성 0.56)이라면 소진 속도는 얼마가 될까요?
