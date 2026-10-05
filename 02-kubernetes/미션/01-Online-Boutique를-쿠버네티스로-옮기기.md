[목차](../Kubernetes-미션.md) · [미션 2 →](./02-고장-난-Online-Boutique-고치기.md)

# 미션 1. Online Boutique를 쿠버네티스로 옮기기

**무엇을 하나요**: Docker 미션 2에서 Compose로 띄운 Online Boutique 서비스 5개를 쿠버네티스의 **Deployment + Service**로 옮깁니다. Compose 파일 한 서비스가 쿠버네티스에서는 Deployment(무엇을 몇 개 실행) + Service(이름과 포트)가 됩니다. 실습 4~6을 서비스 여러 개로 다시 해 보는 미션입니다.

| 과제 | 한 줄 요약 |
|---|---|
| 과제 1 | 서비스 5개를 Deployment + Service로 만들어 쇼핑몰 홈 화면 띄우기 |
| 과제 2 | 장바구니 500 에러를 로그로 찾아 고치기 — Docker 때와 무엇이 같고 다른가 |
| 도전 A (선택) | 잘못된 버전으로 업데이트했을 때 무슨 일이 생기고 어떻게 되돌리나 |
| 도전 B (선택) | 공식 매니페스트로 11개 전체를 한 번에 |

> **바로 가기** · [공통 정보](#공통-정보) · [과제 1. 서비스 5개로 홈 화면 띄우기](#과제-1-서비스-5개로-홈-화면-띄우기) · [과제 2. 장바구니가 안 된다 — 이번엔 쿠버네티스에서](#과제-2-장바구니가-안-된다--이번엔-쿠버네티스에서) · [도전 A (선택). 잘못된 버전으로 업데이트하면](#도전-a-선택-잘못된-버전으로-업데이트하면) · [도전 B (선택). 11개 전체를 한 번에](#도전-b-선택-11개-전체를-한-번에) · [미션 1 결과 정리 표](#미션-1-결과-정리-표) · [미션 1 정리](#미션-1-정리)

## 공통 정보

- 네임스페이스: **`mission1`** — `kubectl create namespace mission1`
- 파일 위치: `~/k8s-mission1/` — `mkdir -p ~/k8s-mission1 && cd ~/k8s-mission1`
- 이미지 주소: `us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo/<서비스>:v0.10.7` (redis만 `redis:alpine`). 공개 이미지라 `kind load` 없이 노드가 받습니다

| 서비스(= Deployment·Service 이름) | 컨테이너 포트 | 환경변수 |
|---|---|---|
| frontend | 8080 | `PORT=8080` + 아래 **주소 8개** |
| productcatalogservice | 3550 | `PORT=3550`, `DISABLE_PROFILER=1` |
| currencyservice | 7000 | `PORT=7000`, `DISABLE_PROFILER=1` |
| cartservice | 7070 | `REDIS_ADDR=redis-cart:6379` |
| redis-cart | 6379 | — |
| shippingservice | 50051 | `PORT=50051`, `DISABLE_PROFILER=1` |

frontend가 다른 서비스를 찾는 주소 환경변수 8개(Docker 미션 2와 같음). 지금 띄우지 않을 서비스도 **주소는 반드시** 넣어야 합니다(없으면 frontend가 시작하자마자 꺼짐).

| 환경변수 | 값 |
|---|---|
| `PRODUCT_CATALOG_SERVICE_ADDR` | `productcatalogservice:3550` |
| `CURRENCY_SERVICE_ADDR` | `currencyservice:7000` |
| `CART_SERVICE_ADDR` | `cartservice:7070` |
| `RECOMMENDATION_SERVICE_ADDR` | `recommendationservice:8080` |
| `SHIPPING_SERVICE_ADDR` | `shippingservice:50051` |
| `CHECKOUT_SERVICE_ADDR` | `checkoutservice:5050` |
| `AD_SERVICE_ADDR` | `adservice:9555` |
| `SHOPPING_ASSISTANT_SERVICE_ADDR` | `shoppingassistantservice:80` |

**작업 순서(모든 과제 공통)**

| 순서 | 할 일 | 명령 |
|---|---|---|
| 1 | 파일 쓰기 (서비스마다 한 파일, Deployment와 Service를 `---`로 이어 씀) | `nano productcatalog.yaml` |
| 2 | 적용 | `kubectl apply -n mission1 -f productcatalog.yaml` |
| 3 | 상태 | `kubectl get pods -n mission1` — 모두 `1/1 Running`인지 |
| 4 | 연결 | `kubectl get endpointslices -n mission1` — Service마다 파드 IP가 있는지 |
| 5 | 로그 | `kubectl logs -n mission1 deploy/<이름>` |
| 6 | 브라우저 | 터미널 1 `kubectl port-forward -n mission1 svc/frontend 8090:80` → `http://localhost:8090` |

## 과제 1. 서비스 5개로 홈 화면 띄우기

**무엇을 하나요**: frontend, productcatalogservice, currencyservice, cartservice, redis-cart를 각각 Deployment + Service로 만들고, 브라우저에서 **상품 9개가 있는 홈 화면**을 확인합니다. frontend Service는 **80번으로 받아 컨테이너 8080으로** 넘깁니다. 나머지 Service는 컨테이너 포트와 같은 번호로 받습니다.

<details><summary>힌트 1 — 어디서 시작하나</summary>

실습 4의 `deploy.yaml`과 실습 6의 `service.yaml`을 `---` 줄로 이어 붙여 시작하세요.
```bash
cd ~/k8s-mission1
H=~/ktcloud-cloud-native-lab/lab/k8s/hello
cat $H/deploy.yaml > productcatalog.yaml && echo "---" >> productcatalog.yaml && cat $H/service.yaml >> productcatalog.yaml
nano productcatalog.yaml
```
바꿀 곳: 이름(Deployment `name`, `matchLabels`, 파드 `labels`, Service `name`·`selector` — 모두 `productcatalogservice`), `replicas: 1`, 이미지, 포트(`containerPort`, Service `port`·`targetPort`), 그리고 `env:`(힌트 2)를 새로 넣습니다.
</details>
<details><summary>힌트 2 — 환경변수 쓰는 법</summary>

`env:`는 `image:`와 같은 들여쓰기에 둡니다. 값은 숫자라도 **따옴표**로 감쌉니다.
```yaml
        env:
        - name: PORT
          value: "3550"
        - name: DISABLE_PROFILER
          value: "1"
```
</details>
<details><summary>힌트 3 — frontend의 포트</summary>

Service 쪽:
```yaml
  ports:
  - port: 80
    targetPort: 8080
```
frontend가 계속 재시작되면 `kubectl logs -n mission1 deploy/frontend`의 `panic:` 줄을 보세요 — Docker 미션 2 과제 1과 같은 원인입니다.
</details>
<details><summary>힌트 4 — 막혔을 때 확인할 것</summary>

- `kubectl get endpointslices -n mission1`에서 Service의 `ENDPOINTS`가 `<unset>`이면 Service `selector`와 파드 `labels`가 다름
- 이름 오타(`productcatalogservice`를 `productcatalog`로)가 있으면 frontend가 그 주소를 못 찾습니다. 표의 이름을 그대로 복사
- `-n mission1`을 빠뜨리면 `default`에 만들어집니다. `kubectl get pods`(네임스페이스 없이)에 보이면 `kubectl delete -f 파일`로 지우고 `-n mission1`으로 다시
</details>

## 과제 2. 장바구니가 안 된다 — 이번엔 쿠버네티스에서

**무엇을 하나요**: 상품을 담고 장바구니를 열면 **500 에러**가 납니다. Docker 미션 2 과제 2와 같은 원인입니다. **로그로 원인을 찾아** 고치고, 로그에 나온 **DNS 서버 주소**가 Docker 때(`127.0.0.11`)와 무엇이 다른지 적으세요.

<details><summary>힌트 1</summary>

`kubectl logs -n mission1 deploy/frontend | grep -i error`
</details>
<details><summary>힌트 2</summary>

`lookup ○○○service on <주소>:53: server misbehaving` = 그 이름의 Service가 없다는 뜻. `<주소>`가 이름을 찾아 주는 DNS 서버입니다. `kubectl get svc -n kube-system`에서 그 주소를 가진 Service를 찾아보세요.
</details>
<details><summary>힌트 3</summary>

shippingservice(포트 50051)를 Deployment + Service로 추가하고 `kubectl apply`. 나머지는 그대로 둡니다.
</details>

## 도전 A (선택). 잘못된 버전으로 업데이트하면

**무엇을 하나요**: productcatalogservice를 **없는 태그** `v0.10.99`로 바꿔 보고, 파드가 어떻게 되는지·쇼핑몰이 계속 열리는지 관찰한 뒤 되돌립니다.

<details><summary>힌트</summary>

파일의 `image:`를 고쳐 apply 하거나, `kubectl set image -n mission1 deploy/productcatalogservice server=<새 이미지>`(컨테이너 이름은 YAML의 `containers[].name`). 되돌리기는 `kubectl rollout undo -n mission1 deploy/productcatalogservice` 또는 파일을 고쳐 apply.
</details>

## 도전 B (선택). 11개 전체를 한 번에

**무엇을 하나요**: 공식 매니페스트(서비스 11개 + 부하 생성기, YAML 한 파일)로 전체를 올리고 주문까지 해 봅니다. 내가 쓴 YAML과 무엇이 다른지 비교합니다.

```bash
ls ~/ob || git clone --depth 1 --branch v0.10.7 https://github.com/GoogleCloudPlatform/microservices-demo.git ~/ob
kubectl create namespace mission1-full
kubectl apply -n mission1-full -f ~/ob/release/kubernetes-manifests.yaml
```

- `kubectl get svc -n mission1-full`에서 `frontend-external`의 `EXTERNAL-IP`가 `<pending>`인 이유를 추측해 적으세요
- 내 `frontend.yaml`과 `~/ob/kubernetes-manifests/frontend.yaml`을 비교해, 공식 쪽에만 있는 설정 **두 가지**를 찾으세요
- 끝나면 `kubectl delete namespace mission1-full`(메모리 반환)

## 미션 1 결과 정리 표

| 항목 | 내 결과 |
|---|---|
| 과제 1 `kubectl get pods -n mission1` 결과 / 홈 화면 캡처 | |
| 과제 1 `kubectl get endpointslices -n mission1` 결과 | |
| 과제 2 원인 (한 줄) / DNS 주소 (쿠버네티스 · Docker) | |
| (도전 A) 잘못된 태그일 때 파드 상태와 홈이 열렸는지 | |
| (도전 B) `<pending>` 이유 / 공식 쪽에만 있는 설정 2가지 | |

## 미션 1 정리
결과 정리 표를 채운 뒤 지웁니다: `kubectl delete namespace mission1` (네임스페이스를 지우면 안의 것이 모두 지워짐). 실습 12(Helm)에서 같은 앱을 다시 설치합니다.
