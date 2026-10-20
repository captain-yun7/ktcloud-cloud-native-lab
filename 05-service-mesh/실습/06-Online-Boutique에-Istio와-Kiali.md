[← 실습 5](./05-타임아웃-재시도-장애-주입.md) · [목차](../서비스-메시-실습.md) · [미션 →](../미션/01-고장-난-메시-고치기.md)

# 실습 6. Online Boutique에 Istio와 Kiali

**무엇을 하나요**: 서비스가 11개인 쇼핑몰 Online Boutique를 띄우고, 먼저 **서비스 목록만으로는 누가 누구를 부르는지 알 수 없는 것**을 봅니다. 그다음 쇼핑몰 전체에 Istio를 주입하고, 프록시가 센 숫자로 관계도를 그려 주는 **Kiali**와 숫자를 모아 두는 **Prometheus**를 설치합니다. 관계도·자물쇠(mTLS)·골든 지표를 보고, 그 숫자가 `istio_requests_total`이라는 지표에서 온다는 것을 Prometheus에 직접 물어 확인합니다. (교안 06장)

**필요한 것**: 실습 4의 Istio(`istiod` `1/1`), `~/ob/helm-chart`(Kubernetes 실습 12에서 받음).

> **바로 가기** · [1. Online Boutique 설치 — 서비스 목록만으로는](#1단계-online-boutique-설치--서비스-목록만으로는) · [2. shop에 Istio 주입](#2단계-shop에-istio-주입) · [3. Prometheus와 Kiali 설치](#3단계-prometheus와-kiali-설치) · [4. Kiali 관계도 보기](#4단계-kiali-관계도-보기) · [5. 골든 지표를 Prometheus에서 — 이 숫자는 어디서 오나](#5단계-골든-지표를-prometheus에서--이-숫자는-어디서-오나) · [6. 부하를 멈추면](#6단계-부하를-멈추면) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. Online Boutique 설치 — 서비스 목록만으로는

```bash
ls ~/ob/helm-chart || git clone --depth 1 --branch v0.10.7 https://github.com/GoogleCloudPlatform/microservices-demo.git ~/ob
printf "frontend:\n  externalService: false\n" > ~/mesh/ob.yaml
helm install shop ~/ob/helm-chart -n shop --create-namespace -f ~/mesh/ob.yaml --wait
kubectl create ingress shop -n shop --rule="shop.localhost/*=frontend:80"
curl -s -o /dev/null -w "%{http_code}\n" shop.localhost
kubectl get svc -n shop
```

**이 명령은**: Kubernetes 실습 12처럼 Helm으로 쇼핑몰을 `shop` 네임스페이스에 설치하고(`--wait` = 다 뜰 때까지 기다림, 강사 VM 약 60초), `shop.localhost`로 들어오는 입구를 붙임. 마지막 줄 = 서비스 목록.

**이렇게 나오면 성공**: `200`, 서비스 11줄(IP는 사람마다 다름).

```
200
NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)     AGE
adservice               ClusterIP   10.96.42.70     <none>        9555/TCP    62s
cartservice             ClusterIP   10.96.158.117   <none>        7070/TCP    62s
checkoutservice         ClusterIP   10.96.97.29     <none>        5050/TCP    62s
currencyservice         ClusterIP   10.96.212.96    <none>        7000/TCP    62s
emailservice            ClusterIP   10.96.104.73    <none>        5000/TCP    62s
frontend                ClusterIP   10.96.89.63     <none>        80/TCP      62s
paymentservice          ClusterIP   10.96.245.62    <none>        50051/TCP   62s
productcatalogservice   ClusterIP   10.96.92.23     <none>        3550/TCP    62s
recommendationservice   ClusterIP   10.96.175.72    <none>        8080/TCP    62s
redis-cart              ClusterIP   10.96.255.178   <none>        6379/TCP    62s
shippingservice         ClusterIP   10.96.234.38    <none>        50051/TCP   62s
```

- 이 목록만 보고 **frontend가 부르는 서비스**를 맞혀 보세요. 이름과 포트뿐이라 누가 누구를 부르는지, 몇 %가 실패하는지, 암호화됐는지는 알 수 없습니다. 4단계에서 같은 것을 그림으로 봅니다
- 쇼핑몰에는 손님 흉내를 내는 **loadgenerator**가 함께 떠서 계속 요청을 보냅니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `cannot re-use a name that is still in use` | `shop` 릴리스가 이미 있음 | `helm list -n shop` 확인 후 그대로 씀 |
| `curl`이 `200`이 아님(`404`) | Ingress를 안 만들었거나 frontend가 아직 안 뜸 | `kubectl -n shop get ingress,pods` |

</details>

## 2단계. shop에 Istio 주입

```bash
kubectl label ns shop istio-injection=enabled
kubectl -n shop rollout restart deploy
kubectl -n shop get pods                    # 1~2분 뒤 12개 모두 2/2
curl -s -o /dev/null -w "%{http_code}\n" shop.localhost
```

**이 명령은**: 실습 4의 3단계와 같은 두 줄. 네임스페이스만 `shop`.

**이렇게 나오면 성공**: 12개(서비스 11 + loadgenerator) 모두 `2/2`, 쇼핑몰은 그대로 `200`.

```
NAME                                     READY   STATUS    RESTARTS   AGE
adservice-84b7bd48f5-t4k8x               2/2     Running   0          102s
cartservice-546d5c6bff-hccls             2/2     Running   0          102s
...
shippingservice-78b6449989-6kkjj         2/2     Running   0          101s
200
```

## 3단계. Prometheus와 Kiali 설치

```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/1.31.1/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/1.31.1/samples/addons/kiali.yaml
kubectl -n istio-system rollout status deploy/kiali       # 약 1분
kubectl create ingress kiali -n istio-system --rule="kiali.localhost/*=kiali:20001"
```

**이 명령은**: Istio가 제공하는 예제 애드온 두 개. Prometheus = 프록시 숫자 저장소, Kiali = 그 숫자로 그린 화면. 마지막 줄 = `kiali.localhost`로 들어오는 입구.

**이렇게 나오면 성공**: `deployment "kiali" successfully rolled out`, `ingress.networking.k8s.io/kiali created` (강사 VM 약 62초)

## 4단계. Kiali 관계도 보기

VS Code **PORTS** 탭에서 VM `80`을 포워딩 → 브라우저에서 `http://kiali.localhost:<포워딩된 포트>/kiali/`

| 화면 | 볼 것 |
|---|---|
| 왼쪽 **Traffic Graph** → 위 Namespace에서 `shop` 선택 | 1단계 목록에 없던 **화살표** — loadgenerator → frontend → 서비스 여러 개, checkoutservice → 서비스 여러 개, cartservice → redis-cart |
| Display → **Security** 켜기 | 화살표마다 자물쇠 = mTLS |
| Display → **Traffic Rate** / **Response Time** | 화살표 위 숫자 — 초당 요청 수 / 걸린 시간 |
| 화살표 하나(예: frontend → productcatalogservice) 누르기 | 오른쪽에 초당 요청 수, 성공·실패 비율 |

**이렇게 나오면 성공**: shop의 워크로드 12개와 화살표 16개 정도가 보이고, Security를 켜면 자물쇠가 보입니다.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `404 page not found` | 주소 끝 `/kiali/`를 빠뜨렸거나 `localhost:<포트>`로 엶 | `http://kiali.localhost:<포트>/kiali/` 그대로 |
| 그래프가 비어 있음 | 네임스페이스를 안 골랐거나 요청이 없음 | 위 Namespace에서 `shop` 체크, `kubectl -n shop get pods`에서 loadgenerator `2/2 Running` |

</details>

## 5단계. 골든 지표를 Prometheus에서 — 이 숫자는 어디서 오나

Kiali가 그린 숫자는 Prometheus에 들어 있습니다. 직접 물어봅니다.

```bash
P="kubectl -n istio-system exec deploy/prometheus -c prometheus-server --"
$P promtool query instant http://localhost:9090 'sum by (destination_workload) (rate(istio_requests_total{reporter="destination", namespace="shop"}[1m]))'
$P promtool query instant http://localhost:9090 'histogram_quantile(0.95, sum by (le, destination_workload) (rate(istio_request_duration_milliseconds_bucket{reporter="destination", namespace="shop"}[1m])))'
```

**이 명령은**: Prometheus 파드 안의 `promtool`로 질의. 첫 줄 = 서비스별 **초당 받은 요청 수**(최근 1분), 둘째 줄 = 서비스별 **p95 지연**(밀리초).

**이렇게 나오면 성공**: 서비스마다 한 줄(숫자는 매번 다름).

```
{destination_workload="productcatalogservice"} => 15.888888888888886 @[…]
{destination_workload="currencyservice"} => 8.688888888888886 @[…]
{destination_workload="frontend"} => 2.844444444444444 @[…]
...
```
```
{destination_workload="checkoutservice"} => 92.5 @[…]
{destination_workload="frontend"} => 67.74999999999997 @[…]
{destination_workload="recommendationservice"} => 8.79545454545454 @[…]
...
```

- `istio_requests_total` = **사이드카가 요청마다 하나씩 더하는 숫자**입니다. Online Boutique 앱은 지표를 하나도 내지 않습니다. 그래도 서비스별 요청 수·응답 코드·지연이 모두 있는 것은 메시가 셌기 때문입니다
- 다음 과목(모니터링)에서는 이 숫자를 Grafana 그래프와 경보로 만듭니다

## 6단계. 부하를 멈추면

쇼핑몰에 요청을 보내던 loadgenerator를 0개로 줄이고 Kiali Graph 화면을 2분쯤 지켜봅니다.

```bash
kubectl -n shop scale deploy loadgenerator --replicas=0
```

**이렇게 나오면 성공**: 1~2분 뒤 화살표가 거의 사라지고 `cartservice → redis-cart` 하나만 남습니다(화면 오른쪽 위 시간 범위가 기본값 **Last 1m**일 때).

| 시간 범위 | 2분 뒤 그래프 (강사 VM) |
|---|---|
| Last 1m (기본) | 워크로드 2 · 화살표 1 — `cartservice → redis-cart` |
| Last 10m | 그대로 — 워크로드 12 · 화살표 16 (멈추기 전 요청이 범위 안에 남음) |

- Kiali는 **프록시 숫자**로 그림을 그립니다. 요청이 없으면 그릴 것이 없습니다
- 다시 켭니다(모니터링 과목에서도 이 손님이 필요합니다):

```bash
kubectl -n shop scale deploy loadgenerator --replicas=1
```

## 끝났는지 확인
- ☐ `kubectl -n shop get pods`가 12개 모두 `2/2`, `shop.localhost` 200
- ☐ Kiali Graph에 shop 관계도와 자물쇠가 보임
- ☐ `promtool`로 서비스별 초당 요청 수와 p95를 봄
- ☐ loadgenerator를 0으로 줄였다가 `--replicas=1`로 되돌림

## 정리
- shop·Prometheus·Kiali는 **미션에서 그대로 씁니다.** 지우지 마세요

## 확인 문제
1. Kiali Graph에서 **화살표가 들어오기만 하고 나가지 않는** 서비스를 두 개 찾아보세요. 손님 흉내를 내는 loadgenerator는 어떤가요?
2. 5단계의 첫 질의에서 `namespace="shop"` 뒤에 `, destination_workload="frontend"`를 더하고 `sum by (destination_workload)`를 `sum by (response_code)`로 바꿔 보세요. frontend가 돌려준 응답 코드는 어떤 것들이고, 성공률은 얼마쯤인가요?
