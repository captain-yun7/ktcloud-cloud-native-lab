[← 시작하기 전에](./00-시작하기-전에.md) · [목차](../클라우드-네트워킹-실습.md) · [실습 2 →](./02-VM의-IP-주소와-경로-확인.md)

# 실습 1. DNS · TCP · TLS · HTTP

**무엇을 하나요**: 브라우저에 `https://example.com`을 치면 네 가지 일이 차례로 일어납니다. **이름을 주소로 바꾸고(DNS)** → **그 주소와 연결을 맺고(TCP)** → **암호를 맞추고 상대가 진짜인지 확인하고(TLS)** → **요청을 보내 응답을 받습니다(HTTP)**. 이 네 가지를 VM에서 명령 하나씩으로 떼어 봅니다. 마지막에 쿠버네티스 클러스터 안의 이름 찾기(CoreDNS)를 봅니다. (교안 01장)

**필요한 것**: 서버 VM과 지금 클러스터(todo의 `load` 파드 — 모니터링 과목에서 만듦). 새로 만들거나 지우는 것은 없습니다.

> **바로 가기** · [1. 이름을 주소로 — dig](#1단계-이름을-주소로--dig) · [2. 레코드 종류와 TTL](#2단계-레코드-종류와-ttl) · [3. DNS 조회 경로 — dig +trace](#3단계-dns-조회-경로--dig-trace) · [4. 연결 맺기 — TCP 3-way handshake](#4단계-연결-맺기--tcp-3-way-handshake) · [5. 암호화와 인증서 — TLS](#5단계-암호화와-인증서--tls) · [6. 응답과 걸린 시간 — HTTP](#6단계-응답과-걸린-시간--http) · [7. 클러스터 안의 이름 — CoreDNS](#7단계-클러스터-안의-이름--coredns) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 이름을 주소로 — dig

```bash
grep nameserver /etc/resolv.conf
resolvectl dns eth0
dig example.com
```

**이 명령은**: 1줄 = VM이 이름을 물어보는 곳. 2줄 = 그곳(VM 안의 중계)이 실제로 물어보는 DNS 서버. 3줄 = `example.com`의 주소를 물어봄(`dig` = DNS에 묻는 명령).

**이렇게 나오면 성공** (`dig`는 가운데 부분만, 주소·시간은 달라도 됨)

```
nameserver 127.0.0.53
Link 2 (eth0): 1.1.1.1 8.8.8.8
```
```
;; QUESTION SECTION:
;example.com.			IN	A

;; ANSWER SECTION:
example.com.		300	IN	A	104.20.23.154
example.com.		300	IN	A	172.66.147.243

;; Query time: 48 msec
;; SERVER: 127.0.0.53#53(127.0.0.53) (UDP)
```

- `QUESTION` = "`example.com`의 A(주소)를 알려 주세요", `ANSWER` = 주소가 **두 개**. 둘 중 아무 곳으로 가도 됩니다
- `300` = 이 답을 300초 동안 기억해 둬도 됨(TTL, 2단계)
- `SERVER: 127.0.0.53` = VM 안의 중계에게 물었고, 중계는 `1.1.1.1`·`8.8.8.8`에 물어 답을 받아 왔습니다
- 주소만 보고 싶으면 `dig +short example.com`

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `dig: command not found` | 로컬 환경에 도구 없음 | `sudo apt-get install -y dnsutils` (서버 VM에는 있음) |
| `status: SERVFAIL`, ANSWER 없음 | 바깥 DNS에 못 닿음 | `dig @8.8.8.8 example.com`로 직접 물어보기. 그래도 안 되면 질문 |
| 주소가 문서와 다름 | 사이트가 주소를 바꿈 | 정상. A 줄이 있으면 됨 |

</details>

## 2단계. 레코드 종류와 TTL

```bash
dig +noall +answer www.github.com
dig +noall +answer NS example.com
dig +noall +answer example.com; sleep 5; dig +noall +answer example.com
```

**이 명령은**: `+noall +answer` = 답(ANSWER) 줄만 보여 줌. 1줄 = `www.github.com`을 물음. 2줄 = `example.com`을 **맡은 DNS 서버**(NS)를 물음. 3줄 = 같은 질문을 5초 간격으로 두 번.

**이렇게 나오면 성공** (TTL 숫자는 달라도 됨)

```
www.github.com.		3592	IN	CNAME	github.com.
github.com.		60	IN	A	20.200.245.247
example.com.		6414	IN	NS	hera.ns.cloudflare.com.
example.com.		6414	IN	NS	elliott.ns.cloudflare.com.
example.com.		299	IN	A	172.66.147.243
example.com.		299	IN	A	104.20.23.154
example.com.		294	IN	A	104.20.23.154
example.com.		294	IN	A	172.66.147.243
```

| 레코드 | 뜻 | 위 출력 |
|---|---|---|
| A | 이 이름의 주소 | `github.com` → `20.200.245.247` |
| CNAME | 이 이름은 저 이름과 같음 → 저 이름을 다시 찾음 | `www.github.com` → `github.com` |
| NS | 이 이름을 맡은 DNS 서버 | `example.com` → Cloudflare의 서버 두 대 |
| TTL(둘째 칸) | 이 답을 기억해 둬도 되는 초 | `299` → 5초 뒤 `294` |

- TTL이 **줄어든 것** = 두 번째 답은 바깥에 다시 묻지 않고 기억해 둔 답입니다. 0이 되면 다시 묻습니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| TTL이 안 줄고 둘 다 `300` | 첫 질문 직후 기억이 지워졌거나 TTL이 막 끝남 | 3줄을 한 번 더 |
| 아무것도 안 나옴 | `+noall` 뒤 `+answer`를 빠뜨림 | 복사 버튼으로 다시 |

</details>

## 3단계. DNS 조회 경로 — dig +trace

```bash
dig +trace +nodnssec example.com | grep -E "Received|^example.com"
```

**이 명령은**: 중계에게 맡기지 않고 **맨 위(루트)부터 직접** 차례로 물어 가는 길을 보여 줌. `grep`으로 "누구에게 받았나"(`Received`) 줄과 `example.com` 줄만 남김.

**이렇게 나오면 성공** (서버 이름·시간은 달라도 됨)

```
;; Received 239 bytes from 127.0.0.53#53(127.0.0.53) in 0 ms
;; Received 836 bytes from 199.7.83.42#53(l.root-servers.net) in 2 ms
example.com.		172800	IN	NS	hera.ns.cloudflare.com.
example.com.		172800	IN	NS	elliott.ns.cloudflare.com.
;; Received 359 bytes from 192.43.172.30#53(i.gtld-servers.net) in 73 ms
example.com.		300	IN	A	172.66.147.243
example.com.		300	IN	A	104.20.23.154
;; Received 72 bytes from 172.64.35.228#53(elliott.ns.cloudflare.com) in 3 ms
```

| 순서 | 물어본 곳 | 받은 답 |
|---|---|---|
| ① | 중계(`127.0.0.53`) | 루트 서버 목록 |
| ② | 루트(`l.root-servers.net`) | "`.com`은 gtld 서버들이 맡음" |
| ③ | `.com`(`i.gtld-servers.net`) | "`example.com`은 Cloudflare의 이 서버가 맡음"(NS) |
| ④ | Cloudflare(`elliott.ns.cloudflare.com`) | 주소(A) |

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `couldn't get address for …` 또는 시간 초과 | 루트 서버 쪽 길이 막힘(망에 따라 직접 DNS를 막음) | 서버 VM에서는 됨. 로컬 환경이면 결과 표만 보고 넘어감 |
| `RRSIG`·`DS` 줄이 잔뜩 | `+nodnssec`를 빠뜨림 | 복사 버튼으로 다시 |

</details>

## 4단계. 연결 맺기 — TCP 3-way handshake

```bash
sudo -v
sudo timeout 8 tcpdump -lni eth0 -c 3 'tcp port 80 and host example.com' & sleep 1; curl -s -o /dev/null -w "%{http_code}\n" http://example.com; wait
```

**이 명령은**: 1줄 = sudo 비밀번호를 미리(물으면 VM 비밀번호). 2줄 = 뒤에서 tcpdump가 VM 바깥 선(`eth0`)의 `example.com` 80번 패킷 **처음 3개**를 찍는 동안(`&`), 1초 뒤 curl로 `http://example.com`에 접속.

**이렇게 나오면 성공** (주소·포트·시각·숫자는 달라도 됨)

```
listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
22:45:09.313614 IP 10.10.1.23.38002 > 172.66.147.243.80: Flags [S], seq 3091130646, win 64240, ...
22:45:09.347832 IP 172.66.147.243.80 > 10.10.1.23.38002: Flags [S.], seq 1876996487, ack 3091130647, ...
22:45:09.347900 IP 10.10.1.23.38002 > 172.66.147.243.80: Flags [.], ack 1, ...
3 packets captured
200
```

| 줄 | 누가 → 누구 | 표시 | 뜻 |
|---|---|---|---|
| 1 | VM → 서버 | `[S]` | 연결할까요? (SYN) |
| 2 | 서버 → VM | `[S.]` | 좋아요, 저도요 (SYN-ACK) |
| 3 | VM → 서버 | `[.]` | 알겠어요 (ACK) — 이제 연결됨 |

- 1줄과 2줄의 시각 차(`0.034`초) = VM과 서버 사이를 **한 번 왕복**한 시간입니다
- 이 세 번 다음에야 HTTP 요청(`GET /`)이 갑니다. 마지막 `200` = 응답 성공

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `[1]+ Stopped` 후 멈춤 | sudo가 비밀번호를 물어 뒤에서 멈춤 | `fg` → 비밀번호 → Ctrl+C. 1줄 `sudo -v`부터 다시 |
| `0 packets captured` | 다른 선을 봄, 또는 curl이 먼저 끝남 | `ip -br addr`로 `10.10.1.N`이 붙은 선 이름 확인. 2줄 다시 |
| `[S]`만 여러 번, `[S.]` 없음 | 답이 안 옴(길이나 방화벽) | 이 단계에서는 정상적으로 안 나옴. 질문 |

</details>

## 5단계. 암호화와 인증서 — TLS

```bash
openssl s_client -connect example.com:443 -servername example.com </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
curl -s -o /dev/null https://104.20.23.154; echo "[$?]"
curl -sS -o /dev/null --resolve example.com:443:20.200.245.247 https://example.com; echo "[$?]"
```

**이 명령은**: 1줄 = `example.com` 443번에 TLS로 붙어(`-servername` = SNI로 이름을 알림) 서버가 내민 **인증서**의 주인(subject) · 발급자(issuer) · 유효 기간 · 다른 이름(SAN)을 봄. 2줄 = 이름 없이 **주소로** HTTPS 접속. 3줄 = `example.com`이라고 말하면서 실제로는 **다른 서버**(GitHub의 주소)로 가게 속여 봄.

**이렇게 나오면 성공** (2·3줄은 실패하는 것이 맞음)

```
subject=CN = example.com
issuer=C = US, O = SSL Corporation, CN = Cloudflare TLS Issuing ECC CA 3
notBefore=Sep 26 22:49:11 2026 GMT
notAfter=Dec 25 22:56:35 2026 GMT
X509v3 Subject Alternative Name: 
    DNS:example.com, DNS:*.example.com
[35]
curl: (60) SSL: no alternative certificate subject name matches target host name 'example.com'
More details here: https://curl.se/docs/sslcerts.html
...
[60]
```

| 줄 | 결과 | 뜻 |
|---|---|---|
| 1 | subject `example.com`, issuer Cloudflare … CA 3 | "이 서버는 `example.com`"이라는 증명서, 보증한 곳 |
| 2 | `[35]` TLS 인사 실패 | 주소 하나에 사이트가 수천 개 — 이름(SNI)이 없으니 어느 인증서를 줄지 몰라 거절 |
| 3 | `[60]` 이름이 안 맞음 | 가짜 서버(GitHub)는 `github.com` 인증서를 냄 → curl이 멈춤. **주소를 속여도 TLS가 막음** |

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 1줄이 빈 출력·`unable to load certificate` | 443번에 못 붙음 | `curl -sI https://example.com`이 되는지 먼저 |
| 2줄이 `[0]` | 그 주소의 서버가 이름 없이도 인증서를 줌(사이트가 바뀜) | 결과만 적고 진행 |
| 3줄이 `[28]`·`[7]` | GitHub 주소가 바뀌어 연결이 안 됨 | `dig +short github.com`의 주소로 `20.200.245.247` 자리를 바꿔 다시 |

</details>

## 6단계. 응답과 걸린 시간 — HTTP

```bash
curl -sv -o /dev/null https://example.com 2>&1 | grep -E "^\* (Connected|SSL connection|ALPN: server)|^\*  (subject|issuer|SSL certificate verify)|^> (GET|Host)|^< HTTP"
for i in 1 2 3; do curl -s -o /dev/null -w "이름 %{time_namelookup}  연결 %{time_connect}  TLS %{time_appconnect}  첫 바이트 %{time_starttransfer}  끝 %{time_total}\n" https://example.com; done
```

**이 명령은**: 1줄 = curl이 지나는 과정을 자세히(`-v`) 보고 그중 연결 · TLS · 인증서 확인 · 보낸 요청(`>`) · 받은 응답(`<`) 줄만 남김. 2줄 = 같은 요청 세 번, 단계마다 **시작부터 몇 초**에 끝났는지.

**이렇게 나오면 성공** (시간은 달라도 됨)

```
* Connected to example.com (104.20.23.154) port 443
* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384 / X25519 / id-ecPublicKey
* ALPN: server accepted h2
*  subject: CN=example.com
*  subjectAltName: host "example.com" matched cert's "example.com"
*  issuer: C=US; O=SSL Corporation; CN=Cloudflare TLS Issuing ECC CA 3
*  SSL certificate verify ok.
> GET / HTTP/2
> Host: example.com
< HTTP/2 200 
이름 0.001170  연결 0.039028  TLS 0.085402  첫 바이트 0.136403  끝 0.136474
이름 0.000716  연결 0.036684  TLS 0.084532  첫 바이트 0.155864  끝 0.155945
이름 0.001002  연결 0.060992  TLS 0.128806  첫 바이트 0.206973  끝 0.207731
```

| 칸 | 끝난 일 | 첫 줄 기준 |
|---|---|---|
| 이름 | DNS (1~3단계) | 0.001초 — 기억해 둔 답 |
| 연결 | TCP 인사 세 번 (4단계) | 0.039초 — 왕복 한 번 |
| TLS | 인증서 확인·암호 맞추기 (5단계) | 0.085초 — 왕복 한 번 더 |
| 첫 바이트 | 요청을 보내고 응답 첫 글자를 받음 | 0.136초 |
| 끝 | 응답을 다 받음 | 0.136초 |

- 숫자는 **처음부터 쌓인 시간**입니다. TLS 칸에서 연결 칸을 빼면 TLS에 든 시간(약 0.046초)
- 요청 한 번에 **왕복이 서너 번** 듭니다. 서버가 멀수록 이 왕복이 길어집니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 1줄이 아무것도 안 나옴 | `2>&1` 빠뜨림(`-v` 내용은 오류 쪽으로 나옴) | 복사 버튼으로 다시 |
| `HTTP/1.1 200` | curl이 HTTP/2를 못 씀(로컬 환경) | 정상 |
| 시간이 0.5초 넘게 들쭉날쭉 | 망이 붐빔 | 세 줄 중 작은 값을 봄 |

</details>

## 7단계. 클러스터 안의 이름 — CoreDNS

```bash
kubectl -n todo exec deploy/load -c curl -- cat /etc/resolv.conf
kubectl -n todo exec deploy/load -c curl -- nslookup web.todo.svc.cluster.local
kubectl -n kube-system get svc kube-dns
nslookup web.todo.svc.cluster.local
```

**이 명령은**: 1줄 = todo의 `load` 파드(curl만 든 파드) 안의 DNS 설정. 2줄 = 파드 안에서 web Service의 이름을 물음. 3줄 = 클러스터의 DNS 서버(CoreDNS)의 Service. 4줄 = **VM에서** 같은 이름을 물음.

**이렇게 나오면 성공** (Service 주소는 달라도 됨, 4줄은 실패하는 것이 맞음)

```
search todo.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5
Server:		10.96.0.10
Address:	10.96.0.10:53

Name:	web.todo.svc.cluster.local
Address: 10.96.14.87
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   4d3h
;; Got SERVFAIL reply from 127.0.0.53
Server:		127.0.0.53
Address:	127.0.0.53#53

** server can't find web.todo.svc.cluster.local: SERVFAIL
```

- 파드는 이름을 `10.96.0.10`(= `kube-dns` Service, 그 뒤가 CoreDNS)에 묻습니다. `web` → `10.96.14.87`(web Service 주소)
- `search` 줄 덕분에 파드 안에서는 `web`(같은 네임스페이스) · `frontend.shop`(다른 네임스페이스)처럼 줄여 써도 됩니다 — 앞 과목에서 쓴 그 이름들
- VM은 클러스터 밖이라 같은 이름을 못 풉니다(`SERVFAIL`). **그 망 안에서만 통하는 이름** = 회사 **사내 DNS**에만 적힌 내부 이름과 같은 성질

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `Error from server (NotFound): deployments.apps "load" not found` | 모니터링 과목의 `load`를 지웠음 | `kubectl -n todo create deploy load --image=curlimages/curl:8.16.0 -- sh -c "while true; do curl -s -o /dev/null http://web/api/todos; sleep 1; done"` 후 30초 뒤 다시 |
| `error: container curl is not valid` | 컨테이너 이름이 다름 | `kubectl -n todo get deploy load -o jsonpath='{.spec.template.spec.containers[*].name}'`의 이름으로 `-c` 자리를 바꿈 |
| 2줄 뒤에 `NXDOMAIN` 줄이 더 붙음 | 짧은 이름(`web`)으로 물음 | 정상 동작이지만 헷갈리니 긴 이름 그대로 |

</details>

## 끝났는지 확인

- ☐ `dig example.com`의 A 두 줄과 `SERVER`를 찾음
- ☐ CNAME · NS · TTL(줄어드는 것)을 2단계 출력에서 찾음
- ☐ `dig +trace`에서 루트 → `.com` → Cloudflare 순서를 봄
- ☐ tcpdump에서 `[S]` → `[S.]` → `[.]` 세 줄을 봄
- ☐ 인증서의 subject · issuer를 읽고, `[35]` · `[60]`의 뜻을 말할 수 있음
- ☐ `curl -w`의 시간 네 칸을 DNS · TCP · TLS · HTTP에 짝지음
- ☐ 파드에서는 `web.todo.svc.cluster.local`이 풀리고 VM에서는 `SERVFAIL`

## 정리

지울 것 없음. 읽기만 했습니다.

### 클라우드에서는

- 이 실습의 DNS 서버 자리를 AWS에서는 **Route 53**이 맡습니다. 도메인을 맡는 서버(3단계 표의 ④ 자리)도, 망 안에서만 풀리는 내부 이름(7단계와 같은 성질 — "비공개 호스팅 영역")도 Route 53으로 만듭니다
- AWS의 쿠버네티스(EKS)에서도 클러스터 안 이름은 CoreDNS가 맡고, 모르는 이름은 VPC의 DNS(Route 53 Resolver)에 넘깁니다
- 인증서(5단계)는 AWS에서 **ACM**이 발급해 로드밸런서에 붙입니다. 전체 대응은 교안 06장 대응표

## 확인 문제

1. `dig +short www.naver.com`을 해 보세요. 마지막 줄의 주소가 나오기까지 이름이 몇 번 바뀌었나요? 어떤 레코드 종류 때문인가요?
2. `curl -s -o /dev/null -w "%{http_code} [%{time_connect}]\n" https://1.1.1.1`의 연결 칸과 6단계 `example.com`의 연결 칸을 비교하세요. 어느 쪽 서버가 더 가까운가요?
