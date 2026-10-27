[← 실습 3](./03-리눅스로-라우터와-NAT-만들기.md) · [목차](../클라우드-네트워킹-실습.md) · [실습 5 →](./05-로드밸런서와-헬스-체크.md)

# 실습 4. 서버 방화벽 대 라우터 ACL

**무엇을 하나요**: 먼저 방화벽이 **없을 때** DB 자리(db 5432번)에 VM에서도 그냥 닿는 것을 봅니다. 그다음 같은 목적("db에는 웹 서브넷의 5432만")을 두 곳에 넣어 봅니다. **서버 방화벽**(서버 자체에 거는 방화벽, 상태를 기억해 내가 보낸 요청의 답은 자동 허용)과 **라우터 ACL**(망 경계 라우터에 거는 규칙, 상태가 없어 답도 따로 허용해야 함)입니다. 두 가지 모두 리눅스의 `iptables`로 넣는데, 회사에서 리눅스 서버와 리눅스 라우터에 거는 규칙과 같은 것입니다. 마지막에 보안 과목의 NetworkPolicy와 나란히 놓습니다. (교안 04장)

**필요한 것**: 실습 3이 끝난 상태(web 80번·db 5432번 서버, NAT). 꼬였으면 `sudo bash ~/ktcloud-cloud-native-lab/lab/network/vpc-up.sh --routed`로 다시 만들고 줄임말([시작하기 전에 2](./00-시작하기-전에.md#2-줄임말-web--db--rt--새-터미널마다-다시))을 다시 칩니다.

> **바로 가기** · [1. 규칙 없이 — db에 누구나 닿음](#1단계-규칙-없이--db에-누구나-닿음) · [2. 서버 방화벽 — db에 규칙 세 줄](#2단계-서버-방화벽--db에-규칙-세-줄) · [3. 라우터 ACL — 규칙 두 줄, 답이 막힘](#3단계-라우터-acl--규칙-두-줄-답이-막힘) · [4. 라우터 ACL — 답도 허용](#4단계-라우터-acl--답도-허용) · [5. NetworkPolicy와 나란히](#5단계-networkpolicy와-나란히) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 규칙 없이 — db에 누구나 닿음

```bash
db iptables -S
web curl -s -m 3 10.0.2.10:5432
curl -s -m 3 10.0.2.10:5432; echo "[$?]"
db curl -s -m 4 -o /dev/null -w "%{http_code}\n" http://1.1.1.1
```

**이 명령은**: 1줄 = db 안의 방화벽 규칙을 명령 모양으로 모두 출력. 2줄 = web → db 5432. 3줄 = **VM**(`10.0.255.1`) → db 5432. 4줄 = db → 인터넷.

**이렇게 나오면 성공**

```
-P INPUT ACCEPT
-P FORWARD ACCEPT
-P OUTPUT ACCEPT
db 10.0.2.10
db 10.0.2.10
[0]
301
```

- 규칙이 하나도 없고 기본값 `ACCEPT`(모두 허용) 세 줄뿐입니다
- web도, web이 아닌 VM도 DB 자리에 그냥 닿습니다. db에 와야 하는 것은 web(앱)뿐입니다 → **웹 서브넷에서 오는 5432번만** 받게 막습니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `db: command not found` | 줄임말 없음(새 터미널) | [시작하기 전에 2](./00-시작하기-전에.md#2-줄임말-web--db--rt--새-터미널마다-다시)의 `alias` 줄 |
| `[7]` / `Connection refused` | db 서버가 안 켜짐 | 실습 3 6단계의 `db sh -c …` 줄 다시 |
| `Cannot open network namespace "db"` | 사내망이 없음 | `sudo bash vpc-up.sh --routed` |

</details>

## 2단계. 서버 방화벽 — db에 규칙 세 줄

```bash
db iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
db iptables -A INPUT -p tcp --dport 5432 -s 10.0.1.0/24 -j ACCEPT
db iptables -P INPUT DROP
web curl -s -m 3 10.0.2.10:5432
curl -s -m 3 10.0.2.10:5432; echo "[$?]"
db curl -s -m 4 -o /dev/null -w "%{http_code}\n" http://1.1.1.1
```

**이 명령은**: db로 **들어오는** 패킷(INPUT)에 ① 내가 시작한 연결의 답은 허용 ② 웹 서브넷(`10.0.1.0/24`)에서 5432번은 허용 ③ 나머지는 모두 버림(DROP). 그리고 1단계의 세 접속을 다시.

**이렇게 나오면 성공**

```
db 10.0.2.10
[28]
301
```

- web → db: 허용(②)
- VM → db: 버려짐. `[28]` = 3초 동안 답이 없음(시간 초과)
- db → 인터넷: `301`. 들어오는 것을 모두 막았는데도 **내가 보낸 요청의 답**은 들어옵니다(① = 상태 기억). 이것이 서버 방화벽입니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| web → db도 시간 초과 | ②번 줄의 대역·포트 오타 | `db iptables -S`로 확인 |
| db → 인터넷 `000` | ①번 줄 빠짐 | `db iptables -F; db iptables -P INPUT ACCEPT` 후 세 줄 다시 |
| `iptables: Bad rule …` / `unknown option` | 줄을 잘라 붙임 | 복사 버튼으로 한 줄씩 |

</details>

## 3단계. 라우터 ACL — 규칙 두 줄, 답이 막힘

서버 방화벽을 풀고, 같은 목적을 **사내 라우터**(망 경계)에 넣습니다.

```bash
db iptables -F; db iptables -P INPUT ACCEPT
rt iptables -A FORWARD -s 10.0.1.0/24 -d 10.0.2.0/24 -p tcp --dport 5432 -j ACCEPT
rt iptables -A FORWARD -d 10.0.2.0/24 -j DROP
web curl -s -m 3 10.0.2.10:5432
curl -s -m 3 10.0.2.10:5432; echo "[$?]"
db curl -s -m 4 -o /dev/null -w "%{http_code}\n" http://1.1.1.1
```

**이 명령은**: 1줄 = db의 서버 방화벽 규칙을 모두 지우고 기본을 허용으로. 2·3줄 = 라우터가 **넘겨 주는** 패킷(FORWARD)에 ① 웹 서브넷 → DB 서브넷 5432번은 허용 ② DB 서브넷으로 들어가는 나머지는 버림. 4~6줄 = 같은 세 접속.

**이렇게 나오면 성공**

```
db 10.0.2.10
[28]
000
```

- web → db: 됨. VM → db: 막힘. 여기까지는 서버 방화벽과 같습니다
- **db → 인터넷이 `000`**: 요청은 나갔지만 **돌아오는 답**(1.1.1.1 → db)이 DB 서브넷으로 들어가다 ②에 걸려 버려졌습니다. 라우터 ACL은 "내가 보낸 요청의 답"을 기억하지 않습니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| web → db도 시간 초과 | 2줄 대역 오타, 또는 2·3줄 순서가 바뀜 | `rt iptables -L FORWARD -n --line-numbers` — 허용이 1번, DROP이 2번 |
| db → 인터넷 `301` | 3줄(DROP)을 빠뜨림 | 3줄 다시 |

</details>

## 4단계. 라우터 ACL — 답도 허용

```bash
rt iptables -I FORWARD 2 -d 10.0.2.0/24 -p tcp --sport 80 -j ACCEPT
rt iptables -L FORWARD -n --line-numbers
db curl -s -m 4 -o /dev/null -w "%{http_code}\n" http://1.1.1.1
db curl -s -m 6 -o /dev/null -w "%{http_code}\n" https://example.com
```

**이 명령은**: 1줄 = 2번째 자리에 끼워 넣기(`-I FORWARD 2`, DROP보다 앞) — "출발 포트 80(웹 서버)에서 DB 서브넷으로 오는 것 = 웹 서버의 답은 허용". 2줄 = 라우터 규칙을 번호와 함께. 3·4줄 = db → 인터넷을 http(80), https(443)로.

**이렇게 나오면 성공**

```
Chain FORWARD (policy ACCEPT)
num  target     prot opt source               destination
1    ACCEPT     6    --  10.0.1.0/24          10.0.2.0/24          tcp dpt:5432
2    ACCEPT     6    --  0.0.0.0/0            10.0.2.0/24          tcp spt:80
3    DROP       0    --  0.0.0.0/0            10.0.2.0/24
301
000
```

- http(80)의 답은 2번 줄로 들어와 `301`
- https(443)는 여전히 `000` — 443에서 오는 답은 허용하지 않았기 때문입니다. 라우터 ACL은 **답이 올 포트까지** 따로 적어야 합니다
- 번호 낮은 규칙부터 봅니다. DROP(3번)보다 앞에 있어야 효과가 있습니다

| | 서버 방화벽 (2단계) | 라우터 ACL (3·4단계) |
|---|---|---|
| 붙는 곳 | 서버(db) | 망 경계(사내 라우터 rt) |
| 답 | 기억함 — 자동 허용(`301`) | 기억 안 함 — 규칙 없으면 `000` |
| 규칙 | 허용 줄 + 나머지 버림(기본값 DROP) | 허용·거부 줄, 위에서부터 번호 순서 |
| 맡는 일 | 서버마다 자기 문 지키기 | 칸 전체를 경계에서 한 번에 |

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 그래도 `000`, 목록에서 `spt:80`이 DROP 아래 | `-A`로 넣어 DROP 뒤에 붙음 | `rt iptables -F` 후 3단계 2·3줄 → 4단계 1줄 |
| web → db도 안 됨 | db의 서버 방화벽이 남음(3단계 1줄 빠뜨림) | `db iptables -F; db iptables -P INPUT ACCEPT` |

</details>

## 5단계. NetworkPolicy와 나란히

보안 과목 실습 7에서 todo의 db에 넣은 NetworkPolicy(`db-from-api`)를 떠올립니다.

```yaml
# 클라우드 보안 실습 7 3단계의 일부 (다시 넣지 않습니다 — 보기만)
kind: NetworkPolicy
metadata:
  name: db-from-api
  namespace: todo
spec:
  podSelector:
    matchLabels:
      app: db
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api
    ports:
    - port: 5432
```

2단계의 db 규칙과 한 줄씩 맞춰 봅니다.

| 무엇 | 서버 방화벽 (2단계, db 안) | 라우터 ACL (3·4단계, rt) | NetworkPolicy (보안 과목) |
|---|---|---|---|
| 붙는 곳 | 서버 하나 | 망 경계(라우터) | 파드(`podSelector: app: db`) |
| 누가 들어와도 되나 | `-s 10.0.1.0/24` (주소로) | `-s 10.0.1.0/24 -d 10.0.2.0/24` | `from: podSelector: app: api` (라벨로) |
| 포트 | `--dport 5432` | `--dport 5432` | `port: 5432` |
| 나머지 | `-P INPUT DROP` | `-j DROP` 줄 | 정책이 고른 파드는 목록에 없으면 버림 |
| 답 | 자동 허용 | 따로 규칙 | 자동 허용 |
| 막혔을 때 | `[28]` 시간 초과 | `[28]` 시간 초과 | 시간 초과(보안 과목 `nc` "막힘", `wget` `download timed out`) |

- NetworkPolicy는 **서버 방화벽과 같은 쪽**입니다(파드에 붙고, 답을 기억함). 다른 점은 주소 대신 **라벨**로 고르는 것 — 파드 주소는 다시 만들 때마다 바뀌기 때문입니다(실습 2 4단계)

**이렇게 나오면 성공**: 표의 세 열을 보고 "NetworkPolicy는 서버 방화벽과 같은 쪽, 라벨로 고른다"를 말할 수 있으면 끝.

## 끝났는지 확인

- ☐ 규칙 없이 VM → db가 `db 10.0.2.10`
- ☐ 서버 방화벽: web → db 됨, VM → db `[28]`, db → 인터넷 `301`
- ☐ 라우터 ACL: 답 규칙 전 db → 인터넷 `000`, 후 http `301`·https `000`
- ☐ 비교 표를 보고 NetworkPolicy가 어느 쪽인지 말할 수 있음

## 정리

```bash
rt iptables -F
```

라우터 ACL 규칙을 지웁니다. 실습 5는 1단계에서 사내망을 다시 만드니, 여기서 모두 지워도 됩니다(부록 A3 캐시 서브넷도 사내망을 다시 만들고 시작).

```bash
sudo bash ~/ktcloud-cloud-native-lab/lab/network/vpc-down.sh
```

**이렇게 나오면 성공**: `정리 완료`. `ip netns list`가 빈 결과. 쿠버네티스 클러스터는 그대로입니다.

### 클라우드에서는

- 이 실습의 서버 방화벽을 AWS에서는 보안그룹, 라우터 ACL을 NACL(네트워크 ACL)이라고 부릅니다. 상태를 기억하느냐의 차이도 그대로입니다
- 보안그룹은 출발지를 주소 대신 다른 보안그룹 이름으로 적을 수 있어, 라벨로 고르는 NetworkPolicy와 닮았습니다. 나머지 짝은 교안 06장 대응표에 모았습니다

## 확인 문제

1. 2단계에서 db → 인터넷이 `301`인데, 3단계에서는 `000`인 이유를 한 문장으로 쓰세요.
2. 서버 방화벽(2단계)에서 ①번 줄(ESTABLISHED,RELATED)을 빼고 넣으면 db → 인터넷과 web → db는 어떻게 될까요?
