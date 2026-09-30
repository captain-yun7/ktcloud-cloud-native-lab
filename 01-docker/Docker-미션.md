# Docker — 미션

- 스스로 풉니다. 막히면 **힌트를 1단계부터 하나씩** 펼쳐 보고, 그래도 막히면 Discord에 질문합니다.
- 리뷰 전까지 미션별 **제출 표**를 채워 제출합니다. 제출 방법은 수업에서 안내합니다.
- 문서에 적힌 시간 수치는 강사 VM에서 단독으로 측정한 값이라 여러분의 결과와 조금 다를 수 있습니다.

| 미션 | 언제 하나 |
|---|---|
| [미션 1. 내 앱 이미지 만들기](#미션-1-내-앱-이미지-만들기) | 교안 05장(실습 8)까지 마친 뒤 |
| [미션 2. Compose로 Online Boutique 조립](#미션-2-compose로-online-boutique-조립) | 교안 09장(실습 13)까지 마친 뒤 |

---

## 미션 1. 내 앱 이미지 만들기

`hello` 앱을 새 폴더로 복사해 **Dockerfile을 처음부터 직접** 쓰고, 기능을 하나 더한 v2를 만들어 v1과 나란히 실행합니다. 실습 7·8의 Dockerfile을 보지 않고 쓰는 것이 목표입니다.

### 준비
```bash
mkdir -p ~/mission1
cd ~/ktcloud-cloud-native-lab/lab/docker/hello
cp app.js package.json package-lock.json .dockerignore ~/mission1/
cd ~/mission1
ls -a            # .  ..  .dockerignore  app.js  package-lock.json  package.json
```
`app.js`의 문구가 `hello, docker`가 아니면(실습 7에서 고친 경우) nano로 `hello, docker`로 되돌립니다.

### 과제 1. Dockerfile을 처음부터 쓰기
아래 조건으로 `~/mission1/Dockerfile`을 쓰세요.

- 베이스 이미지는 `node:22-alpine`, 앱은 3000번 포트
- 앱 코드(`app.js`)만 고쳤을 때 `npm install`이 **캐시로 건너뛰어지는 순서**

<details><summary>힌트 1</summary>

줄은 7개입니다: FROM · WORKDIR · COPY(라이브러리 목록) · RUN · COPY(나머지) · EXPOSE · CMD.
</details>
<details><summary>힌트 2</summary>

라이브러리 목록 파일은 `package.json`과 `package-lock.json` 두 개입니다. 이 둘만 먼저 `COPY`하고 `RUN npm install`, 그다음 `COPY . ./`.
</details>

### 과제 2. v1 빌드하고 실행
이미지 `my-app:v1`을 빌드해 이름 `my-app1`, **VM 포트 8091**로 실행하세요. `curl localhost:8091`에 `hello, docker`가 나오면 됩니다.

<details><summary>힌트</summary>

`docker build -t 이름:태그 .` → `docker run -d --name … -p VM포트:컨테이너포트 이미지`. `-p`의 왼쪽이 VM, 오른쪽이 컨테이너입니다.
</details>

### 과제 3. /about 주소를 더한 v2를 v1과 나란히
`app.js`에 아래 세 줄을 `app.listen(` 줄 **위에** 넣어 `/about` 주소를 만들고, `my-app:v2`로 빌드해 이름 `my-app2`, **VM 포트 8092**로 실행하세요. v1(8091)은 끄지 않습니다.

```js
app.get('/about', (req, res) => {
  res.send('my-app v2\n');
});
```
- `curl localhost:8092/about` → `my-app v2`
- `curl localhost:8091/about` → 무엇이 나오나요? 왜 그럴까요?
- `node -v`(VM)와 `docker exec my-app2 node -v`(컨테이너)의 결과도 적으세요. VM의 Node.js 버전과 상관없이 두 앱이 돌아가는 이유는?

<details><summary>힌트</summary>

v1 이미지는 `/about`을 넣기 전의 `app.js`로 만들어졌습니다. 없는 주소에 대한 Express의 기본 응답은 `Cannot GET /about`(상태 코드 404)입니다. 상태 코드는 `curl -I`로 봅니다.
</details>

### 과제 4. 캐시가 됐는지 확인
`app.js`만 한 번 더 고치고(예: `echo "// again" >> app.js`) `docker build -t my-app:v2 .`로 다시 빌드하세요. 빌드 출력에서 `npm install` 줄이 어떻게 표시되는지 적으세요. `CACHED`가 아니라면 과제 1의 Dockerfile 순서를 고쳐 다시 해 보세요.

<details><summary>힌트</summary>

캐시가 되는 순서라면 `=> CACHED [4/5] RUN npm install`이 보이고, 마지막 `COPY . ./`만 다시 실행됩니다.
</details>

### 도전 (선택). 포트를 환경변수로 바꾸기
`app.js`는 환경변수 `PORT`로 포트를 바꿀 수 있습니다(실습 3 확인 문제 1). **이미지를 다시 빌드하지 않고** `my-app:v2`를 컨테이너 안 포트 4000으로 실행해 **VM 포트 8093**에서 응답하게 하세요. 이름은 `my-app3`.

<details><summary>힌트</summary>

`-e`로 환경변수를 넣고, `-p`의 오른쪽(컨테이너 포트)도 같이 바꿔야 합니다. `docker logs my-app3`에 나오는 포트 번호를 확인하세요.
</details>

### 미션 1 제출 표

| 항목 | 내 결과 |
|---|---|
| 과제 1 Dockerfile 전체 | |
| 과제 2 `docker ps`의 my-app1 줄 | |
| 과제 3 `curl localhost:8092/about` / `curl localhost:8091/about` 결과와 이유, VM·컨테이너 `node -v` | |
| 과제 4 다시 빌드한 출력의 `npm install` 줄 | |
| (도전) 실행 명령과 `docker logs my-app3` 결과 | |

---

## 미션 2. Compose로 Online Boutique 조립

Online Boutique는 구글이 공개한 쇼핑몰 예제로, 서비스 11개와 Redis로 되어 있습니다. 이미 만들어진 공식 이미지를 받아 **Compose로 조립**합니다(빌드 없음). Kubernetes 과목부터 계속 쓰는 앱입니다.

### 공통 정보
모든 이미지 주소: `us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo/<서비스>:v0.10.7` (redis만 `redis:alpine`)

| 서비스 | 포트 | 필요한 환경변수 |
|---|---|---|
| frontend | 8080 (외부 공개) | `PORT=8080` + 아래 **주소 8개** |
| productcatalogservice | 3550 | `PORT=3550`, `DISABLE_PROFILER=1` |
| currencyservice | 7000 | `PORT=7000`, `DISABLE_PROFILER=1` |
| cartservice | 7070 | `REDIS_ADDR=redis-cart:6379` |
| redis-cart | 6379 | — |
| shippingservice | 50051 | `PORT=50051`, `DISABLE_PROFILER=1` |

frontend가 다른 서비스를 찾아가는 주소 환경변수 8개입니다. 값 = `서비스이름:포트`. 지금 띄우지 않을 서비스도 **주소는 반드시** 넣어야 합니다(없으면 frontend가 시작하자마자 꺼집니다).

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

브라우저로 보기: VS Code 아래 **PORTS** 탭에서 8080 포워딩 → `http://localhost:8080`

### 과제 1. 서비스 5개로 홈 화면 띄우기

`~/shop/compose.yaml`을 **직접 작성**해 frontend, productcatalogservice, currencyservice, cartservice, redis-cart를 띄우고, 브라우저에서 **상품 9개가 있는 홈 화면**을 확인하세요.

<details><summary>힌트 1</summary>

실습 13의 `compose.yaml` 모양을 그대로 따라가세요. 이번에는 빌드 없이 모두 `image:`만 씁니다. 서비스 이름(키)이 곧 다른 서비스가 부르는 주소입니다.
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

### 도전 A (선택). redis를 다시 만들어도 장바구니 유지

상품을 담은 뒤 `docker compose up -d --force-recreate redis-cart`로 redis를 새로 만들면 장바구니가 비워집니다.
**redis를 새로 만들어도 장바구니가 남도록** 고치세요. 확인은 홈 오른쪽 위 장바구니 숫자로 합니다.

<details><summary>힌트 1</summary>

실습 10의 "이름 있는 볼륨"입니다. redis는 `/data`에 저장합니다.
</details>
<details><summary>힌트 2</summary>

redis는 기본 설정으로는 종료할 때만 저장합니다. 명령을 `redis-server --appendonly yes`로 바꾸면(`command:` 키) 쓸 때마다 저장합니다.
</details>

### 도전 B (선택). 11개 전체로 주문 완료

나머지 서비스(recommendation, ad, payment, email, checkout)를 추가해 **주문 완료 화면**까지 가 보세요. 필요한 포트와 환경변수는 Online Boutique 저장소의 `kubernetes-manifests/<서비스>.yaml`에 있는 `env:`와 `containerPort`를 보고 찾습니다.

```bash
git clone --depth 1 --branch v0.10.7 https://github.com/GoogleCloudPlatform/microservices-demo.git ~/ob
ls ~/ob/kubernetes-manifests
```

### 미션 2 제출 표

| 항목 | 내 결과 |
|---|---|
| 과제 1 홈 화면 캡처 | |
| 과제 2 원인 (한 줄) / `failed to get ads`인데 홈이 뜬 이유 | |
| (도전 A) 재생성 전·후 장바구니 숫자 (볼륨 없음 / 있음) | |
| (도전 B) 주문 완료 캡처 + `docker stats --no-stream` 가장 무거운 서비스 | |
