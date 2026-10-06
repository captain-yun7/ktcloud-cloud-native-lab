[← 미션 1](./01-내-앱-이미지-만들기.md) · [목차](../Docker-미션.md)

# 미션 2. Compose로 Online Boutique 조립

**무엇을 하나요**: 구글이 공개한 쇼핑몰 예제 **Online Boutique**를 내 서버에 띄웁니다. 이 쇼핑몰은 프로그램 하나가 아니라 **작은 프로그램(서비스) 여러 개**가 서로 불러 가며 돌아갑니다. 실습 13에서 todo 앱(web · api · db 3개)을 `compose.yaml` 하나로 띄웠던 것과 **똑같은 방법**으로, 이번에는 서비스 5~6개를 띄웁니다. 이미지는 구글이 만들어 둔 것을 받아 쓰므로 **빌드(Dockerfile)는 없습니다**.

그다음 일부러 빠뜨린 서비스 때문에 화면에 오류가 났을 때, **로그를 읽어 원인을 찾는 연습**을 합니다. Kubernetes 과목부터 이 쇼핑몰을 계속 씁니다.

| 과제 | 한 줄 요약 |
|---|---|
| 과제 1 | 서비스 5개로 쇼핑몰 홈 화면 띄우기 |
| 과제 2 | 장바구니를 열면 나는 오류(500)를 로그로 찾아 고치기 |
| 도전 A (선택) | redis를 다시 만들어도 장바구니가 남게(볼륨) |
| 도전 B (선택) | 서비스 11개 전체로 주문 완료까지 |

> **바로 가기** · [Online Boutique는 어떤 앱인가요](#online-boutique는-어떤-앱인가요) · [먼저 그림으로 보기 — 쇼핑몰은 어떻게 돌아가나](#먼저-그림으로-보기--쇼핑몰은-어떻게-돌아가나) · [준비 — 포트와 폴더](#준비--포트와-폴더) · [과제 1. 서비스 5개로 홈 화면 띄우기](#과제-1-서비스-5개로-홈-화면-띄우기) · [과제 2. 장바구니가 안 된다](#과제-2-장바구니가-안-된다) · [도전 A (선택). redis를 다시 만들어도 장바구니 유지](#도전-a-선택-redis를-다시-만들어도-장바구니-유지) · [도전 B (선택). 서비스 11개 전체로 주문 완료](#도전-b-선택-서비스-11개-전체로-주문-완료) · [미션 2 결과 정리 표](#미션-2-결과-정리-표) · [미션 2 정리](#미션-2-정리)

## Online Boutique는 어떤 앱인가요

- 구글이 공개한 **오픈소스 쇼핑몰 예제**입니다([GoogleCloudPlatform/microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo), 우리는 v0.10.7 사용). 상품 보기 → 장바구니 → 주문까지 실제 쇼핑몰처럼 동작합니다
- 목적은 장사가 아니라 **마이크로서비스(MSA)를 보여 주는 것**입니다. 쇼핑몰 기능을 작은 서비스 11개로 나눠, 서비스마다 컨테이너 하나로 돌립니다
- 회원가입이 없습니다. 접속하면 자동으로 세션(쿠키)이 생기고, 장바구니는 그 세션에 붙습니다
- 결제·메일·배송은 **가짜**입니다. 카드 번호를 넣어도 돈이 나가지 않고, 메일은 보내는 대신 로그에만 남습니다

**서비스마다 만든 언어가 다릅니다**

| 서비스 | 언어 | 하는 일 | 미션 2에서 |
|---|---|---|---|
| frontend | Go | 쇼핑몰 화면(HTTP). 브라우저가 들어오는 유일한 입구 | 과제 1 |
| productcatalogservice | Go | 상품 9개 목록·검색 | 과제 1 |
| currencyservice | Node.js | 가격을 다른 통화로 변환 | 과제 1 |
| cartservice | C# (.NET) | 장바구니 담기·보기. 내용은 redis에 저장 | 과제 1 |
| redis-cart | Redis | 장바구니 저장소(DB) | 과제 1 |
| shippingservice | Go | 배송비 계산, 배송 접수(가짜) | 과제 2 |
| recommendationservice | Python | "이것도 보세요" 추천 상품 | 도전 B |
| adservice | Java | 상품 화면의 텍스트 광고 | 도전 B |
| paymentservice | Node.js | 카드 결제(가짜) | 도전 B |
| emailservice | Python | 주문 확인 메일(가짜) | 도전 B |
| checkoutservice | Go | 주문 총괄 — 장바구니·결제·배송·메일을 차례로 부름 | 도전 B |

- 원본에는 부하 생성기(loadgenerator, 사용자처럼 계속 접속하는 프로그램)와 AI 쇼핑 도우미(shoppingassistantservice, 구글 클라우드 전용)도 있지만 이 미션에서는 띄우지 않습니다
- **언어가 달라도 함께 돌아가는 이유**: 서비스끼리는 정해진 형식(gRPC)으로만 대화하므로, 상대가 어떤 언어로 만들어졌는지 알 필요가 없습니다. 로그에 보이는 `rpc error`가 이 대화가 실패했다는 뜻입니다
- **우리는 코드를 고치지 않습니다.** 구글이 만들어 둔 이미지를 받아 띄우고, 엮고, 고장 난 곳을 찾을 뿐입니다. Go·C#·Java를 몰라도 됩니다. 언어가 무엇이든 컨테이너 이미지가 되면 다루는 방법이 같다는 것이 이 미션에서 확인할 점입니다
- Kubernetes·클라우드 보안·서비스 메시·모니터링 과목에서도 이 쇼핑몰을 계속 씁니다

## 먼저 그림으로 보기 — 쇼핑몰은 어떻게 돌아가나

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

## 준비 — 포트와 폴더

**1. 8080번이 비어 있는지 봅니다.** 앞 실습에서 8080을 쓰는 컨테이너가 남아 있으면 미션이 시작되지 않습니다.

```bash
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep 8080    # 아무것도 안 나오면 비어 있음
```

- 무언가 나오면 맨 앞 이름으로 지웁니다: `docker rm -f 이름`

**2. 작업 폴더 `~/shop`을 만들고 들어갑니다.** 미션 2의 `compose.yaml`은 이 폴더에 두고, 이후 명령은 **모두 이 폴더에서** 칩니다. 폴더 이름이 컨테이너 이름 앞에 붙으므로(`shop-frontend-1`) 이름을 `shop`으로 맞춰 주세요.

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

## 과제 1. 서비스 5개로 홈 화면 띄우기

**무엇을 하나요**: frontend, productcatalogservice, currencyservice, cartservice, redis-cart 5개를 `~/shop/compose.yaml`에 적고 띄워서, 브라우저에서 **상품 9개가 있는 쇼핑몰 홈 화면**을 봅니다.

### 1단계. compose.yaml 쓰기

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

### 2단계. 문법 검사

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

### 3단계. 띄우기

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

### 4단계. 5개가 모두 떠 있는지 확인

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

### 5단계. 화면 확인

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

## 과제 2. 장바구니가 안 된다

**무엇을 하나요**: 홈 화면은 뜨지만 **장바구니를 열면 오류**가 납니다. 서비스 하나가 빠져 있기 때문입니다. 무엇이 빠졌는지 **로그를 읽어서** 찾고, 그 서비스를 더해 고칩니다. 여러 서비스로 된 앱에서 문제를 찾는 가장 기본적인 방법입니다.

### 1단계. 오류를 직접 보기

브라우저에서 아무 상품이나 눌러 들어가 **Add To Cart**(장바구니 담기)를 누릅니다. 장바구니 화면으로 넘어가면서 오류 화면이 나옵니다.

- 화면에 `Uh, oh!`와 `HTTP Status: 500 Internal Server Error`가 보입니다
- 500 = **서버 안에서 오류가 났다**는 뜻(01장 HTTP 상태 코드). 내 잘못이 아니라 서버 쪽 문제입니다

터미널로도 확인합니다.

```bash
curl -s -o /dev/null -w "%{http_code}\n" localhost:8080/cart     # 500
```

### 2단계. 로그에서 원인 찾기

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

### 3단계. shippingservice 추가

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

### 4단계. 다시 확인

```bash
docker compose ps                                                 # 6개 모두 Up
curl -s -o /dev/null -w "%{http_code}\n" localhost:8080/cart     # 200
```

브라우저에서 장바구니를 다시 열면 담은 상품과 배송비(Shipping)가 보입니다.

### 5단계. 생각해 보기 (결과 정리 표에 적기)

2단계 로그에 `failed to get ads`(광고를 못 가져옴)도 있었습니다. adservice도 없다는 뜻인데, **그런데도 홈 화면은 왜 정상으로 떴을까요?** 상품 화면 아래쪽 광고 자리가 지금 어떻게 보이는지 확인하고 한 줄로 적어 보세요.

**끝났는지 확인**
- ☐ 로그에서 `lookup shippingservice … server misbehaving` 줄을 찾음
- ☐ shippingservice를 추가했고 `docker compose ps`에 6개 `Up`
- ☐ 장바구니 `200`, 브라우저에서 장바구니 화면이 열림
- ☐ `failed to get ads`인데 홈이 뜬 이유를 한 줄로 적음

## 도전 A (선택). redis를 다시 만들어도 장바구니 유지

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

## 도전 B (선택). 서비스 11개 전체로 주문 완료

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

## 미션 2 결과 정리 표

| 항목 | 내 결과 |
|---|---|
| 과제 1 홈 화면 캡처 | |
| 과제 2 원인 (한 줄) / `failed to get ads`인데 홈이 뜬 이유 | |
| (도전 A) 재생성 전·후 장바구니 숫자 (볼륨 없음 / 있음) | |
| (도전 B) 주문 완료 캡처 + `docker stats --no-stream` 가장 무거운 서비스 | |

- `docker stats --no-stream` = 컨테이너마다 쓰는 CPU·메모리를 한 번 보여 줌. `MEM USAGE` 열이 가장 큰 것이 가장 무거운 서비스

## 미션 2 정리
결과 정리 표를 채운 뒤 `~/shop`에서 `docker compose down`으로 내립니다. 도전 A로 볼륨을 만들었다면 `docker compose down -v`.
