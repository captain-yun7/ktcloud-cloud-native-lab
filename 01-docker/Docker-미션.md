# Docker — 미션

미션은 실습에서 배운 것을 **스스로 조합해** 푸는 과제입니다. 실습처럼 명령을 다 적어 두지 않았습니다. 대신 막히면 펼쳐 볼 수 있는 힌트가 단계별로 있습니다.

- 스스로 풉니다. 막히면 **힌트를 1단계부터 하나씩** 펼쳐 보고(▶ 힌트 글자를 누르면 펼쳐짐), 그래도 막히면 Discord에 질문합니다.
- 리뷰 전까지 미션별 **제출 표**를 채워 제출합니다. 제출 방법은 수업에서 안내합니다.
- 문서에 적힌 시간 수치는 강사 VM에서 단독으로 측정한 값이라 여러분의 결과와 조금 다를 수 있습니다.

| 미션 | 언제 하나 |
|---|---|
| [미션 1. 내 앱 이미지 만들기](#미션-1-내-앱-이미지-만들기) | 교안 05장(실습 8)까지 마친 뒤 |
| [미션 2. Compose로 Online Boutique 조립](#미션-2-compose로-online-boutique-조립) | 교안 09장(실습 13)까지 마친 뒤 |

## 시작하기 전에

실습 문서의 [시작하기 전에](./Docker-실습.md#시작하기-전에)와 같습니다. 핵심만 다시 적습니다.

| 확인할 것 | 내용 |
|---|---|
| 접속 | `ssh ktc-sNN`(이메일 인증 없음, VM 비밀번호만). 브라우저가 열리며 이메일을 물으면 예전 설정이 남은 것 — [접속 안내](../00-접속-안내.md) |
| 어디서 치나 | 명령은 전부 **서버 VM 터미널**(프롬프트 `lab@sNN:~$`, VS Code 왼쪽 아래 `SSH: ktc-sNN`)에서 칩니다 |
| 붙여넣기 | 코드 블록 오른쪽 위 복사 버튼 → VS Code 터미널에 Windows Ctrl+V(또는 Ctrl+Shift+V), macOS Cmd+V |
| nano | `nano 파일` → 고치기 → **Ctrl+O → Enter**(저장) → **Ctrl+X**(나가기) |
| 브라우저로 보기 | VS Code **PORTS** 탭 → Forward a Port → 포트 번호 → Enter → 지구 아이콘([자세히](./Docker-실습.md#8-브라우저로-서버의-웹-페이지-보기-ports-탭)) |
| 오류가 나면 | 첫 줄을 읽고, 실습 문서의 [자주 만나는 오류 한눈에](./Docker-실습.md#자주-만나는-오류-한눈에)에서 찾아봅니다 |
| 질문 | 에러 첫 줄을 글자로 복사해 Discord에. 한 일 / 기대 / 실제 / 해 본 것 — [질문 양식](./Docker-실습.md#9-막히면--질문하는-법) |

---

## 미션 1. 내 앱 이미지 만들기

**무엇을 하나요**: `hello` 앱을 새 폴더로 복사해 **Dockerfile을 처음부터 직접** 쓰고, 기능을 하나 더한 v2를 만들어 v1과 나란히 실행합니다. 실습 7·8의 Dockerfile을 보지 않고 쓰는 것이 목표입니다. 이미지를 만들고(빌드) → 실행하고(run) → 고치고 → 다시 빌드하는 흐름을 혼자 한 바퀴 돌아 봅니다.

| 과제 | 한 줄 요약 |
|---|---|
| 과제 1 | Dockerfile을 직접 씀 |
| 과제 2 | v1 이미지를 빌드해 8091번으로 실행 |
| 과제 3 | `/about` 주소를 더한 v2를 8092번으로, v1과 동시에 실행 |
| 과제 4 | 코드만 고쳤을 때 `npm install`이 캐시로 건너뛰는지 확인 |
| 도전 (선택) | 빌드 없이 환경변수로 포트 바꾸기 |

### 준비

`hello` 앱의 파일 네 개를 새 폴더 `~/mission1`로 복사합니다.

```bash
mkdir -p ~/mission1
cd ~/ktcloud-cloud-native-lab/lab/docker/hello
cp app.js package.json package-lock.json .dockerignore ~/mission1/
cd ~/mission1
ls -a            # .  ..  .dockerignore  app.js  package-lock.json  package.json
```

- `cp 파일들 폴더/` = 파일을 그 폴더로 복사(cp = copy). `Dockerfile`은 복사하지 않습니다 — 직접 씁니다
- `ls -a` = `.`으로 시작하는 숨은 파일까지 모두 보기. `.dockerignore`가 보이면 됩니다

`app.js`의 문구가 `hello, docker`가 아니면(실습 7에서 고친 경우) nano로 `hello, docker`로 되돌립니다. 끝에 `// v3` 같은 줄이 붙어 있어도 괜찮습니다(주석이라 동작은 같음).

### 과제 1. Dockerfile을 처음부터 쓰기

**무엇을 하나요**: `~/mission1` 폴더에 `Dockerfile`을 만듭니다. "어떤 이미지에서 시작해 → 무엇을 복사하고 → 무엇을 설치하고 → 무엇을 실행하는지"를 순서대로 적는 일입니다.

아래 조건으로 `~/mission1/Dockerfile`을 쓰세요(`nano Dockerfile`).

- 베이스 이미지는 `node:22-alpine`, 앱은 3000번 포트
- 앱 코드(`app.js`)만 고쳤을 때 `npm install`이 **캐시로 건너뛰어지는 순서**

<details><summary>힌트 1</summary>

줄은 7개입니다: FROM · WORKDIR · COPY(라이브러리 목록) · RUN · COPY(나머지) · EXPOSE · CMD.
</details>
<details><summary>힌트 2</summary>

라이브러리 목록 파일은 `package.json`과 `package-lock.json` 두 개입니다. 이 둘만 먼저 `COPY`하고 `RUN npm install`, 그다음 `COPY . ./`.
</details>
<details><summary>힌트 3</summary>

각 줄이 하는 일을 다시 떠올려 보세요(실습 7 1단계의 표).

| 줄 | 하는 일 |
|---|---|
| `FROM` | 무엇이 들어 있는 이미지에서 시작하나 |
| `WORKDIR` | 이미지 안에서 일할 폴더 |
| `COPY` | VM의 파일을 이미지 안으로 |
| `RUN` | 이미지를 만들 때 실행할 명령 |
| `EXPOSE` | 앱이 쓰는 포트 메모 |
| `CMD` | 컨테이너를 시작할 때 실행할 명령(`["…", "…"]` 모양) |

다 쓴 뒤 `cat Dockerfile`로 7줄인지 확인합니다.
</details>

### 과제 2. v1 빌드하고 실행

**무엇을 하나요**: 과제 1의 Dockerfile로 이미지를 만들고, 컨테이너로 띄워 응답을 확인합니다.

이미지 `my-app:v1`을 빌드해 이름 `my-app1`, **VM 포트 8091**로 실행하세요. `curl localhost:8091`에 `hello, docker`가 나오면 됩니다.

<details><summary>힌트</summary>

`docker build -t 이름:태그 .` → `docker run -d --name … -p VM포트:컨테이너포트 이미지`. `-p`의 왼쪽이 VM, 오른쪽이 컨테이너입니다.
</details>
<details><summary>힌트 2 (막혔을 때 확인할 것)</summary>

- `docker build`는 `~/mission1` 폴더에서, 맨 끝의 `.`까지
- 컨테이너 안의 앱은 3000번에서 기다립니다. 그래서 `-p`의 오른쪽은 3000
- `docker ps`에 `my-app1`이 `Up`이고 PORTS가 `0.0.0.0:8091->3000/tcp`인지 확인
- 이름이 겹친다(`Conflict`)는 오류가 나면 `docker rm -f my-app1` 후 다시
</details>

### 과제 3. /about 주소를 더한 v2를 v1과 나란히

**무엇을 하나요**: 앱에 기능(`/about` 주소)을 하나 더하고 새 버전 이미지 v2를 만듭니다. v1은 그대로 둔 채 v2를 다른 포트로 띄워, 두 버전이 동시에 도는 것을 봅니다.

`app.js`에 아래 세 줄을 `app.listen(` 줄 **위에** 넣어 `/about` 주소를 만들고, `my-app:v2`로 빌드해 이름 `my-app2`, **VM 포트 8092**로 실행하세요. v1(8091)은 끄지 않습니다.

```js
app.get('/about', (req, res) => {
  res.send('my-app v2\n');
});
```

- `nano app.js` → 화살표로 `app.listen(port, () => {` 줄의 **맨 앞**으로 이동 → 세 줄을 붙여 넣고 Enter로 한 줄 띄움 → Ctrl+O → Enter → Ctrl+X
- `cat app.js`로 세 줄이 `app.listen(` 줄 위에 들어갔는지 확인합니다

다음을 확인하고 적으세요.

- `curl localhost:8092/about` → `my-app v2`
- `curl localhost:8091/about` → 무엇이 나오나요? 왜 그럴까요?
- `node -v`(VM)와 `docker exec my-app2 node -v`(컨테이너)의 결과도 적으세요. VM의 Node.js 버전과 상관없이 두 앱이 돌아가는 이유는?

<details><summary>힌트</summary>

v1 이미지는 `/about`을 넣기 전의 `app.js`로 만들어졌습니다. 없는 주소에 대한 Express의 기본 응답은 `Cannot GET /about`(상태 코드 404)입니다. 상태 코드는 `curl -I`로 봅니다.
</details>
<details><summary>힌트 2 (막혔을 때 확인할 것)</summary>

- 8092 `/about`도 `Cannot GET /about`이면: `app.js`를 고친 뒤 **v2를 빌드하지 않았거나**, v1 이미지로 실행한 것. `docker build -t my-app:v2 .` 다시 → `docker rm -f my-app2` → 다시 실행
- `SyntaxError`로 컨테이너가 바로 꺼지면(`docker ps`에 없음, `docker logs my-app2`에 오류): 세 줄을 넣은 위치나 괄호가 틀림. `cat app.js`로 확인
</details>

### 과제 4. 캐시가 됐는지 확인

**무엇을 하나요**: 과제 1에서 정한 줄 순서가 정말 빌드를 빠르게 하는지 확인합니다.

`app.js`만 한 번 더 고치고(예: `echo "// again" >> app.js`) `docker build -t my-app:v2 .`로 다시 빌드하세요. 빌드 출력에서 `npm install` 줄이 어떻게 표시되는지 적으세요. `CACHED`가 아니라면 과제 1의 Dockerfile 순서를 고쳐 다시 해 보세요.

<details><summary>힌트</summary>

캐시가 되는 순서라면 `=> CACHED [4/5] RUN npm install`이 보이고, 마지막 `COPY . ./`만 다시 실행됩니다.
</details>

### 도전 (선택). 포트를 환경변수로 바꾸기

**무엇을 하나요**: 이미지를 다시 만들지 않고, 실행할 때 넣는 설정(환경변수)만으로 앱의 동작(포트)을 바꿔 봅니다.

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

### 미션 1 정리
제출 표를 채운 뒤 컨테이너는 지워도 됩니다: `docker rm -f my-app1 my-app2 my-app3`. 미션 2와 포트가 겹치지 않으므로 두어도 됩니다.

---

## 미션 2. Compose로 Online Boutique 조립

**무엇을 하나요**: Online Boutique는 구글이 공개한 쇼핑몰 예제로, 서비스 11개와 Redis로 되어 있습니다. 이미 만들어진 공식 이미지를 받아 **Compose로 조립**합니다(빌드 없음). Kubernetes 과목부터 계속 쓰는 앱입니다. 실습 13에서 3개로 하던 일을 더 많은 서비스로 해 보고, 서비스 하나가 빠지면 어떤 일이 생기는지 로그로 찾아봅니다.

(서비스 = 한 가지 일만 하는 작은 프로그램. 쇼핑몰은 화면(frontend), 상품 목록, 환율, 장바구니, 배송비 계산 등이 각각 다른 컨테이너로 돕니다. Redis = 장바구니 내용을 저장하는 작은 DB)

| 과제 | 한 줄 요약 |
|---|---|
| 과제 1 | 서비스 5개로 쇼핑몰 홈 화면 띄우기 |
| 과제 2 | 장바구니 500 에러의 원인을 로그로 찾아 고치기 |
| 도전 A (선택) | redis를 다시 만들어도 장바구니가 남게(볼륨) |
| 도전 B (선택) | 11개 전체로 주문 완료까지 |

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

- 포트 = 그 서비스가 컨테이너 안에서 기다리는 번호. 서비스끼리는 이 번호로 부릅니다(실습 12의 `db:5432`처럼)
- `외부 공개` = 브라우저로 볼 frontend만 `ports:`로 VM 포트에 연결합니다. 나머지는 `ports:`가 필요 없습니다

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

**작업 순서(모든 과제 공통)**

| 순서 | 할 일 | 명령 |
|---|---|---|
| 1 | 폴더 만들고 들어가기 | `mkdir -p ~/shop && cd ~/shop` |
| 2 | 파일 쓰기 | `nano compose.yaml` → Ctrl+O → Enter → Ctrl+X |
| 3 | 문법 검사 | `docker compose config -q && echo OK` |
| 4 | 띄우기 | `docker compose up -d` |
| 5 | 상태 보기 | `docker compose ps` — 모두 `Up`인지 |
| 6 | 로그 보기 | `docker compose logs 서비스이름` |
| 7 | 다 내리기 | `docker compose down` |

명령은 모두 `~/shop` 폴더에서 칩니다(실습 13처럼 `compose.yaml`이 있는 폴더).

### 과제 1. 서비스 5개로 홈 화면 띄우기

**무엇을 하나요**: 쇼핑몰 홈 화면에 꼭 필요한 서비스 5개만 골라 `compose.yaml`에 적고 띄웁니다.

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
<details><summary>힌트 4 (막혔을 때 확인할 것)</summary>

- 파일 맨 위는 `services:` 한 줄, 그 아래 서비스 이름은 스페이스 2칸, 서비스 안의 `image:`·`environment:`는 4칸, 환경변수는 6칸(탭 금지)
- `docker compose config -q && echo OK`가 `OK`를 안 찍으면 오류 문구의 줄 번호(`L3.C1` = 3번째 줄)를 nano로 열어 고침
- 서비스 이름 오타(`productcatalogservice`를 `productcatalog`로 쓰는 등)가 있으면 frontend가 그 주소를 못 찾습니다. 표의 이름을 그대로 복사
- 처음에는 이미지를 받느라 `up -d`가 조금 걸립니다(받는 줄이 지나가는 동안 기다림)
</details>

### 과제 2. 장바구니가 안 된다

**무엇을 하나요**: 일부러 빠뜨린 서비스 때문에 생긴 오류를, 로그를 읽어 원인을 찾고 고칩니다. 여러 서비스로 된 앱에서 문제를 찾는 가장 기본적인 방법입니다.

상품을 담고 장바구니를 열면 **500 에러**(서버 오류)가 납니다. **로그로 원인을 찾아** 고치세요.

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

**무엇을 하나요**: 실습 10의 볼륨을 실제 앱에 적용해 봅니다.

상품을 담은 뒤 `docker compose up -d --force-recreate redis-cart`로 redis를 새로 만들면 장바구니가 비워집니다.
**redis를 새로 만들어도 장바구니가 남도록** 고치세요. 확인은 홈 오른쪽 위 장바구니 숫자로 합니다.

- `--force-recreate redis-cart` = 바뀐 것이 없어도 `redis-cart` 컨테이너를 지우고 새로 만듦

<details><summary>힌트 1</summary>

실습 10의 "이름 있는 볼륨"입니다. redis는 `/data`에 저장합니다.
</details>
<details><summary>힌트 2</summary>

redis는 기본 설정으로는 종료할 때만 저장합니다. 명령을 `redis-server --appendonly yes`로 바꾸면(`command:` 키) 쓸 때마다 저장합니다.
</details>

### 도전 B (선택). 11개 전체로 주문 완료

**무엇을 하나요**: 남은 서비스를 모두 더해 실제 쇼핑몰처럼 주문까지 해 봅니다. 필요한 설정을 다른 사람의 설정 파일에서 찾아 읽는 연습입니다.

나머지 서비스(recommendation, ad, payment, email, checkout)를 추가해 **주문 완료 화면**까지 가 보세요. 필요한 포트와 환경변수는 Online Boutique 저장소의 `kubernetes-manifests/<서비스>.yaml`에 있는 `env:`와 `containerPort`를 보고 찾습니다.

```bash
git clone --depth 1 --branch v0.10.7 https://github.com/GoogleCloudPlatform/microservices-demo.git ~/ob
ls ~/ob/kubernetes-manifests
```

- `--depth 1 --branch v0.10.7` = v0.10.7 버전의 최신 상태만 받음(기록 전체를 받지 않아 빠름)
- 파일 보기는 `cat ~/ob/kubernetes-manifests/<서비스>.yaml`. `env:` 아래 `name:`과 `value:`가 환경변수, `containerPort:`가 포트입니다

### 미션 2 제출 표

| 항목 | 내 결과 |
|---|---|
| 과제 1 홈 화면 캡처 | |
| 과제 2 원인 (한 줄) / `failed to get ads`인데 홈이 뜬 이유 | |
| (도전 A) 재생성 전·후 장바구니 숫자 (볼륨 없음 / 있음) | |
| (도전 B) 주문 완료 캡처 + `docker stats --no-stream` 가장 무거운 서비스 | |

- `docker stats --no-stream` = 컨테이너마다 쓰는 CPU·메모리를 한 번 보여 줌. `MEM USAGE` 열이 가장 큰 것이 가장 무거운 서비스

### 미션 2 정리
제출 표를 채운 뒤 `~/shop`에서 `docker compose down`으로 내립니다. 도전 A로 볼륨을 만들었다면 `docker compose down -v`.
