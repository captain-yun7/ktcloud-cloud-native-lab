[← 부록 A3](./A3-캐시-서브넷-붙이기.md) · [목차](../클라우드-네트워킹-실습.md) · [부록 B2 →](./B2-네트워크-최적화-거리와-비용.md)

# 부록 B1. 두 VPC 피어링

> 부록 — 본편(D-30) 밖, 클라우드(AWS) 이름으로 더 보고 싶을 때 보는 문서입니다.

**무엇을 하나요**: 실습 3의 VPC(A, `10.0.0.0/16`) 옆에 다른 VPC(B, `10.1.0.0/16`)를 하나 더 만들고 **피어링**으로 잇습니다. 선(피어링 연결)만 놓아서는 안 되고 **양쪽 라우팅 표에 한 줄씩** 넣어야 통하는 것, 대역이 **겹치면** 이을 수 없는 이유, 그리고 VPC C를 B에 이었을 때 **A에서 C로는 B를 거쳐 가지 못하는 것**(피어링은 전이되지 않음)을 직접 봅니다. (교안 05장)

**필요한 것**: 실습 4까지(줄임말 · `vpc-up.sh`). VPC는 1단계에서 다시 만듭니다. 쿠버네티스 클러스터는 건드리지 않습니다.

> **바로 가기** · [1. VPC A 다시 만들고 새 대역 고르기](#1단계-vpc-a-다시-만들고-새-대역-고르기) · [2. VPC B 만들기 — 잇기 전](#2단계-vpc-b-만들기--잇기-전) · [3. 피어링 연결 놓기](#3단계-피어링-연결-놓기) · [4. 양쪽 라우팅 표에 한 줄씩](#4단계-양쪽-라우팅-표에-한-줄씩) · [5. 대역이 겹치면](#5단계-대역이-겹치면) · [6. VPC C — 피어링은 전이되지 않음](#6단계-vpc-c--피어링은-전이되지-않음) · [7. A와 C를 직접 잇기](#7단계-a와-c를-직접-잇기) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. VPC A 다시 만들고 새 대역 고르기

```bash
cd ~/ktcloud-cloud-native-lab && git pull && cd lab/network
sudo bash vpc-up.sh --routed
alias web="sudo ip netns exec web" db="sudo ip netns exec db" rt="sudo ip netns exec rt" vpcb="sudo ip netns exec vpc-b" vpcc="sudo ip netns exec vpc-c"
python3 - <<'PY'
import ipaddress as ip
a = ip.ip_network("10.0.0.0/16")
for name, c in [("후보 1", "10.0.0.0/16"), ("후보 2", "10.0.2.0/24"), ("후보 3", "10.1.0.0/16"), ("후보 4", "10.2.0.0/16")]:
    print(name, c, a.overlaps(ip.ip_network(c)))
PY
```

**이 명령은**: 1·2줄 = 실습 3이 끝난 상태로 VPC A를 다시 만듦. 3줄 = 줄임말(`vpcb`·`vpcc` = 이번에 만들 VPC B·C 안에서). 4줄부터 = VPC A(`10.0.0.0/16`)와 새 VPC 후보 넷이 겹치는지 계산(실습 3 1단계와 같은 방법).

**이렇게 나오면 성공**

```
라우팅·NAT·서버까지 준비 완료:
db (id: 4)
web (id: 3)
rt (id: 0)
후보 1 10.0.0.0/16 True
후보 2 10.0.2.0/24 True
후보 3 10.1.0.0/16 False
후보 4 10.2.0.0/16 False
```

- 후보 1·2는 A와 겹칩니다(후보 2는 A의 db 칸과 같음). 후보 3·4를 **VPC B · C**의 대역으로 씁니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `bash: vpc-peer.sh: No such file` (다음 단계) | `git pull` 전 | 1줄 다시 |
| `>` 표시만 나오고 멈춤 | 마지막 줄 `PY`까지 안 붙음 | `PY`를 치고 Enter |

</details>

## 2단계. VPC B 만들기 — 잇기 전

```bash
sudo bash vpc-peer.sh new vpc-b 10.1.1.10
vpcb ip -br addr
web curl -s -m 3 10.1.1.10; echo "[$?]"
web tracepath -n -m 4 10.1.1.10
```

**이 명령은**: 1줄 = VPC B(네임스페이스 `vpc-b`)를 만들고 서버 `10.1.1.10`(80번)을 켬. 2줄 = B의 주소. 3줄 = A의 web에서 B의 서버로 접속. 4줄 = 가는 길을 한 칸씩(최대 4칸).

**이렇게 나오면 성공** (접속은 실패하는 것이 맞음)

```
VPC vpc-b 준비 완료: 서버 10.1.1.10:80
lo               UNKNOWN        127.0.0.1/8 10.1.1.10/32 ::1/128
[28]
 1?: [LOCALHOST]                      pmtu 1500
 1:  10.0.1.1                                              0.051ms
 1:  10.0.1.1                                              0.006ms
 2:  10.0.255.1                                            0.048ms
 3:  10.10.0.1                                             0.262ms
 4:  no reply
```

- 아직 A와 B 사이에 아무것도 없습니다. A의 라우터는 `10.1.1.10`을 모르니 **기본 경로**(인터넷 쪽)로 보냅니다: web → 라우터 `10.0.1.1` → VM `10.0.255.1` → 서버 `10.10.0.1` → 그 뒤 사라짐 → `[28]`
- 사설 주소 `10.1.1.10`은 인터넷에 없습니다. VPC끼리는 **직접 잇는 길**이 필요합니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `Cannot create namespace file "/run/netns/vpc-b": File exists` | 이미 만듦 | 그대로 진행. 꼬였으면 1단계부터(`vpc-up.sh`가 지우고 새로) |
| `vpcb: command not found` | 줄임말 없음(새 터미널) | 1단계 3줄 다시 |

</details>

## 3단계. 피어링 연결 놓기

```bash
sudo bash vpc-peer.sh link rt vpc-b 12
rt ip -br addr show pcx-ab
vpcb ip route
web curl -s -m 3 10.1.1.10; echo "[$?]"
```

**이 명령은**: 1줄 = A의 라우터(`rt`)와 VPC B 사이에 피어링 선을 놓음(`12` = A–B, 선 주소 `192.168.12.1`·`.2`). 2·3줄 = A쪽 선 끝, B의 라우팅 표. 4줄 = 다시 접속.

**이렇게 나오면 성공** (접속은 아직 실패하는 것이 맞음)

```
피어링 연결: rt(pcx-ab 192.168.12.1) ↔ vpc-b(pcx-ba 192.168.12.2) — 라우팅 표의 줄은 아직 없음
pcx-ab@if468     UP             192.168.12.1/30 fe80::cb9:ceff:fe42:9e91/64
192.168.12.0/30 dev pcx-ba proto kernel scope link src 192.168.12.2
[28]
```

- 선은 놓였지만(`UP`) 여전히 `[28]`. A의 라우팅 표에 "`10.1.0.0/16`은 이 선으로"가 **없어서** 아직도 인터넷 쪽으로 보냅니다
- AWS에서도 같습니다: 피어링 연결을 만들고 수락해도 **라우팅 표에 줄을 넣기 전에는** 아무것도 안 통합니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `RTNETLINK answers: File exists` | 같은 선을 두 번 놓음 | 그대로 진행 |
| `Cannot find device "pcx-ab"` (2줄) | 1줄이 실패 | 1줄 출력의 오류를 보고, 2단계(`new vpc-b`)를 했는지 |

</details>

## 4단계. 양쪽 라우팅 표에 한 줄씩

**가. A쪽 표에만**

```bash
sudo ip -n rt route add 10.1.0.0/16 via 192.168.12.2
web curl -s -m 3 10.1.1.10; echo "[$?]"
vpcb ip route get 10.0.1.10
```

**이렇게 나오면 성공** (아직 실패하는 것이 맞음)

```
[28]
RTNETLINK answers: Network is unreachable
```

- 요청은 이제 B까지 갑니다. 그런데 B가 답을 돌려보낼 때 web(`10.0.1.10`)으로 가는 길을 모릅니다(`Network is unreachable`) → 답이 안 와서 `[28]`

**나. B쪽 표에도**

```bash
sudo ip -n vpc-b route add 10.0.0.0/16 via 192.168.12.1
web curl -s -m 3 10.1.1.10; echo "[$?]"
rt ip route
vpcb ip route
web ping -c1 -W1 10.1.1.10 | grep ttl
```

**이렇게 나오면 성공**

```
vpc-b 10.1.1.10
[0]
default via 10.0.255.1 dev rt-igw
10.0.1.0/24 dev rt-web proto kernel scope link src 10.0.1.1
10.0.2.0/24 dev rt-db proto kernel scope link src 10.0.2.1
10.0.255.0/30 dev rt-igw proto kernel scope link src 10.0.255.2
10.1.0.0/16 via 192.168.12.2 dev pcx-ab
192.168.12.0/30 dev pcx-ab proto kernel scope link src 192.168.12.1
10.0.0.0/16 via 192.168.12.1 dev pcx-ba
192.168.12.0/30 dev pcx-ba proto kernel scope link src 192.168.12.2
64 bytes from 10.1.1.10: icmp_seq=1 ttl=63 time=0.036 ms
```

| | A의 라우팅 표 | B의 라우팅 표 |
|---|---|---|
| 넣은 줄 | `10.1.0.0/16 via 192.168.12.2` | `10.0.0.0/16 via 192.168.12.1` |
| AWS 콘솔이라면 | 대상 `10.1.0.0/16` → `pcx-…` | 대상 `10.0.0.0/16` → `pcx-…` |

- `ttl=63` = 라우터를 한 번(A의 라우터) 지남 — 실습 3 3단계와 같은 모양. 인터넷을 거치지 않고 바로 갑니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `Error: Nexthop has invalid gateway.` | 3단계 선이 없음, 또는 주소 오타 | `rt ip -br addr show pcx-ab`, 주소 `192.168.12.2` 확인 |
| 나.에서도 `[28]` | B쪽 줄을 A에 넣음(`-n rt`) | `vpcb ip route`에 `10.0.0.0/16 via 192.168.12.1`이 있는지 |
| `RTNETLINK answers: File exists` | 같은 줄을 두 번 | 그대로 진행 |

</details>

## 5단계. 대역이 겹치면

VPC B에도 A의 db와 **같은 주소** `10.0.2.10`이 있다고 해 봅니다(겹치는 대역의 VPC를 이은 것과 같음).

```bash
sudo ip -n vpc-b addr add 10.0.2.10/32 dev lo
web curl -s -m 3 10.0.2.10:5432; echo "[$?]"
rt ip route get 10.0.2.10
sudo ip -n rt route add 10.0.2.10/32 via 192.168.12.2
web curl -s -m 3 10.0.2.10; echo "[$?]"
web curl -s -m 3 10.0.2.10:5432; echo "[$?]"
```

**이 명령은**: 1줄 = B에 `10.0.2.10`을 하나 더 붙임. 2·3줄 = web이 `10.0.2.10`을 부르면 누가 답하나, 라우터는 어느 선으로 보내나. 4줄 = 억지로 "`10.0.2.10`은 B 쪽으로" 줄을 넣음. 5·6줄 = B의 웹 서버(80), A의 db(5432)를 다시.

**이렇게 나오면 성공**

```
db 10.0.2.10
[0]
10.0.2.10 dev rt-db src 10.0.2.1 uid 0
    cache
vpc-b 10.1.1.10
[0]
[7]
```

| | 라우터가 고르는 줄 | B의 `10.0.2.10` | A의 db `10.0.2.10` |
|---|---|---|---|
| 그대로 | `10.0.2.0/24 dev rt-db`(A의 db 칸) | 못 감 | 됨 |
| B 쪽 줄을 넣으면 | `10.0.2.10/32 via 192.168.12.2`(더 자세한 줄이 이김) | 됨 | **못 감** (`[7]`) |

- 같은 주소가 두 곳에 있으면 라우터는 **한 곳만** 고를 수 있습니다. 하나를 얻으면 하나를 잃습니다
- 그래서 AWS는 대역이 겹치는 VPC끼리는 **피어링 자체를 만들어 주지 않습니다**. VPC 대역은 처음부터 겹치지 않게 정합니다(부록 B3 과제 1)

되돌립니다.

```bash
sudo ip -n rt route del 10.0.2.10/32; sudo ip -n vpc-b addr del 10.0.2.10/32 dev lo
web curl -s -m 3 10.0.2.10:5432; echo "[$?]"
```

**이렇게 나오면 성공**: `db 10.0.2.10` `[0]`

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 5줄이 `[7]` | 4줄을 안 넣음 | 4줄 다시 |
| 되돌린 뒤에도 `[7]` | 지우는 줄을 반만 침 | `rt ip route \| grep 10.0.2.10` 줄이 있으면 `sudo ip -n rt route del 10.0.2.10/32` |

</details>

## 6단계. VPC C — 피어링은 전이되지 않음

VPC C(`10.2.0.0/16`)를 만들어 **B와만** 잇습니다. A – B – C 한 줄로 이어진 모양입니다.

```bash
sudo bash vpc-peer.sh new vpc-c 10.2.1.10
sudo bash vpc-peer.sh link vpc-b vpc-c 23
sudo ip -n vpc-b route add 10.2.0.0/16 via 192.168.23.2
sudo ip -n vpc-c route add 10.1.0.0/16 via 192.168.23.1
vpcb curl -s -m 3 10.2.1.10; echo "[$?]"
```

**이렇게 나오면 성공**: B → C는 됩니다.

```
VPC vpc-c 준비 완료: 서버 10.2.1.10:80
피어링 연결: vpc-b(pcx-bc 192.168.23.1) ↔ vpc-c(pcx-cb 192.168.23.2) — 라우팅 표의 줄은 아직 없음
vpc-c 10.2.1.10
[0]
```

이제 A에서 C로 — "C로 가려면 B 쪽으로"를 A의 표에, "A로 가려면 B 쪽으로"를 C의 표에 넣어 봅니다.

```bash
sudo ip -n rt    route add 10.2.0.0/16 via 192.168.12.2
sudo ip -n vpc-c route add 10.0.0.0/16 via 192.168.23.1
web curl -s -m 3 10.2.1.10; echo "[$?]"
web tracepath -n -m 3 10.2.1.10
```

**이렇게 나오면 성공** (실패하는 것이 맞음)

```
[28]
 1?: [LOCALHOST]                      pmtu 1500
 1:  10.0.1.1                                              0.042ms
 1:  10.0.1.1                                              0.006ms
 2:  no reply
 3:  no reply
```

- 길은 다 적었는데 `[28]`. tracepath 2번째 칸(B)에서 끊깁니다 — **B는 남의 VPC 패킷을 넘겨 주지 않습니다**
- A–B, B–C를 이어도 A → C는 안 됩니다. 이것이 "피어링은 **전이되지 않는다**"입니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| B → C가 `[28]` | B나 C 표의 줄 하나를 빠뜨림 | `vpcb ip route`에 `10.2.0.0/16 via 192.168.23.2`, `vpcc ip route`에 `10.1.0.0/16 via 192.168.23.1` |
| A → C가 `vpc-c 10.2.1.10`(성공) | B에서 넘겨 주기를 켬 | `vpcb sysctl net.ipv4.ip_forward`가 `0`인지. 스크립트로 만든 VPC는 `0` |

</details>

## 7단계. A와 C를 직접 잇기

```bash
sudo ip -n rt route del 10.2.0.0/16; sudo ip -n vpc-c route del 10.0.0.0/16
sudo bash vpc-peer.sh link rt vpc-c 13
sudo ip -n rt    route add 10.2.0.0/16 via 192.168.13.2
sudo ip -n vpc-c route add 10.0.0.0/16 via 192.168.13.1
web curl -s -m 3 10.2.1.10; echo "[$?]"
rt ip route | grep pcx
```

**이 명령은**: 1줄 = 6단계에서 "B 쪽으로" 넣은 두 줄을 지움. 2줄 = A–C 피어링 선(`13`). 3·4줄 = 양쪽 표에 상대 대역. 5줄 = A → C. 6줄 = A의 표에서 피어링 줄만.

**이렇게 나오면 성공**

```
피어링 연결: rt(pcx-ac 192.168.13.1) ↔ vpc-c(pcx-ca 192.168.13.2) — 라우팅 표의 줄은 아직 없음
vpc-c 10.2.1.10
[0]
10.1.0.0/16 via 192.168.12.2 dev pcx-ab
10.2.0.0/16 via 192.168.13.2 dev pcx-ac
192.168.12.0/30 dev pcx-ab proto kernel scope link src 192.168.12.1
192.168.13.0/30 dev pcx-ac proto kernel scope link src 192.168.13.1
```

```
    VPC A ──pcx-ab── VPC B
      │                │
    pcx-ac          pcx-bc
      │                │
      └──── VPC C ─────┘
```

- VPC 3개를 모두 잇는 데 피어링 3개. VPC가 10개면 10 × 9 ÷ 2 = **45개** → 그래서 VPC가 많으면 **Transit Gateway**(가운데 허브 하나에 모두 연결)

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `RTNETLINK answers: No such process` (1줄) | 6단계 줄을 안 넣었거나 이미 지움 | 그대로 진행 |
| `RTNETLINK answers: File exists` (3줄) | 1줄을 건너뜀(6단계 줄이 남음) | 1줄 먼저 |

</details>

## 끝났는지 확인

- ☐ 겹침 계산에서 B·C 대역이 `False`
- ☐ 피어링 선만으로는 `[28]`, A쪽 줄만으로도 `[28]`(B에서 `Network is unreachable`), 양쪽 줄을 넣으니 `vpc-b 10.1.1.10`
- ☐ 겹치는 주소는 한 곳만 갈 수 있음(`/32` 줄을 넣으면 A의 db `[7]`)
- ☐ A–B, B–C만 이었을 때 A → C `[28]`, A–C를 직접 이으니 `vpc-c 10.2.1.10`

## 정리

```bash
sudo bash ~/ktcloud-cloud-native-lab/lab/network/vpc-down.sh
```

**이렇게 나오면 성공**: `정리 완료`. VPC A·B·C와 피어링 선이 모두 지워집니다. 실습 5는 VPC를 다시 만들고 시작합니다.

## 확인 문제

1. 7단계 뒤에 VPC B에서 A의 db(`10.0.2.10`의 5432)를 부르면 닿을까요? 왜 그런가요?
2. VPC가 5개이고 모두 서로 통해야 합니다. 피어링으로 하면 몇 개가 필요하고, Transit Gateway로 하면 연결이 몇 개인가요?
