# Docker — 미션

> 검증: 2026-09-25, s30. 시간 수치는 강사 VM 단독 측정값이라 여러분의 결과와 조금 다를 수 있습니다.
> 스스로 풉니다. 막히면 **힌트를 1단계부터 하나씩** 펼쳐 보고, 그래도 막히면 Discord에 질문합니다.
> 리뷰 전까지 미션별 **제출 표**를 채워 제출합니다. 제출 방법은 수업에서 안내합니다.

| 미션 | 언제 하나 |
|---|---|
| [미션 1. frontend 이미지 빌드](#미션-1-frontend-이미지-빌드) | 교안 05장(실습 11)까지 마친 뒤 |
| [미션 2. Compose로 Online Boutique 조립](#미션-2-compose로-online-boutique-조립) | 교안 11장(실습 16)까지 마친 뒤 |

---

## 미션 1. frontend 이미지 빌드

> 언제 하나: 05장(실습 11)까지 마친 뒤

### 준비
[실습 11](./Docker-실습.md#실습-11-샘플앱-받고-dockerfile-읽기)에서 받은 `~/ob`가 있어야 합니다. 없으면:
```bash
cd ~ && git clone --depth 1 --branch v0.10.7 https://github.com/GoogleCloudPlatform/microservices-demo.git ob
```

### 과제 1. frontend 이미지 빌드

`~/ob/src/frontend`의 Dockerfile로 이미지를 만드세요. 이미지 이름은 `my-frontend:v1`.
빌드에 걸린 시간과 완성된 이미지 크기를 기록합니다.

<details><summary>힌트 1</summary>

이미지를 만드는 명령은 `docker build`입니다. Dockerfile이 있는 폴더에서 실행합니다.
</details>
<details><summary>힌트 2</summary>

`docker build -t 이름:태그 경로` 형식입니다. 경로는 현재 폴더면 `.`입니다. 시간은 명령 앞에 `time`을 붙이면 잴 수 있습니다.
</details>
<details><summary>힌트 3</summary>

```bash
cd ~/ob/src/frontend
time docker build -t my-frontend:v1 .
docker image ls my-frontend
```
</details>

### 과제 2. 홈 화면 문구를 바꾸고 다시 빌드

홈 화면의 `Hot Products`를 `Hot Products - 내이름`으로 바꾸고 `my-frontend:v2`를 빌드하세요.
첫 빌드와 두 번째 빌드 시간을 비교하고, 빌드 로그에서 `CACHED`로 표시된 단계를 찾으세요.

<details><summary>힌트 1</summary>

화면 문구는 Go 코드가 아니라 HTML 템플릿에 있습니다. `templates` 폴더를 보세요.
</details>
<details><summary>힌트 2</summary>

`grep -rn "Hot Products" templates/` 로 파일과 줄을 찾고, `vi`나 `sed -i`로 바꿉니다.
</details>
<details><summary>힌트 3</summary>

```bash
sed -i 's#<h3>Hot Products</h3>#<h3>Hot Products - 내이름</h3>#' templates/home.html
time docker build -t my-frontend:v2 .
```
</details>

### 과제 3. 왜 바로 꺼질까

`my-frontend:v2`를 실행하면 바로 종료됩니다. **로그를 읽고 원인을 설명**하세요.
그리고 frontend가 시작하려면 **환경변수가 몇 개** 필요한지 소스 코드에서 찾아 적으세요.

<details><summary>힌트 1</summary>

`docker run --rm my-frontend:v2` 의 출력에서 긴 스택 트레이스 말고 **맨 위 `panic:` 줄**만 읽으세요.
</details>
<details><summary>힌트 2</summary>

에러 메시지에 나온 함수가 `main.go` 어디서 불리는지 찾아보세요. `grep -n "mustMapEnv" main.go`
</details>
<details><summary>힌트 3</summary>

`mustMapEnv(..., "XXX_SERVICE_ADDR")` 줄을 세면 됩니다. frontend는 다른 서비스들의 주소를 환경변수로 받고, 하나라도 없으면 시작하지 않습니다. 단, `initTracing` 함수 안에 있는 것은 추적 기능을 켤 때만 읽습니다.
</details>

### 과제 4. COPY 순서 실험 ⭐

원본 Dockerfile은 `COPY go.mod go.sum ./` → `RUN go mod download` → `COPY . .` 순서입니다.
이 순서를 바꾸면 어떻게 될까요?

1. `Dockerfile.bad`를 만들어 **`COPY . .`을 `go mod download`보다 먼저** 하도록 바꾸세요 (나머지는 원본과 같게)
2. 두 Dockerfile로 한 번씩 빌드해 둡니다
3. 홈 문구를 한 번 더 바꾼 뒤, **두 Dockerfile로 각각 다시 빌드**하고 시간을 비교하세요
4. 왜 차이가 나는지 3줄로 설명하세요

<details><summary>힌트 1</summary>

다른 이름의 Dockerfile로 빌드하려면 `-f` 옵션을 씁니다. `docker build -f Dockerfile.bad -t bad:1 .`
</details>
<details><summary>힌트 2</summary>

Docker는 명령을 위에서부터 실행하며, **어떤 단계의 입력(복사한 파일)이 바뀌면 그 단계부터 아래는 전부 다시** 실행합니다. `COPY . .`에는 템플릿 파일도 포함됩니다.
</details>
<details><summary>힌트 3</summary>

`Dockerfile.bad`의 builder 부분:
```dockerfile
FROM golang:1.27.0-alpine AS builder
WORKDIR /src
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /go/bin/frontend .
```
(아래 `FROM gcr.io/distroless/static` 부분은 원본과 같게)
</details>

> 도전 A · B는 과제 1~4를 먼저 끝낸 사람만 선택해서 풉니다.

### 도전 A (선택). 템플릿만 바꿨는데 왜 Go를 다시 컴파일할까

과제 4에서 원본 Dockerfile도 재빌드에 십몇 초가 걸렸습니다. 템플릿(HTML)만 바꿨는데 `go build`가 다시 돈 이유를 찾고, **템플릿을 바꿔도 `go build`가 캐시되도록** Dockerfile을 고쳐 보세요.

<details><summary>힌트</summary>

builder 단계에서 `COPY . .`이 템플릿까지 복사합니다. 컴파일에 필요한 것은 `.go` 파일과 `genproto`, `money`, `validator` 폴더뿐입니다. 템플릿은 두 번째 단계에서 따로 복사합니다.
</details>

### 도전 B (선택). 컨테이너와 VM의 차이

`docker run -it --rm ubuntu:24.04 bash` 안에서 `ps`, `hostname`, `cat /etc/os-release`, `uname -r`을 실행하고 VM에서의 결과와 비교해 다른 점 3가지, 같은 점 1가지를 적으세요.

### 미션 1 제출 표

| 항목 | 내 결과 |
|---|---|
| 과제 1 첫 빌드 시간 / 이미지 크기 | |
| 과제 2 재빌드 시간 / CACHED 단계 수 | |
| 과제 3 종료 원인 (한 줄) / 필요한 환경변수 개수 | |
| 과제 4 원본 재빌드 / bad 재빌드 시간 | |
| 과제 4 차이의 이유 (3줄) | |
| 도전 A (한 경우) 고친 Dockerfile의 재빌드 시간 | |

---

## 미션 2. Compose로 Online Boutique 조립

> 언제 하나: 11장(실습 16)까지 마친 뒤

### 공통 정보
모든 이미지 주소: `us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo/<서비스>:v0.10.7` (redis만 `redis:alpine`)

| 서비스 | 포트 | 필요한 환경변수 |
|---|---|---|
| frontend | 8080 (외부 공개) | `PORT=8080` + 미션 1 과제 3에서 찾은 **주소 8개** |
| productcatalogservice | 3550 | `PORT=3550`, `DISABLE_PROFILER=1` |
| currencyservice | 7000 | `PORT=7000`, `DISABLE_PROFILER=1` |
| cartservice | 7070 | `REDIS_ADDR=redis-cart:6379` |
| redis-cart | 6379 | — |
| shippingservice | 50051 | `PORT=50051`, `DISABLE_PROFILER=1` |

frontend 주소 환경변수의 값 = `서비스이름:포트`. 지금 띄우지 않을 서비스도 **주소는 반드시** 넣어야 합니다 (recommendationservice:8080, checkoutservice:5050, adservice:9555, shoppingassistantservice:80).

브라우저로 보기: VS Code 아래 **PORTS** 탭에서 8080 포워딩 → `http://localhost:8080`

### 과제 1. 서비스 5개로 홈 화면 띄우기

`~/shop/compose.yaml`을 **직접 작성**해 frontend, productcatalogservice, currencyservice, cartservice, redis-cart를 띄우고, 브라우저에서 **상품 9개가 있는 홈 화면**을 확인하세요.

<details><summary>힌트 1</summary>

실습 14의 `compose.yaml` 모양을 그대로 따라가세요. 서비스 이름(키)이 곧 다른 서비스가 부르는 주소입니다.
</details>
<details><summary>힌트 2</summary>

`environment:`는 두 가지로 쓸 수 있습니다.
```yaml
    environment:
      PORT: "8080"
      PRODUCT_CATALOG_SERVICE_ADDR: productcatalogservice:3550
```
frontend가 계속 재시작되면 `docker compose logs frontend`의 `panic:` 줄을 보세요.
</details>
<details><summary>힌트 3</summary>

frontend 부분:
```yaml
  frontend:
    image: us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo/frontend:v0.10.7
    ports: ["8080:8080"]
    environment:
      PORT: "8080"
      PRODUCT_CATALOG_SERVICE_ADDR: productcatalogservice:3550
      CURRENCY_SERVICE_ADDR: currencyservice:7000
      CART_SERVICE_ADDR: cartservice:7070
      RECOMMENDATION_SERVICE_ADDR: recommendationservice:8080
      SHIPPING_SERVICE_ADDR: shippingservice:50051
      CHECKOUT_SERVICE_ADDR: checkoutservice:5050
      AD_SERVICE_ADDR: adservice:9555
      SHOPPING_ASSISTANT_SERVICE_ADDR: shoppingassistantservice:80
```
나머지 4개는 표의 포트·환경변수를 같은 모양으로 적으면 됩니다.
</details>

### 과제 2. 장바구니가 안 된다

상품을 담고 장바구니를 열면 **500 에러**가 납니다. **로그로 원인을 찾아** 고치세요.

<details><summary>힌트 1</summary>

`docker compose logs frontend | grep -i error`
</details>
<details><summary>힌트 2</summary>

`lookup ○○○service ... server misbehaving` = 그 이름의 서비스가 네트워크에 없다는 뜻입니다.
</details>
<details><summary>힌트 3</summary>

shippingservice(포트 50051)를 추가하고 `docker compose up -d` (바뀐 것만 새로 생성됩니다).
</details>

그리고 답해 보세요: 로그의 `failed to get ads`는 왜 나오고, 그런데도 홈 화면은 왜 떴을까요?

### 과제 3. 내가 빌드한 frontend로 교체

frontend를 미션 1 과제 2에서 만든 `my-frontend:v2`로 바꿔 홈에 `Hot Products - 내이름`이 보이게 하세요.
**원본 `compose.yaml`은 고치지 말고** 덮어쓰기 파일을 따로 만들어서 해 보세요.

<details><summary>힌트 1</summary>

`docker compose -f 파일1 -f 파일2 up -d` — 뒤 파일이 앞 파일의 값을 덮어씁니다.
</details>
<details><summary>힌트 2</summary>

덮어쓰기 파일에는 바꿀 부분만 적습니다.
```yaml
services:
  frontend:
    image: my-frontend:v2
```
</details>

### 과제 4. redis를 다시 만들어도 장바구니 유지

상품을 담은 뒤 `docker compose up -d --force-recreate redis-cart`로 redis를 새로 만들면 장바구니가 비워집니다.
**redis를 새로 만들어도 장바구니가 남도록** 고치세요. 확인은 홈 오른쪽 위 장바구니 숫자로 합니다.

<details><summary>힌트 1</summary>

실습 15의 "이름 있는 볼륨"입니다. redis는 `/data`에 저장합니다.
</details>
<details><summary>힌트 2</summary>

redis는 기본 설정으로는 종료할 때만 저장합니다. 명령을 `redis-server --appendonly yes`로 바꾸면 쓸 때마다 저장합니다.
</details>

### 과제 5. 레지스트리의 이미지로 실행

실습 16에서 띄운 연습용 레지스트리(`localhost:5000`)에 `my-frontend:v2`를 올리고, **Compose가 레지스트리의 이미지를 쓰도록** 바꾸세요. 로컬 이미지를 지워도 동작하는지 확인합니다.

<details><summary>힌트</summary>

`docker tag` → `docker push` → 덮어쓰기 파일의 `image:`를 `localhost:5000/my-frontend:v2`로. 로컬 이미지는 `docker image rm my-frontend:v2 localhost:5000/my-frontend:v2`로 지우고 `docker compose up -d`하면 레지스트리에서 받아 옵니다.
</details>

### 도전 (선택). 11개 전체로 주문 완료

과제 1~5를 먼저 끝낸 사람만 선택해서 풉니다.
나머지 서비스(recommendation, ad, payment, email, checkout)를 추가해 **주문 완료 화면**까지 가 보세요. 필요한 포트와 환경변수는 `~/ob/kubernetes-manifests/<서비스>.yaml`의 `env:`와 `containerPort`에 있습니다.

### 미션 2 제출 표

| 항목 | 내 결과 |
|---|---|
| 과제 1 홈 화면 캡처 | |
| 과제 2 원인 (한 줄) / `failed to get ads`인데 홈이 뜬 이유 | |
| 과제 3 `Hot Products - 내이름` 캡처 | |
| 과제 4 재생성 전·후 장바구니 숫자 (볼륨 없음 / 있음) | |
| 과제 5 `curl localhost:5000/v2/_catalog` 결과 | |
| (도전) 주문 완료 캡처 + `docker stats --no-stream` 가장 무거운 서비스 | |
