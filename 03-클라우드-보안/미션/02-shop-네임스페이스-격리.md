[← 미션 1](./01-취약한-memo-api-고치기.md) · [목차](../클라우드-보안-미션.md)

# 미션 2. shop 네임스페이스 격리

**무엇을 하나요**: Kubernetes 실습 12에서 Helm으로 설치해 본 쇼핑몰 Online Boutique(`shop`, 서비스 11개)를 아래 요구사항 1~5에 맞춥니다. `shop`에 restricted 라벨을 붙여도 11개 서비스가 모두 Ready, 다른 네임스페이스(`other`의 `t`)에서는 shop 어디에도 못 닿고, Traefik → frontend와 cartservice → redis-cart만 열어 둡니다. 단 **쇼핑몰은 그대로 동작해야** 합니다(홈, 장바구니 담기). 실습 7(NetworkPolicy)·8(Pod Security Admission)을 실제 서비스 11개에 적용하는 미션입니다.

| 과제 | 한 줄 요약 |
|---|---|
| 과제 1 | restricted 수준에서 11개 서비스 모두 Ready |
| 과제 2 | 다른 네임스페이스에서는 아무 데도 못 닿게, Traefik → frontend만 열기 |
| 과제 3 | redis-cart는 cartservice만 닿게, 쇼핑몰 기능 유지 |
| 도전 (선택) | Kyverno 메모리 limit 정책, 읽기 전용 계정, 차트 기본 정책과 비교 |

> **바로 가기** · [준비](#준비) · [과제 1. restricted에서 11개 모두 Ready](#과제-1-restricted에서-11개-모두-ready) · [과제 2. 밖은 막고 Traefik → frontend만 열기](#과제-2-밖은-막고-traefik--frontend만-열기) · [과제 3. redis-cart는 cartservice만, 쇼핑몰 기능 유지](#과제-3-redis-cart는-cartservice만-쇼핑몰-기능-유지) · [도전 (선택)](#도전-선택) · [미션 2 결과 정리 표](#미션-2-결과-정리-표) · [미션 2 정리](#미션-2-정리)

## 준비

Kubernetes 실습 12와 같은 값으로 shop을 설치하되, 이번에는 **설치 전에 restricted 라벨을 먼저** 붙입니다.

```bash
kubectl get ingressclass                      # traefik이 보여야 함 (없으면 cd ~/ktcloud-cloud-native-lab/lab && make ingress)
ls ~/ob/helm-chart || git clone --depth 1 --branch v0.10.7 https://github.com/GoogleCloudPlatform/microservices-demo.git ~/ob
mkdir -p ~/sec/shop && cd ~/sec/shop
cat > my-values.yaml <<'EOF'
frontend:
  externalService: false
loadGenerator:
  create: false
EOF
cat > shop-ingress.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: shop
  namespace: shop
spec:
  rules:
  - host: shop.localhost
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service: {name: frontend, port: {number: 80}}
EOF
helm list -A                                  # 다른 shop이 남아 있으면 helm uninstall … 로 지움 (쇼핑몰은 한 벌만)
kubectl create namespace shop
kubectl label namespace shop pod-security.kubernetes.io/enforce=restricted
helm install shop ~/ob/helm-chart -n shop -f my-values.yaml
kubectl apply -f shop-ingress.yaml
kubectl -n shop get deploy          # 20초쯤 뒤 — 무슨 일이 일어났나요?
```

**이 명령은**
- 첫 두 줄 = Ingress(Traefik)와 차트 폴더 `~/ob`가 있는지 확인(Kubernetes 실습 11·12). 없으면 뒤의 명령이 받아 옴
- `cat > 파일 <<'EOF' … EOF` = 두 `EOF` 사이 글을 파일로 저장. `my-values.yaml` = 차트 기본값 중 바꿀 것(외부 주소 끄기, 부하 발생기 끄기 — Kubernetes 실습 12와 같음). `shop-ingress.yaml` = `shop.localhost`로 frontend에 들어가게 함
- `helm list -A` = 모든 네임스페이스의 Helm 설치 목록. 노드가 4코어라 쇼핑몰은 **한 벌만** 띄울 수 있습니다
- 네임스페이스를 먼저 만들어 restricted 라벨을 붙인 뒤 같은 값으로 설치(`--wait` 없이)하고, Deployment들의 상태를 봅니다

**요구사항** (과제 1~3에서 하나씩 맞춥니다)

| # | 요구 | 확인 방법 |
|---|---|---|
| 1 | `shop`은 **restricted** 수준에서 11개 서비스가 모두 Ready | `kubectl -n shop get deploy` |
| 2 | 밖(다른 네임스페이스)에서는 shop의 **어떤 서비스에도 닿지 않음** | `kubectl -n other exec t -- nc -z -w 3 frontend.shop 80`, `productcatalogservice.shop 3550` → 막힘 |
| 3 | 단, **Traefik(Ingress)은 frontend에** 닿음 | `curl -s -o /dev/null -w "%{http_code}\n" shop.localhost` → 200 |
| 4 | **redis-cart에는 cartservice만** 닿음 | shop 안의 다른 파드에서 `nc -z redis-cart 6379` → 막힘 |
| 5 | 쇼핑몰 기능 유지 | 브라우저에서 상품을 장바구니에 담고 `Cart (1)` 확인 |

- 요구 1은 차트 값(values)으로, 2~4는 NetworkPolicy YAML로 풉니다
- 결과는 **표로** 확인합니다(아래 결과 정리 표). "된 것 같다"는 통과가 아닙니다

**이렇게 나오면?**
| 화면 | 원인 | 해결 |
|---|---|---|
| `cannot re-use a name that is still in use` | `shop`이 이미 있음 | `helm uninstall shop -n shop; kubectl delete namespace shop` 후 준비를 처음부터 |
| `Error from server (AlreadyExists): namespaces "shop" already exists` | 이전 shop 네임스페이스가 남음 | 위와 같음 |
| `Error: path "/home/lab/ob/helm-chart" not found` | 차트 폴더가 없음 | 둘째 줄(`git clone …`)을 다시 |

## 과제 1. restricted에서 11개 모두 Ready

**무엇을 하나요**: 준비의 마지막 명령에서 Deployment가 하나도 Ready가 아닌 이유를 찾고, 차트 값 하나를 바꿔 `helm upgrade`로 11개를 모두 띄웁니다.

<details><summary>힌트 1 — 파드가 하나도 안 뜬다</summary>

실습 8의 4단계와 같은 상황입니다. `kubectl -n shop get events --field-selector reason=FailedCreate`의 메시지를 보세요. 이유가 **딱 하나**입니다.
</details>
<details><summary>힌트 2 — 차트에 그 설정이 있나</summary>

`helm show values ~/ob/helm-chart | grep -A2 seccomp` — 찾은 값을 `my-values.yaml`에 더하고 `helm upgrade shop ~/ob/helm-chart -n shop -f my-values.yaml --wait`(Kubernetes 실습 12)로 적용합니다.
</details>

## 과제 2. 밖은 막고 Traefik → frontend만 열기

**무엇을 하나요**: NetworkPolicy로 shop을 "전부 막고 하나씩 여는" 상태로 만듭니다. 다른 네임스페이스(`other`의 `t`)에서는 frontend·productcatalogservice 모두 막히고, Traefik을 거친 `curl shop.localhost`는 200이 나와야 합니다. 정책 파일은 `~/sec/shop/shop-netpol.yaml` 하나에 `---`로 이어 씁니다.

<details><summary>힌트 1 — 정책 설계</summary>

실습 7처럼 **전부 막고 하나씩 연다**. 이 과제와 과제 3까지 필요한 정책은 4개면 충분합니다: 기본 차단 / 같은 네임스페이스끼리 / Traefik → frontend / cart → redis. "같은 네임스페이스의 모든 파드"는 `from: - podSelector: {}`입니다.
</details>
<details><summary>힌트 2 — Traefik을 어떻게 고르나</summary>

Traefik은 `traefik` 네임스페이스에 있습니다. 다른 네임스페이스는 `namespaceSelector`로 고릅니다(실습 7 확인 문제 1). 네임스페이스마다 자동으로 붙는 라벨 `kubernetes.io/metadata.name: traefik`을 씁니다. Traefik에서 오는 요청은 서비스 포트(80)가 아니라 **파드 포트(8080)** 로 들어옵니다.
</details>
<details><summary>힌트 3 — 정책을 넣었는데 홈이 여전히 된다 / 안 된다</summary>

정책은 **새 연결**부터 적용됩니다. Traefik이 이미 열어 둔 연결로 계속 될 수 있습니다. `kubectl -n traefik rollout restart deploy/traefik` 후 다시 확인하세요.
</details>

## 과제 3. redis-cart는 cartservice만, 쇼핑몰 기능 유지

**무엇을 하나요**: 장바구니 저장소 redis-cart(6379)에는 cartservice만 닿게 합니다. shop 안의 다른 파드에서 시험하면 막히고, productcatalogservice(3550)는 열려 있어야 합니다. 마지막으로 브라우저에서 상품을 장바구니에 담아 `Cart (1)`을 확인합니다(PORTS 탭에서 80 전달 → `http://shop.localhost:<포트>`, 또는 VM에서 `curl`).

<details><summary>힌트 1 — 같은 네임스페이스 규칙이 redis까지 열어 버린다</summary>

NetworkPolicy는 **합집합**입니다(실습 7). "막는 규칙"을 더할 수 없으므로, "같은 네임스페이스끼리" 규칙의 대상에서 redis-cart를 **빼야** 합니다. `podSelector`의 `matchExpressions`와 `NotIn`을 찾아보세요.
</details>
<details><summary>힌트 2 — shop 안에서 시험 파드가 거부된다</summary>

restricted 네임스페이스에서는 시험 파드도 실습 4의 설정 묶음이 있어야 뜹니다. `--overrides`로 설정을 넣은 busybox 한 줄입니다(끝의 호스트·포트만 바꿔 씁니다).
```bash
kubectl -n shop run t --rm -i --restart=Never --image=busybox:1.37 --overrides='{"spec":{"securityContext":{"runAsNonRoot":true,"runAsUser":1000,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"c","image":"busybox:1.37","command":["nc","-z","-w","3","redis-cart","6379"],"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}}]}}' && echo 열림 || echo 막힘
```
</details>

## 도전 (선택)

1. Kyverno로 "shop의 컨테이너는 **메모리 limit 필수**" 정책을 만들고, limit 없는 파드가 거부되는지 확인하세요. Online Boutique는 통과해야 합니다
2. shop을 **읽기만** 하는 서비스 계정 `shop-viewer`를 만드세요 (파드·Service·Deployment 조회와 로그 보기 가능, Secret 조회·삭제 불가). `can-i`로 확인
3. 차트 옵션 `--set networkPolicies.create=true`를 켜면 어떻게 되는지 확인하고, 내 정책과 비교하세요

## 미션 2 결과 정리 표

| # | 시험 | 명령 | 기대 | 결과 |
|---|---|---|---|---|
| 1 | restricted에서 Ready | `kubectl -n shop get deploy` | 11개 1/1 | |
| 2 | other → frontend:80 | | 막힘 | |
| 3 | other → productcatalogservice:3550 | | 막힘 | |
| 4 | shop.localhost 홈 | | 200 | |
| 5 | shop 안 다른 파드 → redis-cart:6379 | | 막힘 | |
| 6 | shop 안 → productcatalogservice:3550 | | 열림 | |
| 7 | 장바구니 담기 | 브라우저 캡처 | Cart (1) | |
| 8 | 대조군: other → kubernetes.default:443 | | 열림 | |

> 대조군(8)이 막히면 시험 방법이 잘못된 것입니다. "막힘"이 정책 때문인지, 시험 파드가 안 떠서인지 구분하세요.

## 미션 2 정리

미션이 끝나면 쇼핑몰을 지웁니다(노드 CPU를 많이 씀). todo와 other는 실습 10에서도 쓰니 남깁니다.

```bash
helm uninstall shop -n shop
kubectl delete namespace shop
kubectl delete validatingpolicy require-memory-limit --ignore-not-found   # 도전 1을 했으면
```
