[← 실습 1](./01-DNS-TCP-TLS-HTTP.md) · [목차](../클라우드-네트워킹-실습.md) · [실습 3 →](./03-리눅스로-라우터와-NAT-만들기.md)

# 실습 2. VM의 IP 주소와 경로 확인

**무엇을 하나요**: 지금까지 쓴 서버 VM과 쿠버네티스 클러스터를 **하나도 바꾸지 않고** 주소만 읽습니다. VM 주소와 기본 경로 → Docker 브리지와 kind 노드 3대 → 파드 IP · Service IP 순서로 따라가며 **주소 표**를 채우고, 항목마다 온프레미스 용어(사내망 · 서브넷 · 기본 게이트웨이 · NAT)를 붙입니다. (교안 02장)

**필요한 것**: API Gateway 과목이 끝난 클러스터 그대로(kind 노드 3개, todo). 새로 만들거나 지우는 것은 없습니다.

> **바로 가기** · [1. VM의 주소와 기본 경로](#1단계-vm의-주소와-기본-경로) · [2. Docker 브리지와 kind 노드](#2단계-docker-브리지와-kind-노드) · [3. 파드 IP와 Service IP](#3단계-파드-ip와-service-ip) · [4. 주소 표 채우기](#4단계-주소-표-채우기) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. VM의 주소와 기본 경로

```bash
ip -br addr show eth0
ip route
ip route get 1.1.1.1
```

**이 명령은**: 첫째 = VM의 바깥쪽 네트워크 인터페이스(`eth0`)의 주소. 둘째 = VM의 **경로표**(어느 주소를 어디로 보낼지 적은 표). 셋째 = "`1.1.1.1`(인터넷의 한 주소)로 보내면 경로표의 어느 줄을 타나".

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
| `Device "eth0" does not exist.` | 내 PC 터미널에서 침, 또는 인터페이스 이름이 다름 | 프롬프트가 `lab@sNN`인지. 맞으면 `ip -br addr`로 `10.10.1.N`이 붙은 줄의 이름을 씀 |
| `10.0.0.0/16 via 10.0.255.2` 줄이 더 보임 | 실습 3을 미리 해 본 흔적 | 그대로 두고 진행(실습 3의 `vpc-up.sh`가 정리함) |

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

## 3단계. 파드 IP와 Service IP

```bash
kubectl -n todo get pods -o wide
kubectl -n todo get svc web
```

**이 명령은**: 1줄 = todo 파드 목록과 파드마다 주소(`IP` 열) · 앉은 노드(`NODE` 열). 2줄 = web Service와 그 주소(`CLUSTER-IP`).

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
```

- 파드 주소는 모두 `10.244.x.x`입니다. 같은 노드의 파드는 앞 세 자리가 같습니다(`lab-worker` = `10.244.2.x`, `lab-worker2` = `10.244.1.x`) — 노드마다 파드 주소 묶음(`/24`)을 따로 나눠 받기 때문입니다
- Service 주소는 `10.96.x.x`입니다. 파드가 다시 만들어지면 파드 주소는 바뀌지만 Service 주소는 그대로입니다
- 파드·Service 주소는 **클러스터 안에서만 쓰는 주소**입니다. VM에서 이 주소로 바로 접속하면 닿지 않습니다 — 회사 **내부망**(바깥에 열지 않는 망)의 서버 주소와 같은 성질입니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `No resources found in todo namespace.` · `Error from server (NotFound): services "web" not found` | todo가 없음 | 질문 |
| `api-v2` 줄이 없음 · 파드 수가 다름 | 앞 과목에서 만든 것이 사람마다 다름 | 정상. web 파드 줄만 있으면 됨 |

</details>

## 4단계. 주소 표 채우기

1~3단계의 내 값을 **내 값** 칸에 적습니다. **온프레미스에서는** 칸은 회사 전산실에서 부르는 이름입니다. 교안 02장의 그림을 보고 고릅니다 — 사내망 대역 · 서브넷 · 기본 게이트웨이 · NAT(공유기) · 내부망의 서버 · 내부 로드밸런서 중에서.

| 무엇 | 어디서 봤나 | 내 값 | 온프레미스에서는 |
|---|---|---|---|
| 서버가 만든 실습 망 | 1단계 `ip route`의 `dev eth0 … scope link` 줄 | | |
| 내 VM 주소 | 1단계 `ip -br addr show eth0` | | |
| VM의 기본 경로 | 1단계 `default via …` | | |
| `10.10.0.1`(서버)이 하는 일 | 1단계 설명 | 사설 주소를 바깥 주소로 바꿔 내보냄 | |
| kind 노드 망 | 2단계 `br-…` | | |
| 노드 3대 주소 | 2단계 `INTERNAL-IP` | | |
| todo web 파드 주소 | 3단계 `IP` 열의 `web-…` 줄 | | |
| todo web Service 주소 | 3단계 `CLUSTER-IP` | | |

**이렇게 나오면 성공**: 칸 8개가 모두 채워짐. **온프레미스에서는** 칸은 정답이 하나가 아닐 수 있습니다 — 왜 그 이름인지 한 줄로 말할 수 있으면 됩니다.

## 끝났는지 확인

- ☐ 내 VM 주소와 `default via 10.10.0.1`을 찾음
- ☐ 노드 3대의 주소(`172.18.0.x`)를 찾음
- ☐ web 파드 주소(`10.244.x.x`)와 web Service 주소(`10.96.x.x`)를 찾음
- ☐ 주소 표 8칸을 채움

## 정리

지울 것 없음. 읽기만 했습니다.

### 클라우드에서는

- 이 실습의 사내망 대역을 AWS에서는 **VPC**, 공유기(NAT)를 **NAT 게이트웨이**, 기본 경로 줄을 **라우팅 표의 `0.0.0.0/0` 줄**이라고 부릅니다
- AWS의 쿠버네티스(EKS)에서는 파드가 VPC 서브넷의 진짜 주소를 받습니다(VPC CNI). 전체 대응은 교안 06장 대응표

## 확인 문제

1. todo의 **db** 파드 주소와, 그 파드가 앉은 노드 이름을 3단계 출력에서 찾으세요. 그 노드의 주소(2단계 `INTERNAL-IP`)는 무엇인가요?
2. 1단계 `ip route`에서 `172.18.0.0/16` 줄은 어느 인터페이스(`dev`)로 보내나요? 그 인터페이스는 2단계에서 본 무엇인가요?
