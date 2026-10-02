# Docker — 미션

미션은 실습에서 배운 것을 **스스로 조합해** 푸는 과제입니다. 실습처럼 명령을 다 적어 두지 않았습니다. 대신 막히면 펼쳐 볼 수 있는 힌트가 단계별로 있습니다.

- 스스로 풉니다. 막히면 **힌트를 1단계부터 하나씩** 펼쳐 보고(▶ 힌트 글자를 누르면 펼쳐짐), 그래도 막히면 Discord에 질문합니다.
- 미션마다 끝에 **결과 정리 표**가 있습니다. 리뷰 때 함께 보니 채워 두세요.
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

### 미션 1 결과 정리 표

| 항목 | 내 결과 |
|---|---|
| 과제 1 Dockerfile 전체 | |
| 과제 2 `docker ps`의 my-app1 줄 | |
| 과제 3 `curl localhost:8092/about` / `curl localhost:8091/about` 결과와 이유, VM·컨테이너 `node -v` | |
| 과제 4 다시 빌드한 출력의 `npm install` 줄 | |
| (도전) 실행 명령과 `docker logs my-app3` 결과 | |

### 미션 1 정리
결과 정리 표를 채운 뒤 컨테이너는 지워도 됩니다: `docker rm -f my-app1 my-app2 my-app3`. 미션 2와 포트가 겹치지 않으므로 두어도 됩니다.

---

## 미션 2. Compose로 Online Boutique 조립

**무엇을 하나요**: 구글이 공개한 쇼핑몰 예제 **Online Boutique**를 내 서버에 띄웁니다. 이 쇼핑몰은 프로그램 하나가 아니라 **작은 프로그램(서비스) 여러 개**가 서로 불러 가며 돌아갑니다. 실습 13에서 todo 앱(web · api · db 3개)을 `compose.yaml` 하나로 띄웠던 것과 **똑같은 방법**으로, 이번에는 서비스 5~6개를 띄웁니다. 이미지는 구글이 만들어 둔 것을 받아 쓰므로 **빌드(Dockerfile)는 없습니다**.

그다음 일부러 빠뜨린 서비스 때문에 화면에 오류가 났을 때, **로그를 읽어 원인을 찾는 연습**을 합니다. Kubernetes 과목부터 이 쇼핑몰을 계속 씁니다.

| 과제 | 한 줄 요약 |
|---|---|
| 과제 1 | 서비스 5개로 쇼핑몰 홈 화면 띄우기 |
| 과제 2 | 장바구니를 열면 나는 오류(500)를 로그로 찾아 고치기 |
| 도전 A (선택) | redis를 다시 만들어도 장바구니가 남게(볼륨) |
| 도전 B (선택) | 서비스 11개 전체로 주문 완료까지 |

### 먼저 그림으로 보기 — 쇼핑몰은 어떻게 돌아가나

브라우저로 쇼핑몰에 들어가면, 화면을 만드는 **frontend**가 필요한 정보를 다른 서비스들에게 물어봐서 한 화면으로 합칩니다.

```
                            ┌─▶ productcatalogservice   상품 목록 (3550번)
브라우저 ──▶ frontend ───────┼─▶ currencyservice          가격 환율 (7000번)
            화면 (8080번)    ├─▶ cartservice ──▶ redis-cart   장바구니 (7070번) → 저장 (6379번)
                            └─▶ shippingservice          배송비 계산 (50051번)
```

| 서비스 | 하는 일 | 실습 13에 빗대면 |
|---|---|---|
| frontend | 쇼핑몰 화면(HTML)을 만들어 브라우저에 보냄 | web |
| productcatalogservice | 상품 9개의 이름·사진·가격 목록 | api |
| currencyservice | 가격을 원하는 통화(USD, EUR …)로 바꿈 | api |
| cartservice | 장바구니에 담기·보기 | api |
| redis-cart | 장바구니 내용을 저장하는 작은 DB | db |
| shippingservice | 배송비 계산 — 장바구니 화면에서 씀 | api |

- 서비스 = 한 가지 일만 하는 작은 프로그램. 서비스마다 컨테이너 하나로 돕니다
- 서비스끼리는 **서비스 이름:포트**로 서로를 부릅니다. 실습 12·13에서 api가 `db:5432`로 DB를 부른 것과 같습니다
- 브라우저(바깥)에서 들어오는 곳은 frontend 하나뿐입니다. 그래서 **frontend만** VM 포트에 연결(`ports:`)합니다

**실습 13과 비교**

| | 실습 13 (todo) | 미션 2 (Online Boutique) |
|---|---|---|
| 서비스 수 | 3개 (web · api · db) | 5개 → 6개 (도전 B는 12개) |
| 이미지 | `build:`로 직접 빌드 | `image:`로 구글이 만든 것을 받음 — **빌드 없음** |
| 바깥 포트 | web만 `8088:80` | frontend만 `8080:8080` |
| 서로 부르는 법 | api의 `DB_HOST: db` | frontend의 주소 환경변수 8개(`PRODUCT_CATALOG_SERVICE_ADDR: productcatalogservice:3550` 등) |

### 준비 — 포트와 폴더

**1. 8080번이 비어 있는지 봅니다.** 앞 실습에서 8080을 쓰는 컨테이너가 남아 있으면 미션이 시작되지 않습니다.

```bash
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep 8080    # 아무것도 안 나오면 비어 있음
```

- 무언가 나오면 맨 앞 이름으로 지웁니다: `docker rm -f 이름`

**2. 미션 폴더를 만들고 들어갑니다.** 이후 명령은 **모두 이 폴더에서** 칩니다.

```bash
mkdir -p ~/shop && cd ~/shop
pwd              # /home/lab/shop
```

**3. 아래 정보를 과제에서 계속 씁니다.** 이름과 값은 **복사해서 붙여 넣으세요**(오타가 가장 흔한 원인입니다).

이미지 주소 — 모두 같은 모양이고 `<서비스>` 자리만 바뀝니다(redis만 `redis:alpine`).

```
us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo/<서비스>:v0.10.7
```

서비스별 포트와 환경변수

| 서비스 | 포트 | 넣어야 할 환경변수 |
|---|---|---|
| frontend | 8080 | `PORT: "8080"` + 아래 **주소 8개** |
| productcatalogservice | 3550 | `PORT: "3550"`, `DISABLE_PROFILER: "1"` |
| currencyservice | 7000 | `PORT: "7000"`, `DISABLE_PROFILER: "1"` |
| cartservice | 7070 | `REDIS_ADDR: "redis-cart:6379"` |
| redis-cart | 6379 | 없음 |
| shippingservice | 50051 | `PORT: "50051"`, `DISABLE_PROFILER: "1"` |

- `DISABLE_PROFILER: "1"` = 구글 클라우드에서만 쓰는 성능 측정 기능을 끄는 설정. 우리 서버에서는 꺼야 합니다
- 숫자 값은 따옴표로 감쌉니다(`"8080"`)

frontend의 주소 환경변수 8개 — 값은 `서비스이름:포트`

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

> ⚠️ **지금 띄우지 않는 서비스(recommendation, checkout, ad, shopping assistant)의 주소까지 8개 모두 넣어야 합니다.** frontend는 시작할 때 8개를 전부 확인하고, 하나라도 없으면 바로 꺼집니다. 주소는 "필요하면 여기로 부르겠다"는 메모라서, 그 서비스가 실제로 없어도 메모는 있어야 합니다.

### 과제 1. 서비스 5개로 홈 화면 띄우기

**무엇을 하나요**: frontend, productcatalogservice, currencyservice, cartservice, redis-cart 5개를 `~/shop/compose.yaml`에 적고 띄워서, 브라우저에서 **상품 9개가 있는 쇼핑몰 홈 화면**을 봅니다.

#### 1단계. compose.yaml 쓰기

`nano compose.yaml`로 파일을 엽니다. 아래는 **처음 두 서비스만 채운 뼈대**입니다. 그대로 붙여 넣은 뒤, 아래쪽 `# ← 직접 쓰기` 세 곳(currencyservice, cartservice, redis-cart)을 위 표를 보고 **productcatalogservice와 같은 모양으로** 채웁니다.

```yaml
services:
  frontend:
    image: us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo/frontend:v0.10.7
    ports:
      - "8080:8080"
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

  productcatalogservice:
    image: us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo/productcatalogservice:v0.10.7
    environment:
      PORT: "3550"
      DISABLE_PROFILER: "1"

  # ← 직접 쓰기: currencyservice (productcatalogservice와 같은 모양, 이름·포트만 다름)

  # ← 직접 쓰기: cartservice (환경변수는 REDIS_ADDR 하나)

  # ← 직접 쓰기: redis-cart (image: redis:alpine 한 줄이면 됨, 환경변수 없음)
```

**이 파일은**

| 줄 | 뜻 |
|---|---|
| `services:` | 이 아래에 띄울 서비스들을 적는다 (맨 앞, 들여쓰기 없음) |
| `  frontend:` | 서비스 이름. **이 이름이 다른 서비스가 부르는 주소**가 됨 (스페이스 2칸) |
| `    image:` | 받아서 쓸 이미지 (스페이스 4칸) |
| `    ports:` / `      - "8080:8080"` | VM 8080 → 컨테이너 8080. frontend에만 씀 |
| `    environment:` | 컨테이너에 넣을 환경변수. 그 아래 `이름: 값`은 스페이스 6칸 |
| `#`로 시작하는 줄 | 설명(주석). 무시됨. 다 채운 뒤 지워도 되고 둬도 됨 |

**들여쓰기가 가장 중요합니다.** 스페이스로만 맞추고 탭은 쓰지 않습니다.

```
services:                 ← 0칸
  frontend:               ← 2칸  서비스 이름
    image: …              ← 4칸  서비스 안의 설정
    environment:          ← 4칸
      PORT: "8080"        ← 6칸  환경변수 하나
```

다 쓰면 **Ctrl+O → Enter**(저장) → **Ctrl+X**(나가기). `cat compose.yaml`로 다시 한 번 봅니다.

#### 2단계. 문법 검사

```bash
docker compose config -q && echo OK
```

- `docker compose config` = compose.yaml을 읽어 문법이 맞는지 확인. `-q` = 내용을 길게 보여 주지 말고 확인만
- `&& echo OK` = 앞 명령이 성공했을 때만 OK를 찍음

**이렇게 나오면 성공**: `OK` 한 줄

**이렇게 나오면?**

| 화면 | 원인 | 해결 |
|---|---|---|
| 줄 번호가 들어간 오류(`line 12`, `L12.C3` 등) | 그 줄 들여쓰기가 틀림 | `nano compose.yaml` → 그 줄 앞 칸 수를 위 그림과 맞춤 |
| `found character that cannot start any token` | 탭이 들어감 | 그 줄 앞 공백을 지우고 스페이스로 다시 |
| `no configuration file provided: not found` | 지금 폴더가 `~/shop`이 아님 | `cd ~/shop` 후 다시 |

#### 3단계. 띄우기

```bash
docker compose up -d
```

- `up` = 파일에 적힌 서비스를 모두 만들고 시작. `-d` = 뒤에서 실행(터미널을 돌려줌)
- 처음에는 이미지 5개를 받느라 1분 안팎 걸립니다. 받는 줄이 지나가는 동안 기다립니다

**이렇게 나오면 성공** (마지막 부분)

```
 Container shop-productcatalogservice-1 Started
 Container shop-cartservice-1 Started
 Container shop-currencyservice-1 Started
 Container shop-redis-cart-1 Started
 Container shop-frontend-1 Started
```

#### 4단계. 5개가 모두 떠 있는지 확인

```bash
docker compose ps
```

**이렇게 나오면 성공** — 5줄 모두 `Up`, frontend의 PORTS에 `0.0.0.0:8080->8080`

```
NAME                           SERVICE                 STATUS         PORTS
shop-cartservice-1             cartservice             Up 10 seconds  7070/tcp
shop-currencyservice-1         currencyservice         Up 10 seconds  7000/tcp
shop-frontend-1                frontend                Up 10 seconds  0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp
shop-productcatalogservice-1   productcatalogservice   Up 10 seconds  3550/tcp
shop-redis-cart-1              redis-cart              Up 10 seconds  6379/tcp
```

- 이름 앞의 `shop-`은 폴더 이름입니다(실습 13 확인 문제 1)
- 줄이 5개보다 적으면 빠진 서비스가 꺼진 것입니다. `docker compose ps -a`로 멈춘 것까지 봅니다

#### 5단계. 화면 확인

먼저 터미널로 확인합니다.

```bash
curl -s -o /dev/null -w "%{http_code}\n" localhost:8080      # 200
```

- `-s` 진행 표시 숨김 · `-o /dev/null` 본문은 버림 · `-w "%{http_code}\n"` 상태 코드만 출력 → **200**이면 성공
- 방금 띄웠으면 몇 초 동안은 연결이 안 될 수 있습니다. 5초 뒤 다시

그다음 브라우저로 봅니다(문서 앞 "시작하기 전에" ⑧과 같은 방법).

1. VS Code 아래 패널에서 **PORTS** 탭 → **Forward a Port** → `8080` 입력 → Enter
2. 생긴 줄의 주소(지구 아이콘)를 눌러 `http://localhost:8080`을 엽니다

**이렇게 나오면 성공**: 맨 위에 "Online Boutique" 로고, 아래에 상품 사진 9개(Sunglasses, Tank Top, Watch, Loafers, Hairdryer, Candle Holder, Salt & Pepper Shakers, Bamboo Glass Jar, Mug). 이 화면을 캡처해 두면 리뷰 때 함께 봅니다.

**이렇게 나오면?**

| 증상 | 확인하는 명령과 화면 | 원인과 해결 |
|---|---|---|
| `docker compose ps`에 frontend가 없음 | `docker compose ps -a` → frontend `Exited (2)` / `docker compose logs frontend` → `panic: environment variable "SHOPPING_ASSISTANT_SERVICE_ADDR" not set` | 따옴표 안 이름의 환경변수가 빠졌거나 오타. 위 주소 8개 표와 비교해 고치고 `docker compose up -d` |
| 홈 화면이 `Uh, oh!` 오류(500) | `docker compose logs frontend \| grep -i error` → `lookup ○○○ … server misbehaving` | ○○○라는 서비스가 없음. 서비스 이름 오타(`productcatalog`처럼 줄여 씀)거나 서비스를 안 적음 |
| `port is already allocated` | `docker ps \| grep 8080` | 다른 컨테이너가 8080을 씀. 그 컨테이너를 `docker rm -f 이름`으로 지우고 다시 `up -d` |
| `curl`이 `Failed to connect` | `docker compose ps` | frontend가 아직 시작 중이거나 꺼짐. 5초 뒤 다시, 꺼졌으면 위 첫 줄 |
| 브라우저가 안 열림 | PORTS 탭에 8080 줄이 있는지 | Forward a Port를 다시. 주소는 `http://localhost:8080` |

**끝났는지 확인**
- ☐ `docker compose ps`에 5개 모두 `Up`
- ☐ `curl` 상태 코드 `200`
- ☐ 브라우저에서 상품 9개 홈 화면을 보고 캡처함

### 과제 2. 장바구니가 안 된다

**무엇을 하나요**: 홈 화면은 뜨지만 **장바구니를 열면 오류**가 납니다. 서비스 하나가 빠져 있기 때문입니다. 무엇이 빠졌는지 **로그를 읽어서** 찾고, 그 서비스를 더해 고칩니다. 여러 서비스로 된 앱에서 문제를 찾는 가장 기본적인 방법입니다.

#### 1단계. 오류를 직접 보기

브라우저에서 아무 상품이나 눌러 들어가 **Add To Cart**(장바구니 담기)를 누릅니다. 장바구니 화면으로 넘어가면서 오류 화면이 나옵니다.

- 화면에 `Uh, oh!`와 `HTTP Status: 500 Internal Server Error`가 보입니다
- 500 = **서버 안에서 오류가 났다**는 뜻(01장 HTTP 상태 코드). 내 잘못이 아니라 서버 쪽 문제입니다

터미널로도 확인합니다.

```bash
curl -s -o /dev/null -w "%{http_code}\n" localhost:8080/cart     # 500
```

#### 2단계. 로그에서 원인 찾기

화면을 만든 것은 frontend이니 frontend의 로그부터 봅니다. 로그가 길어서 `error`가 들어간 줄만 고릅니다.

```bash
docker compose logs frontend | grep -i error
```

- `docker compose logs frontend` = frontend 컨테이너가 화면(표준 출력)에 쓴 기록
- `| grep -i error` = 그중 `error`가 들어간 줄만(`-i` = 대소문자 구분 안 함). 실습 2의 파이프와 같음

**이렇게 나옵니다** (한 줄이 아주 길어서 화면에서는 여러 줄로 접혀 보입니다. 중요한 부분만 남겼습니다)

```
frontend-1  | {"error":"failed to get shipping quote: rpc error: code = Unavailable desc = dns: A record lookup error: lookup shippingservice on 127.0.0.11:53: server misbehaving", … "message":"request error" …}
frontend-1  | {"error":"failed to get ads: … lookup adservice on 127.0.0.11:53: server misbehaving", … "message":"failed to retrieve ads" …}
```

**첫 줄을 한 조각씩 읽기**

| 조각 | 뜻 |
|---|---|
| `failed to get shipping quote` | 배송비(shipping quote)를 가져오지 못함 ← 장바구니 화면은 배송비를 같이 보여 주므로 |
| `lookup shippingservice` | `shippingservice`라는 **이름을 찾아봤는데** |
| `server misbehaving` | 찾지 못함 = **그런 이름의 컨테이너가 없음** |
| `127.0.0.11:53` | Docker 안의 이름 찾기 담당(DNS). 실습 12에서 컨테이너 이름을 IP로 바꿔 주던 그것 |

→ 결론: **compose.yaml에 shippingservice가 없어서** 장바구니 화면이 배송비를 못 가져와 500이 났습니다.

#### 3단계. shippingservice 추가

`nano compose.yaml`을 열고 **맨 아래**에 shippingservice를 더합니다. productcatalogservice와 같은 모양에 이름과 포트만 다릅니다(표: 포트 50051, `PORT: "50051"`, `DISABLE_PROFILER: "1"`). 서비스 이름의 들여쓰기는 다른 서비스와 같은 2칸입니다.

저장한 뒤 문법 검사와 띄우기를 다시 합니다.

```bash
docker compose config -q && echo OK
docker compose up -d
```

**이렇게 나오면 성공** — 이미 떠 있던 5개는 `Running`(그대로 둠), shippingservice만 새로 생김

```
 Container shop-productcatalogservice-1 Running
 Container shop-currencyservice-1 Running
 Container shop-cartservice-1 Running
 Container shop-redis-cart-1 Running
 Container shop-shippingservice-1 Created
 Container shop-shippingservice-1 Started
```

- Compose는 **바뀐 것만** 새로 만듭니다(실습 13 확인 문제 2와 같음)

#### 4단계. 다시 확인

```bash
docker compose ps                                                 # 6개 모두 Up
curl -s -o /dev/null -w "%{http_code}\n" localhost:8080/cart     # 200
```

브라우저에서 장바구니를 다시 열면 담은 상품과 배송비(Shipping)가 보입니다.

#### 5단계. 생각해 보기 (결과 정리 표에 적기)

2단계 로그에 `failed to get ads`(광고를 못 가져옴)도 있었습니다. adservice도 없다는 뜻인데, **그런데도 홈 화면은 왜 정상으로 떴을까요?** 상품 화면 아래쪽 광고 자리가 지금 어떻게 보이는지 확인하고 한 줄로 적어 보세요.

**끝났는지 확인**
- ☐ 로그에서 `lookup shippingservice … server misbehaving` 줄을 찾음
- ☐ shippingservice를 추가했고 `docker compose ps`에 6개 `Up`
- ☐ 장바구니 `200`, 브라우저에서 장바구니 화면이 열림
- ☐ `failed to get ads`인데 홈이 뜬 이유를 한 줄로 적음

### 도전 A (선택). redis를 다시 만들어도 장바구니 유지

**무엇을 하나요**: 실습 10의 **볼륨**을 실제 앱에 써 봅니다. 장바구니 내용은 redis-cart 컨테이너 안에 저장되기 때문에, redis-cart를 새로 만들면 장바구니가 비어 버립니다. 볼륨을 붙여 다시 만들어도 남게 고칩니다.

1. 브라우저에서 상품을 하나 담습니다. 홈 오른쪽 위 장바구니 아이콘에 숫자 `1`이 붙습니다
2. redis-cart만 새로 만듭니다

```bash
docker compose up -d --force-recreate redis-cart
```

- `--force-recreate redis-cart` = 바뀐 것이 없어도 redis-cart 컨테이너를 지우고 새로 만듦(컨테이너가 고장 나서 다시 만든 상황을 흉내)

3. 홈을 새로고침하면 장바구니 숫자가 사라집니다(비었음). 이것을 막는 것이 과제입니다
4. `compose.yaml`의 redis-cart에 볼륨을 붙이고, 파일 맨 아래에 볼륨 이름을 적습니다(실습 13의 `db-data`와 같은 모양). redis가 데이터를 저장하는 폴더는 `/data`입니다
5. 저장 → `docker compose up -d` → 1~3을 다시 해서 이번에는 숫자가 **남는지** 확인합니다

<details><summary>힌트 1</summary>

실습 13 compose.yaml의 db 부분처럼 씁니다: redis-cart 안에 `volumes:` 아래 `- 볼륨이름:/data`, 파일 맨 아래(들여쓰기 없이) `volumes:` 아래에 `  볼륨이름:`.
</details>
<details><summary>힌트 2</summary>

볼륨을 붙였는데도 비면: redis는 기본으로 데이터를 메모리에만 두고 끝날 때 저장합니다. redis-cart에 `command: ["redis-server", "--appendonly", "yes"]`를 더하면 바뀔 때마다 파일에 적습니다.
</details>

### 도전 B (선택). 서비스 11개 전체로 주문 완료

**무엇을 하나요**: 남은 서비스(recommendationservice, adservice, paymentservice, emailservice, checkoutservice)를 모두 더해 **주문 완료 화면**까지 가 봅니다. 필요한 포트와 환경변수는 이 문서에 없습니다 — **Online Boutique 원본 저장소의 설정 파일을 읽어서** 찾는 연습입니다(실무에서 남이 만든 앱을 띄울 때 하는 일).

1. 원본 저장소를 받습니다

```bash
git clone --depth 1 --branch v0.10.7 https://github.com/GoogleCloudPlatform/microservices-demo.git ~/ob
ls ~/ob/kubernetes-manifests
```

- `--depth 1 --branch v0.10.7` = v0.10.7 버전의 최신 상태만 받음(기록 전체를 받지 않아 빠름)
- `kubernetes-manifests/` = 서비스마다 Kubernetes 설정 파일이 하나씩 있음. 다음 과목에서 이 파일들을 그대로 씁니다

2. 서비스 하나씩 열어 **포트**와 **환경변수**를 찾습니다

```bash
cat ~/ob/kubernetes-manifests/checkoutservice.yaml
```

| 파일에서 찾을 곳 | 뜻 | compose.yaml에서는 |
|---|---|---|
| `containerPort: 5050` | 그 서비스가 기다리는 포트 | 다른 서비스가 부르는 주소의 포트 |
| `env:` 아래 `- name: PORT` / `value: "5050"` | 환경변수 하나 | `environment:` 아래 `PORT: "5050"` |
| `image: checkoutservice` | 이미지 이름 | 위 이미지 주소 모양에 이름만 넣음 |

3. 다섯 서비스를 compose.yaml에 더하고 `docker compose up -d` → `docker compose ps`로 모두 `Up`인지 봅니다
4. 브라우저에서 상품 담기 → 장바구니 → **Place Order**(주문하기)를 눌러 주문 완료 화면을 봅니다
5. `docker stats --no-stream`으로 가장 무거운 서비스를 찾습니다

- `docker stats --no-stream` = 컨테이너마다 쓰는 CPU·메모리를 한 번 보여 줌. `MEM USAGE` 열이 가장 큰 것이 가장 무거운 서비스

<details><summary>힌트</summary>

- 막히면 그 서비스의 로그(`docker compose logs 서비스이름`)부터 봅니다. 환경변수가 빠지면 대개 시작하자마자 꺼지며 어떤 이름이 없는지 알려 줍니다
- checkoutservice는 다른 서비스를 많이 부르므로(장바구니·상품·배송·환율·결제·메일) 주소 환경변수가 여러 개입니다
</details>

### 미션 2 결과 정리 표

| 항목 | 내 결과 |
|---|---|
| 과제 1 홈 화면 캡처 | |
| 과제 2 원인 (한 줄) / `failed to get ads`인데 홈이 뜬 이유 | |
| (도전 A) 재생성 전·후 장바구니 숫자 (볼륨 없음 / 있음) | |
| (도전 B) 주문 완료 캡처 + `docker stats --no-stream` 가장 무거운 서비스 | |

- `docker stats --no-stream` = 컨테이너마다 쓰는 CPU·메모리를 한 번 보여 줌. `MEM USAGE` 열이 가장 큰 것이 가장 무거운 서비스

### 미션 2 정리
결과 정리 표를 채운 뒤 `~/shop`에서 `docker compose down`으로 내립니다. 도전 A로 볼륨을 만들었다면 `docker compose down -v`.
