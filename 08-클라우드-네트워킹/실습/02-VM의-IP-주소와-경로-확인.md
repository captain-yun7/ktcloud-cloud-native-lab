[← 실습 1](./01-DNS-TCP-TLS-HTTP.md) · [목차](../클라우드-네트워킹-실습.md) · [실습 3 →](./03-리눅스로-라우터와-NAT-만들기.md)

# 실습 2. VM의 IP 주소와 경로 확인

**무엇을 하나요**: 지금까지 쓴 서버 VM과 쿠버네티스 클러스터를 **하나도 바꾸지 않고** 주소만 읽습니다. VM 주소 → 기본 경로 → Docker 브리지 → kind 노드 3대 → 노드마다 파드 대역 → 파드 IP · Service IP → VM의 입구 포트(80 · 8080) 순서로 따라가며 **주소 표**를 채우고, 항목마다 온프레미스 용어(사내망 · 서브넷 · 기본 게이트웨이 · NAT · 로드밸런서)을 붙입니다. (교안 02장)

**필요한 것**: API Gateway 과목이 끝난 클러스터 그대로(kind 노드 3개, todo, shop, Traefik 입구 80, Envoy Gateway 입구 8080). 새로 만들거나 지우는 것은 없습니다.

> **바로 가기** · [1. VM의 주소와 기본 경로](#1단계-vm의-주소와-기본-경로) · [2. Docker 브리지와 kind 노드](#2단계-docker-브리지와-kind-노드) · [3. 노드마다 파드 대역 — 노드의 경로표](#3단계-노드마다-파드-대역--노드의-경로표) · [4. 파드 IP와 Service IP — VM에서는 안 닿음](#4단계-파드-ip와-service-ip--vm에서는-안-닿음) · [5. 들어오는 입구 — VM의 80과 8080](#5단계-들어오는-입구--vm의-80과-8080) · [6. 주소 표 채우기](#6단계-주소-표-채우기) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. VM의 주소와 기본 경로

```bash
ip -br addr show eth0
ip route
ip route get 1.1.1.1
```

**이 명령은**: 첫째 = VM 바깥 선(`eth0`)의 주소. 둘째 = VM의 **경로표**(어느 주소를 어디로 보낼지 적은 표). 셋째 = "`1.1.1.1`(인터넷의 한 주소)로 보내면 경로표의 어느 줄을 타나".

**이렇게 나오면 성공** (s23 예 — VM 주소와 `br-` 뒤 글자는 사람마다 다름)

```
eth0             UP             10.10.1.23/16 fe80::be24:11ff:feaf:d1f0/64
default via 10.10.0.1 dev eth0 proto static
10.10.0.0/16 dev eth0 proto kernel scope link src 10.10.1.23
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown
172.18.0.0/16 dev br-00f6611cf1e1 proto kernel scope link src 172.18.0.1
1.1.1.1 via 10.10.0.1 dev eth0 src 10.10.1.23 uid 1000
    cache
```

- 내 VM은 `10.10.0.0/16` 망(서버가 만든 실습 VM 전용 망)의 `10.10.1.N`입니다
- `default via 10.10.0.1` = 표에 없는 주소(인터넷 전부)는 **`10.10.0.1`로** 넘깁니다. VM에게 `10.10.0.1`은 **기본 게이트웨이**이고, 실습 서버 자신입니다. 서버가 VM의 사설 주소를 바깥 주소로 바꿔 내보냅니다 — 집·회사의 **공유기(NAT)**가 하는 일입니다
- `172.17…`·`172.18…` 두 줄은 VM 안의 Docker가 만든 망입니다(2단계)
- 셋째 명령의 `via 10.10.0.1` = 인터넷으로 가는 패킷은 `default` 줄을 탑니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `Device "eth0" does not exist.` | 내 PC 터미널에서 침, 또는 선 이름이 다름 | 프롬프트가 `lab@sNN`인지. 맞으면 `ip -br addr`로 `10.10.1.N`이 붙은 줄의 이름을 씀 |
| `10.0.0.0/16 via 10.0.255.2` 줄이 더 보임 | 실습 3을 미리 해 본 흔적 | 그대로 두고 진행(실습 3 1단계의 `vpc-up.sh`가 정리함) |

</details>

## 2단계. Docker 브리지와 kind 노드

```bash
ip -br addr show type bridge
kubectl get nodes -o wide
```

**이 명령은**: 첫째 = VM 안의 **브리지**(여러 컨테이너를 잇는 가상 스위치)와 그 주소. 둘째 = 쿠버네티스 노드 목록과 노드 주소(`INTERNAL-IP`).

**이렇게 나오면 성공** (둘째는 앞 열만)

```
br-00f6611cf1e1  UP             172.18.0.1/16 fc00:f853:ccd:e793::1/64 fe80::28dc:37ff:fe53:2428/64
docker0          DOWN           172.17.0.1/16 fe80::6c2a:9eff:fe35:427e/64
```
```
NAME                STATUS   ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   ...
lab-control-plane   Ready    control-plane   16h   v1.37.0   172.18.0.2    <none>        ...
lab-worker          Ready    <none>          16h   v1.37.0   172.18.0.3    <none>        ...
lab-worker2         Ready    <none>          16h   v1.37.0   172.18.0.4    <none>        ...
```

- kind 노드 3대는 VM 안의 **Docker 컨테이너**입니다. 셋 다 브리지 `br-…`(`172.18.0.0/16`)에 붙어 `172.18.0.2 · .3 · .4`를 받았습니다. VM 자신은 이 망에서 `172.18.0.1`
- VM 안에 망이 하나 더 있는 셈입니다: 서버 망 `10.10.0.0/16` 안의 VM, VM 안의 노드 망 `172.18.0.0/16`
- `EXTERNAL-IP`가 `<none>` = 노드에 바깥 주소가 없습니다. 회사 **내부망**(바깥에 열지 않는 망)에 놓인 서버와 같습니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `The connection to the server … was refused` | kind 노드 컨테이너가 멈춤(VM 재부팅 등) | `docker start lab-control-plane lab-worker lab-worker2` 후 1분 뒤 다시 |
| 노드가 1개(`lab-control-plane`만) | 작은 클러스터(lite)로 만듦 | 그대로 진행. 표의 노드 칸을 1개로 채움 |
| `172.18.` 대신 `172.19.` 등 | Docker 망을 다시 만든 적이 있음 | 정상. 내 값으로 표를 채움 |

</details>

## 3단계. 노드마다 파드 대역 — 노드의 경로표

```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,NODE-IP:.status.addresses[0].address,POD-CIDR:.spec.podCIDR
docker exec lab-worker ip route | grep -v "scope host"
```

**이 명령은**: 첫째 = 노드마다 이름 · 노드 주소 · **그 노드의 파드가 받을 주소 범위**(`POD-CIDR`). 둘째 = 노드 `lab-worker` 안에 들어가 그 노드의 경로표를 봄(파드 하나하나의 줄은 빼고).

**이렇게 나오면 성공** (노드와 파드 대역의 짝은 사람마다 다를 수 있음)

```
NAME                NODE-IP      POD-CIDR
lab-control-plane   172.18.0.2   10.244.0.0/24
lab-worker          172.18.0.3   10.244.2.0/24
lab-worker2         172.18.0.4   10.244.1.0/24
```
```
default via 172.18.0.1 dev eth0
10.244.0.0/24 via 172.18.0.2 dev eth0
10.244.1.0/24 via 172.18.0.4 dev eth0
172.18.0.0/16 dev eth0 proto kernel scope link src 172.18.0.3
```

- 파드 주소 전체 `10.244.0.0/16`을 노드마다 `/24` 칸으로 나눴습니다. 회사에서 사내망 대역을 **서브넷**으로 나누는 것과 같은 모양입니다
- `lab-worker`의 표: "`10.244.0.0/24`(control-plane의 파드)는 `172.18.0.2`로, `10.244.1.0/24`(worker2의 파드)는 `172.18.0.4`로". 이것이 **라우팅 표**입니다. 자기 칸(`10.244.2.0/24`)은 노드 안이라 줄이 따로 없습니다
- `default via 172.18.0.1` = 나머지는 VM으로. VM은 다시 `10.10.0.1`(서버)로 — 1단계

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `Error response from daemon: No such container: lab-worker` | 노드가 1개인 클러스터 | `docker exec lab-control-plane ip route \| grep -v "scope host"` |
| `POD-CIDR`가 `<none>` | 열 이름 뒤 경로 오타 | 첫 줄을 복사 버튼으로 다시 |

</details>

## 4단계. 파드 IP와 Service IP — VM에서는 안 닿음

```bash
kubectl -n todo get pods -o wide
kubectl -n todo get svc web
WEB=$(kubectl -n todo get pod -l app=web -o jsonpath='{.items[0].status.podIP}')
SVC=$(kubectl -n todo get svc web -o jsonpath='{.spec.clusterIP}')
echo $WEB $SVC
ip route get $WEB
curl -s -m 3 -o /dev/null -w "%{http_code}" $WEB; echo " [$?]"
curl -s -m 3 -o /dev/null -w "%{http_code}" $SVC; echo " [$?]"
docker exec lab-control-plane curl -s -m 3 -o /dev/null -w "%{http_code}\n" $WEB
docker exec lab-control-plane curl -s -m 3 -o /dev/null -w "%{http_code}\n" $SVC
```

**이 명령은**: 1·2줄 = todo 파드의 주소(`IP` 열)와 web Service의 주소(`CLUSTER-IP`). 3~5줄 = web 파드 주소와 Service 주소를 변수 `WEB`·`SVC`에 넣고 출력. 6줄 = VM이 그 파드 주소로 보낸다면 어느 줄을 타나. 7·8줄 = **VM에서** 파드·Service로 접속(3초 제한). 9·10줄 = **노드 안에서** 같은 주소로 접속.

**이렇게 나오면 성공** (주소는 사람마다 다름, 결과 모양이 같으면 됨)

```
NAME                      READY   STATUS    RESTARTS   AGE   IP            NODE          ...
api-6f57dd5f7-qzckt       2/2     Running   0          16h   10.244.1.11   lab-worker2   ...
api-v2-56fb997669-nrns6   2/2     Running   0          16h   10.244.1.18   lab-worker2   ...
db-86878656ff-5pl7w       2/2     Running   0          16h   10.244.1.10   lab-worker2   ...
load-75d7b4fccd-mr5ss     2/2     Running   0          16h   10.244.2.12   lab-worker    ...
web-5bdd6887b7-s6g67      2/2     Running   0          16h   10.244.2.11   lab-worker    ...
NAME   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
web    ClusterIP   10.96.103.189   <none>        80/TCP    16h
10.244.2.11 10.96.103.189
10.244.2.11 via 10.10.0.1 dev eth0 src 10.10.1.23 uid 1000
000 [28]
000 [28]
200
200
```

- 파드 주소는 3단계에서 본 그 노드의 칸 안에 있습니다(web `10.244.2.11` → `lab-worker`의 `10.244.2.0/24`)
- **VM에서는 둘 다 `000 [28]`**(3초 동안 답 없음). VM의 경로표에 `10.244…`·`10.96…` 줄이 없어서 `default`(바깥 서버)로 보내 버립니다(6줄 결과)
- **노드 안에서는 `200`**. 파드·Service 주소는 클러스터 안에서만 쓰는 주소입니다 — 회사 **내부망**(바깥에 열지 않는 망)과 같은 성질입니다. 그럼 밖에서는 어떻게 들어올까요 → 5단계

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `echo`가 빈 줄 또는 주소 하나만 | todo가 없거나 라벨이 다름 | `kubectl -n todo get pods --show-labels`에서 `app=web` 확인. todo가 없으면 질문 |
| VM에서 `200` | VM 경로표에 `10.244` 줄을 넣어 둔 적이 있음 | `ip route \| grep 10.244` — 정상 동작은 아니지만 실습에는 지장 없음. 질문 |
| 노드 안에서 `000` | 파드가 막 다시 만들어져 주소가 바뀜 | 3~5줄부터 다시 |

</details>

## 5단계. 들어오는 입구 — VM의 80과 8080

```bash
docker port lab-control-plane
kubectl -n traefik get pods -o wide
kubectl -n envoy-gateway-system get svc | grep NodePort
curl -s -o /dev/null -w "shop.localhost      %{http_code}\n" shop.localhost
curl -s -o /dev/null -w "todo.localhost:8080 %{http_code}\n" todo.localhost:8080
```

**이 명령은**: 1줄 = 노드 컨테이너 `lab-control-plane`의 포트 중 **VM의 포트로 이어진 것**. 2줄 = Traefik(쿠버네티스 과목의 입구) 파드가 어느 노드에 있나. 3줄 = Envoy Gateway(API Gateway 과목의 입구)의 Service. 4·5줄 = VM에서 두 입구로 접속.

**이렇게 나오면 성공** (`6443` 줄의 VM 쪽 번호는 사람마다 다름)

```
80/tcp -> 0.0.0.0:80
443/tcp -> 0.0.0.0:443
6443/tcp -> 127.0.0.1:42673
30080/tcp -> 0.0.0.0:8080
NAME                       READY   STATUS    RESTARTS   AGE   IP           NODE                ...
traefik-694bbc456d-lc88k   1/1     Running   0          16h   10.244.0.3   lab-control-plane   ...
envoy-gateway-front-19c8d80b   NodePort    10.96.103.215   <none>        80:30080/TCP    16h
shop.localhost      200
todo.localhost:8080 200
```

- 밖에서 클러스터로 들어오는 문은 이 두 줄뿐입니다
  - **VM 80** → 노드 `lab-control-plane`의 80 → 그 노드의 Traefik → Ingress 규칙(`shop.localhost`) → shop
  - **VM 8080** → 노드의 **30080**(NodePort) → Envoy Gateway → HTTPRoute(`todo.localhost`) → todo
- 파드 주소(4단계)는 숨겨 두고 **입구 하나**만 열어 이름·경로로 나눠 보내는 것 = **로드밸런서**(이름·경로로 나누는 L7 로드밸런서 — nginx·HAProxy 같은 것)와 같은 자리입니다
- `-> 0.0.0.0:8080` = VM의 8080으로 온 요청의 목적지를 노드 주소로 바꿔 넘깁니다(Docker가 넣은 규칙). 공유기의 **포트 포워딩**과 같은 일입니다. 실습 3의 6단계에서 같은 일을 직접 합니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `30080/tcp -> 0.0.0.0:8080` 줄이 없음 | 8080 매핑 없이 만든 클러스터 | API Gateway 실습 1의 입구가 없는 상태. 표의 8080 칸은 "없음"으로 채우고 질문 |
| `todo.localhost:8080`이 `301` | API Gateway 실습 8에서 http를 https로 넘겨 보내게 함 | 정상 — 입구는 살아 있음. `curl -s -o /dev/null -w "%{redirect_url}\n" todo.localhost:8080`에 `https://`로 시작하는 주소가 보이면 됨. 표의 8080 칸은 그대로 |
| `todo.localhost:8080`이 `404` | todo의 HTTPRoute가 없음 | API Gateway 실습 1을 지운 상태. 표에는 그대로 적음 |
| `shop.localhost`가 `404` | shop의 Ingress가 없음 | `kubectl get ingress -A`. 없으면 표에 그대로 적음 |
| 셋째 명령이 빈 결과 | Envoy Gateway가 없음 | `kubectl get ns envoy-gateway-system`. 없으면 표의 8080 칸 "없음" |

</details>

## 6단계. 주소 표 채우기

1~5단계의 내 값을 **내 값** 칸에 적습니다. **온프레미스에서는** 칸은 회사 전산실에서 부르는 이름입니다. 교안 02장의 그림을 보고 고릅니다 — 사내망 대역 · 서브넷 · 기본 게이트웨이 · 라우터(라우팅 표의 한 줄) · NAT(공유기) · 포트 포워딩 · 로드밸런서 · 내부망의 서버 중에서.

| 무엇 | 어디서 봤나 | 내 값 | 온프레미스에서는 |
|---|---|---|---|
| 서버가 만든 실습 망 | 1단계 `ip route`의 `dev eth0 … scope link` 줄 | | |
| 내 VM 주소 | 1단계 `ip -br addr show eth0` | | |
| VM의 기본 경로 | 1단계 `default via …` | | |
| `10.10.0.1`(서버)이 하는 일 | 1단계 설명 | 사설 주소를 바깥 주소로 바꿔 내보냄 | |
| kind 노드 망 | 2단계 `br-…` | | |
| 노드 3대 주소 | 2단계 `INTERNAL-IP` | | |
| 노드마다 파드 대역 | 3단계 `POD-CIDR` | | |
| 노드 경로표의 `via` 줄 하나 | 3단계 | | |
| todo web 파드 주소 | 4단계 `$WEB` | | |
| todo web Service 주소 | 4단계 `$SVC` | | |
| 입구 80 | 5단계 `80/tcp -> …` + Traefik | | |
| 입구 8080 | 5단계 `30080/tcp -> …` + NodePort | | |

**이렇게 나오면 성공**: 칸 12개가 모두 채워짐. **온프레미스에서는** 칸은 정답이 하나가 아닐 수 있습니다 — 왜 그 이름인지 한 줄로 말할 수 있으면 됩니다.

## 끝났는지 확인

- ☐ 내 VM 주소와 `default via 10.10.0.1`을 찾음
- ☐ 노드 3대의 주소(`172.18.0.x`)와 노드마다 파드 대역(`10.244.x.0/24`)을 찾음
- ☐ VM에서 파드·Service는 `000 [28]`, 노드 안에서는 `200`
- ☐ VM의 80 → Traefik, 8080 → 30080 → Envoy Gateway를 찾음
- ☐ 주소 표 12칸을 채움

## 정리

지울 것 없음. 읽기만 했습니다. 변수 `WEB`·`SVC`는 터미널을 닫으면 사라집니다.

### 클라우드에서는

- 이 실습의 사내망 대역을 AWS에서는 **VPC**, 공유기(NAT)를 **NAT 게이트웨이**, 기본 경로 줄을 **라우팅 표의 `0.0.0.0/0` 줄**, 입구의 로드밸런서를 **ALB(L7)·NLB(L4)**라고 부릅니다
- AWS의 쿠버네티스(EKS)에서는 파드가 VPC 서브넷의 진짜 주소를 받고(VPC CNI), Ingress를 만들면 AWS 로드밸런서가 생깁니다(Load Balancer Controller). 전체 대응은 교안 06장 대응표

## 확인 문제

1. 노드 `lab-worker2`의 경로표를 보세요. `lab-worker`의 파드(3단계 `POD-CIDR`)로 가는 줄은 어디로(`via`) 보내나요?
2. todo의 **db** 파드 주소를 찾고, 그 주소가 3단계 표의 어느 노드 칸에 속하는지 답하세요. VM에서 그 주소의 5432번에 닿을까요?
