[← 시작하기 전에](./00-시작하기-전에.md) · [목차](../모니터링-실습.md) · [실습 2 →](./02-Grafana-기본-대시보드.md)

# 실습 1. kube-prometheus-stack 설치와 Prometheus 둘러보기

**무엇을 하나요**: todo를 다시 띄우고, 서비스 메시 과목의 애드온을 지운 뒤, 지표를 모으는 **Prometheus**·그래프를 그리는 **Grafana**·경보를 보내는 **Alertmanager**를 한 번에 설치합니다. 설치 전에 `kubectl`만으로는 "5분 전에는 어땠나"에 답할 수 없다는 것을 먼저 봅니다. 설치 뒤에는 Prometheus 화면에서 무엇을 모으는지(Targets), 숫자를 어떻게 꺼내는지(Query), 켜진 경보가 있는지(Alerts)를 봅니다. (교안 01장)

**필요한 것**: 서비스 메시 과목의 클러스터([시작하기 전에 2](./00-시작하기-전에.md#2-클러스터가-떠-있는지-확인)), VM 도커의 이미지 `todo-api:v1`·`todo-web:v1`(Kubernetes 실습 7에서 만듦).

> **바로 가기** · [1. todo 다시 띄우기](#1단계-todo-다시-띄우기) · [2. Istio 애드온 지우기](#2단계-istio-애드온-지우기) · [3. 설치 전에 — 지금 값만 보임](#3단계-설치-전에--지금-값만-보임) · [4. 설치 — make monitoring](#4단계-설치--make-monitoring) · [5. 세 화면 열기](#5단계-세-화면-열기) · [6. 수집 대상 — Targets](#6단계-수집-대상--targets) · [7. 숫자 꺼내 보기와 켜진 경보](#7단계-숫자-꺼내-보기와-켜진-경보) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. todo 다시 띄우기

서비스 메시 과목 끝에서 지운 todo(web · api · db)를 다시 띄웁니다. 이번에는 처음부터 Istio 사이드카를 붙이고, 1초마다 할 일 목록을 부르는 손님 역할 파드 `load`도 함께 띄웁니다.

```bash
kind load docker-image todo-api:v1 todo-web:v1 --name lab
kubectl create ns todo
kubectl label ns todo istio-injection=enabled
kubectl apply -f ~/ktcloud-cloud-native-lab/03-클라우드-보안/todo.yaml
kubectl -n todo create deploy load --image=curlimages/curl:8.16.0 -- sh -c "while true; do curl -s -o /dev/null http://web/api/todos; sleep 1; done"
kubectl -n todo get pods
```

**이 명령은**: 첫 줄 = VM 도커의 todo 이미지 두 개를 클러스터 노드에 넣음. 둘째·셋째 줄 = 네임스페이스 `todo`를 먼저 만들고 "여기 파드에는 사이드카를 넣어라" 라벨을 붙임(파드가 생기기 **전에** 붙여야 처음부터 `2/2`). 넷째 줄 = 클라우드 보안 과목의 todo 매니페스트. 다섯째 줄 = 1초마다 `http://web/api/todos`를 부르는 손님.

**이렇게 나오면 성공**: 10초쯤 뒤 파드 4개 모두 `2/2 Running`.

```
namespace/todo created
namespace/todo labeled
Warning: resource namespaces/todo is missing the kubectl.kubernetes.io/last-applied-configuration annotation ...
namespace/todo configured
secret/todo-secret created
...
deployment.apps/load created
NAME                    READY   STATUS    RESTARTS   AGE
api-7bcdc699f-hhrqp     2/2     Running   0          7s
db-86878656ff-r78zn     2/2     Running   0          7s
load-75d7b4fccd-nk42r   2/2     Running   0          7s
web-5bdd6887b7-78g96    2/2     Running   0          7s
```

- `Warning: … last-applied-configuration …`은 둘째 줄에서 손으로 만든 네임스페이스를 넷째 줄 파일이 한 번 더 만들려고 해서 나는 안내입니다. 그대로 두면 됩니다

할 일을 하나 넣어 둡니다.

```bash
kubectl -n todo exec deploy/load -c curl -- curl -s -X POST -H "Content-Type: application/json" -d '{"title":"모니터링 공부"}' http://web/api/todos; echo
```

**이렇게 나오면 성공**: `{"id":1,"title":"모니터링 공부"}`

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `ERROR: image: "todo-api:v1" not present locally` | VM 도커에 이미지가 없음 | `cd ~/ktcloud-cloud-native-lab/lab/docker/todo && docker build -t todo-api:v1 api && docker build -t todo-web:v1 web` 후 첫 줄부터 |
| `Error from server (AlreadyExists): namespaces "todo" already exists` | todo가 남아 있음 | `kubectl -n todo get pods`가 모두 `2/2`이면 그대로 다음 단계. `1/1`이면 셋째 줄부터 하고 `kubectl -n todo rollout restart deploy` |
| 파드가 `ErrImageNeverPull` | 첫 줄(`kind load`)을 빠뜨림 | 첫 줄 후 `kubectl -n todo rollout restart deploy` |
| 파드가 `1/1` | 라벨보다 파드가 먼저 생김 | `kubectl -n todo rollout restart deploy` |

</details>

## 2단계. Istio 애드온 지우기

```bash
for a in kiali prometheus; do kubectl delete -f https://raw.githubusercontent.com/istio/istio/1.31.1/samples/addons/$a.yaml; done
kubectl -n istio-system delete ingress kiali
kubectl -n istio-system get deploy
```

**이 명령은**: 서비스 메시 실습 6에서 설치한 Kiali·Prometheus 애드온과 `kiali.localhost` 입구를 지웁니다. 이 과목에서 설치할 Prometheus와 하는 일이 겹치기 때문입니다. `for a in kiali prometheus; do … done` = 같은 명령을 `kiali`, `prometheus` 두 번 실행.

**이렇게 나오면 성공**: `… deleted` 줄이 여러 개, 마지막 줄 목록에 `istiod` 하나만.

```
deployment.apps "kiali" deleted from istio-system namespace
...
deployment.apps "prometheus" deleted from istio-system namespace
ingress.networking.k8s.io "kiali" deleted from istio-system namespace
NAME     READY   UP-TO-DATE   AVAILABLE   AGE
istiod   1/1     1            1           25h
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `Error from server (NotFound): … not found` | 이미 지웠거나 설치하지 않음 | 그대로 다음 단계 |

</details>

## 3단계. 설치 전에 — 지금 값만 보임

모니터링 도구가 없을 때 쓸 수 있는 것은 `kubectl`입니다. 쇼핑몰 파드가 CPU·메모리를 얼마나 쓰는지 봅니다.

```bash
kubectl top pods -n shop --sort-by=cpu | head -4
kubectl top pods -n shop --since=5m
```

**이 명령은**: 첫 줄 = shop 파드의 **지금** CPU·메모리를 CPU 큰 순서로 위 3개(`head -4` = 제목 줄 + 3줄). 둘째 줄 = "5분 전부터" 보여 달라는 옵션을 붙여 봄.

**이렇게 나오면 성공** (값은 사람마다 다름)

```
NAME                                     CPU(cores)   MEMORY(bytes)
frontend-5548498587-vkqn9                39m          47Mi
productcatalogservice-7f946d78f6-dsr88   22m          44Mi
currencyservice-5b966fdd9-cx99b          17m          70Mi
error: unknown flag: --since
See 'kubectl top pod --help' for usage.
```

| 묻고 싶은 것 | `kubectl`만 있을 때 | 4단계 설치 뒤 |
|---|---|---|
| 지금 CPU·메모리 | `kubectl top` — 지금 값 하나 | 같은 값을 그래프로 |
| 5분 전 CPU | **답 못 함** — `--since` 같은 옵션이 없고, 지난 값을 저장하지 않음 | Prometheus가 15~30초마다 가져와 **시간순으로 저장** → 지난 값도 봄 |
| 문제가 생긴 순간 | 내가 명령을 친 순간만 앎 | 경보가 알려 줌(실습 8) |

- `kubectl top`은 클러스터의 metrics-server가 **지금 값만** 알려 주는 것입니다. "어젯밤 느려졌다"는 말을 들어도 지난 값을 볼 방법이 없습니다

## 4단계. 설치 — make monitoring

```bash
cd ~/ktcloud-cloud-native-lab && git pull && cd lab
make monitoring           # 약 1분
```

**이 명령은**: 실습 저장소를 최신으로 받고, Helm으로 kube-prometheus-stack을 `monitoring` 네임스페이스에 설치합니다. 설정 파일은 `lab/monitoring/kps-values.yaml`입니다. 끝나면 파드 목록이 같이 나옵니다.

**이렇게 나오면 성공**: 1분쯤 뒤 파드 8개가 모두 `Running`(READY 칸의 앞뒤 숫자가 같음).

```
NAME                                                    READY   STATUS    RESTARTS   AGE
alertmanager-kps-kube-prometheus-stack-alertmanager-0   2/2     Running   0          44s
kps-grafana-55bdcc985d-zps2k                            3/3     Running   0          52s
kps-kube-prometheus-stack-operator-857dd47f6b-j9vhx     1/1     Running   0          52s
kps-kube-state-metrics-747b7b996-8r6hb                  1/1     Running   0          52s
kps-prometheus-node-exporter-b9sn6                      1/1     Running   0          52s
kps-prometheus-node-exporter-qlv9q                      1/1     Running   0          52s
kps-prometheus-node-exporter-tp7kp                      1/1     Running   0          52s
prometheus-kps-kube-prometheus-stack-prometheus-0       2/2     Running   0          43s
```

| 구성 요소 | 하는 일 |
|---|---|
| Prometheus | 지표를 **가져와서(pull)** 시간순으로 저장, PromQL로 조회 |
| Prometheus Operator | ServiceMonitor·PodMonitor·PrometheusRule(쿠버네티스 리소스)을 Prometheus 설정으로 바꿔 줌 |
| node-exporter | 노드마다 하나 — CPU·메모리·디스크 |
| kube-state-metrics | 쿠버네티스 객체 상태 — 파드 재시작 수, 준비된 레플리카 수 |
| Grafana | 그래프·대시보드 |
| Alertmanager | 경보를 모아 사람에게 보냄(실습 8) |

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `make: *** No rule to make target 'monitoring'.` | `lab` 폴더 밖이거나 저장소가 옛날 것 | 첫 줄부터 다시 |
| `Error: … context deadline exceeded` / `timed out` | 이미지 받기가 늦거나 메모리 부족으로 파드가 제때 안 뜸 | `kubectl -n monitoring get pods`로 안 뜬 파드 확인 후 `make monitoring` 한 번 더(다시 해도 됨) |
| 파드가 `Pending` | VM 메모리 부족 | `free -m` 결과를 붙여 질문 |

</details>

## 5단계. 세 화면 열기

PORTS 탭에서 VM `80`을 전달하고([시작하기 전에 3](./00-시작하기-전에.md#3-브라우저로-보기--ports-탭과-주소)) 세 주소를 엽니다.

- `http://grafana.localhost:<포트>` — `admin` / `lab-grafana`로 로그인
- `http://prometheus.localhost:<포트>`
- `http://alertmanager.localhost:<포트>`

**이렇게 나오면 성공**: 세 화면이 모두 열립니다.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `404 page not found` | 주소 오타(Traefik까지는 왔지만 맞는 주소가 없음) | `grafana.localhost`처럼 정확히 |
| 페이지가 안 열림 | PORTS에서 80을 전달하지 않았음 | PORTS 탭에서 80 전달, 그 포트 번호 사용 |

</details>

## 6단계. 수집 대상 — Targets

Prometheus 화면 위쪽 **Status → Target health**(옛 화면은 **Targets**)를 엽니다.

**이렇게 나오면 성공**: 모든 대상이 `UP`(초록).

같은 내용을 터미널에서 세어 봅니다.

```bash
curl -s prometheus.localhost/api/v1/targets | python3 -c "
import json,sys,collections
d=json.load(sys.stdin)['data']['activeTargets']
print(len(d)); print(collections.Counter((t['labels']['job'], t['health']) for t in d))"
```

**이 명령은**: Prometheus에 수집 대상 목록을 물어보고(`curl`), 결과(JSON)에서 대상 수와 대상 이름(`job`)·상태(`health`)별 개수를 셉니다(`python3`). 네 줄을 한 번에 붙여 넣습니다.

**이렇게 나오면 성공**: 대상 22개, 모두 `'up'`.

```
22
Counter({('kubelet', 'up'): 9, ('node-exporter', 'up'): 3, ('kps-kube-prometheus-stack-alertmanager', 'up'): 2, ('coredns', 'up'): 2, ('kps-kube-prometheus-stack-prometheus', 'up'): 2, ('kps-grafana', 'up'): 1, ('apiserver', 'up'): 1, ('kps-kube-prometheus-stack-operator', 'up'): 1, ('kube-state-metrics', 'up'): 1})
```

- 쿠버네티스(apiserver·kubelet·coredns), 노드(node-exporter), 스택 자신이 대상입니다. **todo·shop 앱은 아직 목록에 없습니다** — 실습 3·4에서 넣습니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `json.decoder.JSONDecodeError` | 네 줄을 나눠 붙여 넣었거나 주소 오타 | 네 줄을 한 번에 다시 |
| `'down'`이 섞여 있음 | 설치 직후 아직 뜨는 중 | 1분 뒤 다시. 그대로면 화면에서 빨간 대상 이름을 붙여 질문 |

</details>

## 7단계. 숫자 꺼내 보기와 켜진 경보

Prometheus 화면의 **Query**(옛 화면 **Graph**) 탭 입력 칸에 아래를 하나씩 넣고 **Execute**를 누릅니다.

| PromQL | 뜻 |
|---|---|
| `up` | 대상이 살아 있으면 1, 죽었으면 0 |
| `kube_pod_container_status_restarts_total{namespace="todo"}` | todo 컨테이너의 재시작 횟수 (누적) |
| `container_memory_working_set_bytes{namespace="todo", container!=""}` | todo 컨테이너의 메모리(바이트) |

**이렇게 나오면 성공**: 줄마다 `{…}` 이름표와 숫자가 나옵니다. 위쪽 **Graph** 탭으로 바꾸면 시간에 따른 선 그래프가 됩니다.

- 중괄호 `{namespace="todo"}` = 이 이름표가 붙은 것만 고르기. 실습 3에서 자세히 봅니다

이어서 위쪽 **Alerts** 탭을 엽니다.

**이렇게 나오면 성공**: 켜진(Firing) 경보가 `Watchdog` 하나뿐.

- `Watchdog`은 "경보 체계가 살아 있다"는 신호로 **항상 켜 두는** 경보입니다. 이것 하나만 켜져 있으면 정상입니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `Empty query result` | 따옴표·중괄호 오타 | 문서에서 다시 복사 |
| `TargetDown` 경보가 켜짐 | 6단계에서 `down`인 대상이 있음 | 6단계 다시 확인 |
| `PrometheusErrorSendingAlertsToAnyAlertmanager`·`…ToSomeAlertmanagers`가 켜짐 | 설치 직후 Prometheus가 Alertmanager보다 먼저 떠서 처음 몇 번 못 보냄 | 2~3분 뒤 새로 고침 — 사라지면 정상 |

</details>

## 끝났는지 확인
- ☐ todo 파드 4개가 `2/2 Running`
- ☐ istio-system에 `istiod`만 남음
- ☐ 3단계에서 `kubectl top`은 지금 값만, `--since`는 오류인 것을 봄
- ☐ 세 화면이 열리고, Target health가 모두 `UP`
- ☐ Alerts에서 켜진 경보가 `Watchdog` 하나

## 정리
- 설치한 것과 todo는 **과목 끝까지 계속 씁니다**. 지우지 마세요

## 확인 문제
1. `kubectl get pods -A -o wide | grep node-exporter`로 node-exporter 파드를 찾아보세요. 몇 개이고, 왜 그 개수일까요?
2. Query에 `up == 0`을 넣어 보세요. 결과가 몇 줄인가요? 무엇을 뜻하나요?
