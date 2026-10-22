[← 실습 4](./04-todo-api에-지표-달고-가져오기.md) · [목차](../모니터링-실습.md) · [실습 6 →](./06-Loki와-LogQL.md)

# 실습 5. todo 대시보드 만들기

**무엇을 하나요**: 실습 4의 todo-api 지표로 Grafana 대시보드를 직접 만듭니다. 패널은 셋 — 요청 수, p95 처리 시간, 5xx 비율. 5xx 비율은 `or vector(0)` 없이 먼저 넣어 `No data`가 나오는 것을 본 뒤 고칩니다. 마지막에 db를 멈춰 장애를 내고 대시보드가 어떻게 바뀌는지 본 뒤, JSON 파일로 내보냅니다. (교안 05장)

**필요한 것**: 실습 4의 ServiceMonitor(`serviceMonitor/todo/todo-api/0` UP), 브라우저의 Grafana 화면.

> **바로 가기** · [1. 새 대시보드와 요청 수 패널](#1단계-새-대시보드와-요청-수-패널) · [2. p95 패널](#2단계-p95-패널) · [3. 5xx 비율 — or vector(0) 없이 먼저](#3단계-5xx-비율--or-vector0-없이-먼저) · [4. 장애 내고 패널 보기](#4단계-장애-내고-패널-보기) · [5. 저장하고 JSON으로 내보내기](#5단계-저장하고-json으로-내보내기) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 새 대시보드와 요청 수 패널

Grafana → **Dashboards → New → New dashboard → Add visualization** → 데이터 소스 **Prometheus**.

아래쪽 쿼리 칸 오른쪽의 **Code**를 눌러 아래를 붙여 넣고 **Run queries**.

```promql
sum by (route, code) (rate(todo_http_requests_total[1m]))
```

오른쪽 설정에서 종류 **Time series**, 제목 `요청 수`, 쿼리 칸 아래 **Options → Legend**에 `{{route}} {{code}}`. 오른쪽 위 **Back to dashboard**.

**이렇게 나오면 성공**: 선 네 개 — `/api/todos 200`(약 1), `/metrics 200`(약 0.07), 실습 4에서 한 번씩 보낸 `POST`의 `/api/todos 400`·`/api/todos 201`(0 — 지금은 안 늘어나므로).

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 쿼리 칸에 붙여 넣기가 안 됨 | Builder 모드 | 쿼리 칸 오른쪽 **Code** |
| `No data` | 데이터 소스가 Prometheus가 아님, 또는 실습 4 대상이 DOWN | 위쪽 데이터 소스, Target health |

</details>

## 2단계. p95 패널

**Add → Visualization**으로 패널을 하나 더 만듭니다.

```promql
histogram_quantile(0.95, sum by (le) (rate(todo_http_request_duration_seconds_bucket{route="/api/todos"}[5m])))
```

종류 **Time series**, 제목 `p95 처리 시간`, 오른쪽 **Standard options → Unit**에서 **Time / seconds (s)**. **Back to dashboard**.

**이렇게 나오면 성공**: 선 하나, 약 `4.8 ms`로 표시.

## 3단계. 5xx 비율 — or vector(0) 없이 먼저

새 패널(종류 **Stat**, 제목 `5xx 비율`, Unit **Misc / Percent (0.0-1.0)**, **Thresholds**의 빨강 기준을 `0.1`)에 아래를 넣고 **Run queries**.

```promql
sum(rate(todo_http_requests_total{code=~"5.."}[1m])) / sum(rate(todo_http_requests_total[1m]))
```

**이 쿼리는**: 5xx 응답의 초당 수 ÷ 전체 초당 수 = 실패 비율. `code=~"5.."` = 5로 시작하는 세 자리.

**이렇게 나오면 성공**: 숫자 대신 **`No data`**. 실패가 하나도 없으니 0%여야 할 것 같은데 비어 있습니다 — 5xx 응답이 한 번도 없으면 앞쪽(분자) 결과가 0이 아니라 **아예 없고**, 없는 것을 나누면 결과도 없습니다.

같은 패널의 쿼리를 아래로 바꿉니다.

```promql
(sum(rate(todo_http_requests_total{code=~"5.."}[1m])) or vector(0)) / sum(rate(todo_http_requests_total[1m]))
```

**이렇게 나오면 성공**: `0%`(초록). **Back to dashboard**.

| | `or vector(0)` 없음 | 있음 |
|---|---|---|
| 5xx가 한 번도 없을 때 | `No data` — 고장인지 정상인지 모름 | `0%` |
| 5xx가 생겼을 때 | 비율이 나옴 | 비율이 나옴(같음) |

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `0.0500%`처럼 이상함 | Unit을 Percent (0-100)으로 고름 | Percent (0.0-1.0) |
| 바꾼 뒤에도 `No data` | 괄호 위치가 다름 | 둘째 쿼리 그대로 복사 |

</details>

## 4단계. 장애 내고 패널 보기

db를 0개로 줄여 todo에 장애를 냅니다. 대시보드 오른쪽 위 새로 고침을 **10s**로 두고 2분 지켜봅니다.

```bash
kubectl -n todo scale deploy db --replicas=0          # 장애 발생
kubectl -n todo exec deploy/load -c curl -- curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" http://web/api/todos
```

**이 명령은**: db 파드를 0개로 → api가 db에 못 붙음. 둘째 줄 = 손님 입장에서 응답 코드와 걸린 시간.

**이렇게 나오면 성공**: `500 0.02…s`, 1분쯤 뒤 패널이 바뀜.

| 패널 | 장애 1분 뒤 (강사 VM) |
|---|---|
| 요청 수 | `/api/todos 200` → 0, 새 선 `/api/todos 500` 약 1 |
| 5xx 비율 | **약 94%, 빨강** |
| p95 처리 시간 | 그대로 약 4.8ms — 느려지지 않음 |

- 장애인데 느려지지 않았습니다. api가 db에 연결하자마자 끊겨 **바로** 500을 돌려주기 때문입니다. 처리 시간만 보고 있었다면 이 장애를 놓칩니다. 왜 500인지는 실습 6에서 로그로 찾습니다

복구합니다.

```bash
kubectl -n todo scale deploy db --replicas=1          # 복구
kubectl -n todo rollout status deploy/db
kubectl -n todo exec deploy/load -c curl -- curl -s http://web/api/todos; echo
```

**이렇게 나오면 성공**: `successfully rolled out`, 할 일 목록이 그대로(`[{"id":1,"title":"모니터링 공부"},{"id":2,"title":"지표 달기"}]`). 1~2분 뒤 5xx 비율이 `0%` 초록으로 돌아옴.

## 5단계. 저장하고 JSON으로 내보내기

오른쪽 위 **Save dashboard** → 이름 `todo-api` → **Save**. 이어서 **Export → Export as JSON** → **Download file**.

**이렇게 나오면 성공**: 내 PC에 `.json` 파일이 생김.

- 대시보드는 JSON 파일입니다. 파일을 Git에 두면 누구나 **Dashboards → New → Import**로 같은 화면을 가져올 수 있습니다. 미션 1에서 씁니다

## 끝났는지 확인
- ☐ 패널 세 개(요청 수 · p95 처리 시간 · 5xx 비율)가 있는 대시보드 `todo-api` 저장
- ☐ 3단계에서 `No data` → `0%`를 봄
- ☐ 4단계에서 5xx 비율이 빨개지고 p95는 그대로인 것을 봄
- ☐ db를 `--replicas=1`로 되돌림, JSON 파일을 내려받음

## 정리
- **db는 꼭 1개로 되돌립니다.** 대시보드는 남겨 둡니다

## 확인 문제
1. 4단계 장애 중 5xx 비율이 100%가 아니라 약 94%였습니다. 실패하지 않은 6%는 어떤 요청일까요? 1단계 패널에서 찾아보세요.
2. 5xx 비율 쿼리를 `/api/todos` 경로만 보도록 고쳐 보세요. 장애 중에는 몇 %가 될까요?
