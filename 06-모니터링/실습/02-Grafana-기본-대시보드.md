[← 실습 1](./01-kube-prometheus-stack-설치와-Prometheus-둘러보기.md) · [목차](../모니터링-실습.md) · [실습 3 →](./03-PromQL-기본.md)

# 실습 2. Grafana 기본 대시보드

**무엇을 하나요**: 먼저 Prometheus 화면만으로 그래프를 그려 보고 무엇이 불편한지 본 뒤, Grafana에 미리 들어 있는 대시보드로 todo·shop 파드와 노드를 보고, 그래프 뒤에 숨은 PromQL을 확인합니다. (교안 02장)

**필요한 것**: 실습 1의 설치, 브라우저의 Prometheus 화면과 Grafana 화면(`admin` / `lab-grafana`).

> **바로 가기** · [1. Grafana 없이 — Prometheus 화면으로 그리기](#1단계-grafana-없이--prometheus-화면으로-그리기) · [2. 대시보드 목록](#2단계-대시보드-목록) · [3. 네임스페이스별 파드 CPU·메모리](#3단계-네임스페이스별-파드-cpu메모리) · [4. 노드 3개](#4단계-노드-3개) · [5. 그래프 뒤의 PromQL 보기](#5단계-그래프-뒤의-promql-보기) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. Grafana 없이 — Prometheus 화면으로 그리기

Prometheus 화면만으로도 그래프는 그려집니다. **Query** 탭 입력 칸에 아래를 붙여 넣고 **Execute** → 위쪽 **Graph** 탭.

```promql
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="todo", container!=""}[5m]))
```

**이 쿼리는**: todo 파드마다 지금 쓰는 CPU(코어 수). 뜻은 실습 3에서 하나씩 풉니다 — 지금은 붙여 넣기만 합니다.

**이렇게 나오면 성공**: 파드마다 선이 하나씩, **4줄**(api·db·load·web).

이번에는 메모리도 같이 보고 싶다고 합시다. 입력 칸의 쿼리를 지우고 실습 1의 `container_memory_working_set_bytes{namespace="todo", container!=""}`를 넣으면 CPU 그래프는 사라집니다. 둘을 같이 보려면 쿼리 칸을 하나 더 추가해 다시 쳐야 하고, 화면을 닫으면 다음에 또 쳐야 합니다.

| | Prometheus 화면만 | Grafana 기본 대시보드 (2~4단계) |
|---|---|---|
| 쿼리 | 볼 때마다 입력 | 패널에 **저장**돼 있음 — 열기만 하면 됨 |
| 한 화면 | 쿼리 칸을 하나씩 추가 | 대시보드 하나에 패널 **18개**(CPU·메모리·네트워크 …) |
| 네임스페이스 바꾸기 | 쿼리 안의 `todo`를 고쳐 다시 Execute | 위쪽 `namespace` 칸에서 고르기 |
| 남과 같이 보기 | 주소 복사 | 대시보드 링크, JSON 파일(실습 5) |

- Prometheus 화면은 **숫자를 꺼내 확인하는 곳**, Grafana는 **자주 볼 그래프를 저장해 두고 여러 사람이 보는 곳**입니다

## 2단계. 대시보드 목록

Grafana 왼쪽 메뉴 **Dashboards**를 엽니다.

**이렇게 나오면 성공**: 기본 대시보드가 25개 보입니다.

## 3단계. 네임스페이스별 파드 CPU·메모리

**Kubernetes / Compute Resources / Namespace (Pods)**를 열고, 위쪽 `namespace` 칸에서 `todo`를 고릅니다. 이어서 `shop`으로 바꿔 봅니다.

**이렇게 나오면 성공**: 고른 네임스페이스의 파드별 CPU·메모리 그래프가 나오고, 칸을 바꾸면 그래프 전체가 바뀝니다.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 그래프가 `No data` | 고른 namespace가 다름, 또는 시간 범위가 너무 짧음 | `namespace` 칸 확인, 오른쪽 위 시간 범위를 `Last 1 hour`로 |
| 로그인이 안 됨 | 비밀번호 오타 | `admin` / `lab-grafana` |

</details>

## 4단계. 노드 3개

**Node Exporter / Nodes**를 열고 위쪽 `instance` 칸에서 노드를 바꿔 봅니다.

**이렇게 나오면 성공**: 노드마다 CPU·메모리·디스크 그래프. `instance` 칸에 주소가 3개.

## 5단계. 그래프 뒤의 PromQL 보기

3단계 대시보드에서 아무 그래프(패널)에 마우스를 올리고 키보드 **e**(Edit)를 누릅니다.

**이렇게 나오면 성공**: 아래쪽에 그 그래프를 그리는 PromQL이 보입니다. 오른쪽 위 **Back to dashboard**(또는 **Discard**)로 돌아갑니다 — 기본 대시보드는 저장하지 않습니다.

- 대시보드는 PromQL의 결과를 그림으로 보여 주는 것입니다. 실습 3에서 PromQL을 직접 씁니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| **e**를 눌러도 아무 일 없음 | 마우스가 패널 위에 없음 | 패널 제목 오른쪽 메뉴(⋮) → Edit |
| 나갈 때 저장하라고 물음 | 패널을 조금 바꿈 | **Discard** |

</details>

## 끝났는지 확인
- ☐ Prometheus 화면에서 todo CPU 4줄을 그려 봄
- ☐ Namespace (Pods) 대시보드에서 todo ↔ shop을 바꿔 봄
- ☐ 패널 하나에서 e를 눌러 PromQL을 봄

## 정리
- 바꾼 대시보드는 저장하지 않습니다

## 확인 문제
1. Kubernetes / Compute Resources / Namespace (Pods)의 shop 메모리 그래프에서 메모리를 가장 많이 쓰는 파드는 무엇인가요?
