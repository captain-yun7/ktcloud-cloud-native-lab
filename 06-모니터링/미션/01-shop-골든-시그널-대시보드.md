[목차](../모니터링-미션.md) · [미션 2 →](./02-장애-찾기-지표-로그-트레이스.md)

# 미션 1. shop 골든 시그널 대시보드

**상황**: todo는 서비스가 셋이라 실습 5의 대시보드로 충분했습니다. 쇼핑몰(Online Boutique)은 서비스가 11개이고, 앱이 Prometheus 지표를 **하나도** 내지 않습니다. 그래도 **서비스마다 요청 수·오류·지연**을 한 화면에서 봐야 합니다. 방법이 있습니다 — 실습 3에서 본 것처럼 파드마다 붙은 **Istio 사이드카**가 모든 요청을 세고 있습니다.

언제: 실습 5(05장) 뒤. 필요한 것: 실습 1~5.

> **바로 가기** · [과제 1. shop 사이드카 지표 수집](#과제-1-shop-사이드카-지표-수집) · [과제 2. 대시보드 `shop 골든 시그널`](#과제-2-대시보드-shop-골든-시그널) · [과제 3. 장애 때 빨개지는지](#과제-3-장애-때-빨개지는지) · [도전 A (선택). gRPC 서비스의 오류율](#도전-a-선택-grpc-서비스의-오류율) · [도전 B (선택). 포화 — 파드별 CPU 패널](#도전-b-선택-포화--파드별-cpu-패널) · [미션 1 결과 정리 표 (리뷰 때 함께 봄)](#미션-1-결과-정리-표-리뷰-때-함께-봄)

## 과제 1. shop 사이드카 지표 수집

shop의 사이드카 지표를 Prometheus가 가져가게 합니다. 확인: Prometheus **Target health**에 shop 사이드카 대상이 12개 `UP`, Query `sum by (destination_workload) (rate(istio_requests_total{reporter="destination", namespace="shop"}[1m]))`에 서비스 10개 안팎.

<details><summary>힌트 1 — 어디서 시작하나</summary>

실습 3의 2단계에서 만든 `~/mon/istio-podmonitor.yaml`은 `namespace: todo`라 todo 파드만 고릅니다. 같은 파일을 복사해 네임스페이스만 바꾸면 됩니다(`cp istio-podmonitor.yaml shop-podmonitor.yaml` → `nano`).
</details>

## 과제 2. 대시보드 `shop 골든 시그널`

대시보드를 새로 만들고 서비스 고르기 변수 `workload`(여러 개·전체 선택 가능)와 패널 세 개를 넣습니다. 저장한 뒤 JSON으로 내보냅니다(실습 5의 5단계).

| 패널 | 내용 |
|---|---|
| 서비스별 초당 요청 수 | Time series, 서비스마다 선 하나 |
| frontend 5xx 비율 | Stat, 10% 넘으면 빨강 |
| 서비스별 p95 지연(ms) | Time series |

<details><summary>힌트 2 — 어떤 지표를</summary>

`istio_requests_total`(요청 수, counter)과 `istio_request_duration_milliseconds_bucket`(지연, histogram) — 실습 3의 4~6단계. 받는 쪽 기준으로 세려면 `reporter="destination"`, 서비스 이름은 `destination_workload`. 실습 5의 세 쿼리에서 지표 이름과 이름표만 바꾸면 됩니다. 단위가 **ms**인 것에 주의합니다.
</details>
<details><summary>힌트 3 — 변수</summary>

Dashboard settings → Variables → New variable → Query: `label_values(istio_requests_total{namespace="shop"}, destination_workload)`. Multi-value·Include All 켜기. 쿼리에서는 `destination_workload=~"$workload"`.
</details>

## 과제 3. 장애 때 빨개지는지

productcatalog를 0개로 줄여 5xx 패널이 빨개지는 것을 확인하고 되돌립니다.

```bash
kubectl -n shop scale deploy productcatalogservice --replicas=0     # 장애
kubectl -n shop scale deploy productcatalogservice --replicas=1     # 복구
```

## 도전 A (선택). gRPC 서비스의 오류율

다른 서비스들의 오류율 패널도 만들어 보세요. 과제 3의 장애 중에 frontend 말고는 5xx가 잡히지 않습니다. 왜일까요?

## 도전 B (선택). 포화 — 파드별 CPU 패널

골든 시그널의 넷째 **포화**(얼마나 꽉 찼나)를 위해 shop 파드별 CPU 패널을 하나 더 넣어 보세요. 과제 3의 장애 중에 이 패널은 어떻게 움직이나요?

## 미션 1 결과 정리 표 (리뷰 때 함께 봄)

| # | 확인 | 내 결과 |
|---|---|---|
| 과제 1 | shop 사이드카 수집 대상 수, RPS 상위 3개 서비스 | |
| 과제 2 | 대시보드 화면(변수·패널 세 개), p95가 가장 큰 서비스 | |
| 과제 3 | 장애 중 5xx 비율 / 복구 뒤 | |
| 도전 A | 5xx가 안 잡히는 이유 | |
| 도전 B | 장애 중 CPU 패널의 움직임 | |
