[목차](../API-Gateway-미션.md)

# 미션. Online Boutique 앞문

**상황**: 쇼핑몰(Online Boutique, `shop`)은 지금 앞 과목의 Traefik 입구(`shop.localhost`, 80)로만 열려 있습니다. 이번에 게이트웨이 입구 `front`(8080)에도 쇼핑몰을 열고, **제휴 파트너**용 길을 하나 따로 냅니다. 파트너는 `shop.localhost:8080/partner/…`로 상품 페이지를 가져가는데, **키가 있는 파트너만**, **파트너마다 1분에 10번까지**만 받습니다. 손님(브라우저)은 지금처럼 키 없이 씁니다. 마지막으로 쇼핑몰 입구도 **HTTPS**로 바꿉니다.

언제: 실습 8(07장) 뒤. 필요한 것: 실습 1~8(입구 `front`, 키·속도 제한 정책 쓰는 법, 실습 8의 CA `~/apigw/tls/`와 port-forward 8443).

> **바로 가기** · [과제 1. 손님 입구 — shop.localhost:8080](#과제-1-손님-입구--shoplocalhost8080) · [과제 2. 파트너 경로 나누기 — /partner](#과제-2-파트너-경로-나누기--partner) · [과제 3. 파트너 경로에만 키](#과제-3-파트너-경로에만-키) · [과제 4. 파트너마다 1분에 10번](#과제-4-파트너마다-1분에-10번) · [과제 5. 쇼핑몰 입구도 HTTPS로](#과제-5-쇼핑몰-입구도-https로) · [도전 A (선택). 막힌 수를 Prometheus에서](#도전-a-선택-막힌-수를-prometheus에서) · [도전 B (선택). 손님 입구에 3초 제한](#도전-b-선택-손님-입구에-3초-제한) · [결과 정리 표 (리뷰 때 함께 봄)](#결과-정리-표-리뷰-때-함께-봄)

## 과제 1. 손님 입구 — shop.localhost:8080

입구 `front`에 쇼핑몰을 엽니다. 확인: `curl -s -o /dev/null -w "%{http_code}\n" shop.localhost:8080` → `200`. Traefik 쪽 `shop.localhost`(80)도 그대로 `200`. 브라우저(PORTS 8080)로도 열어 봅니다.

먼저 지금 상태를 봅니다: `shop.localhost:8080`은 `404`(입구는 있는데 `shop.localhost` 경로가 없음).

<details><summary>힌트 1 — 어디서 시작하나</summary>

실습 1의 5단계 `todo-route.yaml`과 같은 모양입니다. 네임스페이스는 `shop`, 이름은 `shop.localhost`, 보낼 곳은 Service `frontend` 80번(`kubectl -n shop get svc frontend`).
</details>

## 과제 2. 파트너 경로 나누기 — /partner

파트너는 `shop.localhost:8080/partner/product/OLJCESPC7Z`처럼 앞에 `/partner`를 붙여 부릅니다. 쇼핑몰(frontend)에는 `/partner`라는 경로가 없으므로, 입구에서 **앞의 `/partner`를 떼고** frontend의 `/product/OLJCESPC7Z`로 보냅니다. 손님 경로(과제 1)와 **다른 HTTPRoute**(`shop-partner`)로 만듭니다.

확인: 지금(과제 2 전) `shop.localhost:8080/partner/product/OLJCESPC7Z` → `404`. 과제 2 뒤 → `200`, 본문에 `Sunglasses`.

<details><summary>힌트 2 — 경로 조건</summary>

실습 2의 2단계처럼 `matches: - path: type: PathPrefix, value: /partner`. `/partner`가 `/`보다 길어서 손님 경로보다 먼저 맞습니다.
</details>
<details><summary>힌트 3 — 앞부분 떼기(URLRewrite)</summary>

규칙 안, `backendRefs`와 같은 칸에 필터를 넣습니다(실습 2의 5단계 `filters`와 같은 자리).

```yaml
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /
```

`ReplacePrefixMatch` = 맞은 앞부분(`/partner`)을 `/`로 바꿈 → `/partner/product/X`가 `/product/X`가 됨.
</details>

## 과제 3. 파트너 경로에만 키

파트너 둘의 키를 Secret에 넣고, `shop-partner`에만 키 검사를 붙입니다. 앱(frontend)에는 파트너 이름을 `x-partner` 헤더로 넘기고, 키는 넘기지 않습니다.

| 파트너 | 키 |
|---|---|
| `partner-a` | `pa-7c1e` |
| `partner-b` | `pb-93d0` |

확인: 키 없이 `/partner/product/OLJCESPC7Z` → `401`, `partner-a`의 키 → `200`, **손님 경로**(`/`, `/product/OLJCESPC7Z`)는 키 없이 `200`.

<details><summary>힌트 4 — 무엇을 바꾸나</summary>

실습 3의 `apikey.yaml`을 복사(`cp ~/apigw/apikey.yaml ~/apigw/partner-key.yaml`)해서 네임스페이스, Secret 이름과 내용, `targetRefs`의 HTTPRoute 이름, `forwardClientIDHeader`를 바꿉니다.
</details>

## 과제 4. 파트너마다 1분에 10번

파트너 이름(`x-partner`)마다 1분에 10번까지만 받습니다. 확인: `partner-b`의 키로 11번 연달아 → 마지막만 `429`. 그 직후 `partner-a`는 `200`, 손님 경로도 `200`.

<details><summary>힌트 5 — 무엇을 바꾸나</summary>

실습 5의 `ratelimit.yaml`에서 네임스페이스, `targetRefs`, 헤더 이름, 횟수. 11번은 실습 5의 1단계 명령에서 `seq 1 11`.
</details>

## 과제 5. 쇼핑몰 입구도 HTTPS로

실습 8에서 todo에 한 것을 쇼핑몰에 합니다. 실습 8의 CA로 `shop.localhost` 인증서를 만들고, 입구에 `shop.localhost`용 HTTPS 리스너(창구)를 하나 더 열고, 손님 경로를 그 창구로 옮기고, HTTP로 온 손님은 HTTPS로 넘겨 보냅니다.

확인(port-forward 8443이 떠 있어야 함 — 실습 8 3단계 나):

- 과제 5 전: `curl -s --cacert ~/apigw/tls/ca.crt -o /dev/null -w "%{http_code}\n" https://shop.localhost:8443/` → `000`(연결 안 됨). 입구가 연결을 끊어서 8443 잇기도 한 번 끊겼다가 다시 이어집니다 — 다음 명령은 3초 뒤에
- 과제 5 뒤: 같은 명령 → `200`. `curl -s -o /dev/null -w "%{http_code} %{redirect_url}\n" shop.localhost:8080/` → `301 https://shop.localhost:8443/`
- 파트너 경로도 HTTPS에서 그대로: 키 없이 `401`, `pa-7c1e`로 `200`. Traefik(`shop.localhost`, 80)은 그대로 `200`

<details><summary>힌트 7 — 인증서와 Secret</summary>

실습 8 2단계의 넷째 줄에서 이름 두 곳(`/CN=…`, `DNS:…`)과 파일 이름(`todo.key`·`todo.crt`)을 `shop`으로 바꿉니다. `~/apigw/tls`에서 해야 `ca.crt`·`ca.key`를 찾습니다. Secret 이름은 `shop-tls`, 네임스페이스는 입구와 같은 `gateway`.
</details>

<details><summary>힌트 8 — 리스너와 경로</summary>

`gateway.yaml`에 실습 8 3단계의 `- name: https` 덩어리를 한 번 더 붙이고, `name`을 `https-shop`, `hostname`을 `shop.localhost`, 인증서를 `shop-tls`로. `port: 443`은 그대로입니다.

손님 경로(`shop`)는 `parentRefs`에 `sectionName: https-shop`을 한 줄 더해 다시 apply합니다. 넘겨 보내기는 실습 8의 `todo-redirect.yaml`을 복사해 이름·네임스페이스·`hostnames`를 쇼핑몰 것으로.
</details>

## 도전 A (선택). 막힌 수를 Prometheus에서

실습 5의 6단계 쿼리로 지금까지 입구가 막은 429와 401 수를 다시 보세요. 과제 3·4에서 늘어난 만큼 늘었나요? 쇼핑몰(frontend)의 Istio 지표에는 그 요청이 있나요?

## 도전 B (선택). 손님 입구에 3초 제한

상품 서비스가 느려지면 손님은 얼마나 기다려야 할까요? 손님 경로(`shop`)에 **요청 전체 3초 제한**을 넣고(실습 6 2단계), 상품 서비스를 일부러 5초 늦춰 두 입구를 비교합니다. 과제 5 뒤라 게이트웨이 쪽은 HTTPS 주소로 부릅니다. 끝나면 **꼭 되돌립니다**.

```bash
kubectl -n shop set env deploy/productcatalogservice EXTRA_LATENCY=5s     # 느리게
kubectl -n shop rollout status deploy/productcatalogservice
sleep 15
curl -s --cacert ~/apigw/tls/ca.crt -o /dev/null -w "게이트웨이 %{http_code} %{time_total}\n" https://shop.localhost:8443/
curl -s -o /dev/null -w "Traefik %{http_code} %{time_total}\n" shop.localhost
kubectl -n shop set env deploy/productcatalogservice EXTRA_LATENCY-       # 되돌리기
```

<details><summary>힌트 6 — 3초 제한</summary>

실습 6 2단계와 같습니다. 손님 경로 HTTPRoute 규칙 안, `backendRefs`와 같은 칸에

```yaml
    timeouts:
      request: 3s
```

과제 5에서 넣은 `sectionName: https-shop`은 그대로 둡니다.
</details>

## 결과 정리 표 (리뷰 때 함께 봄)

| # | 확인 | 내 결과 |
|---|---|---|
| 과제 1 | `shop.localhost:8080` / `shop.localhost` 응답 코드 | |
| 과제 2 | 과제 2 전·후 `/partner/product/OLJCESPC7Z` 응답 코드 | |
| 과제 3 | 키 없음 / `pa-7c1e` / 손님 경로 응답 코드 | |
| 과제 4 | partner-b 11번 결과, 직후 partner-a | |
| 과제 5 | 과제 5 전·후 `https://shop.localhost:8443/`, `shop.localhost:8080/`의 코드와 넘겨 보낸 주소 | |
| 도전 A | 429 수(전·후), frontend 지표에 있었나 | |
| 도전 B | 두 입구의 응답 코드·걸린 시간 | |
| 정리 | HTTPRoute 둘로 나눈 이유 한 줄 | |
| 생각해 볼 것 | 과제 5 뒤 `http://shop.localhost:8080/partner/…`(키 있음)는 어떻게 되나? 파트너도 HTTPS로만 받으려면? | |
