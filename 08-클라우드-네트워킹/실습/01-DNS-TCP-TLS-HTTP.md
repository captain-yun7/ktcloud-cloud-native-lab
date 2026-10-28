[← 시작하기 전에](./00-시작하기-전에.md) · [목차](../클라우드-네트워킹-실습.md) · [실습 2 →](./02-VM의-IP-주소와-경로-확인.md)

# 실습 1. DNS · TCP · TLS · HTTP

**무엇을 하나요**: 브라우저에 `https://example.com`을 치면 네 가지 일이 차례로 일어납니다. **이름을 주소로 바꾸고(DNS)** → **그 주소와 연결을 맺고(TCP)** → **암호를 맞추고 상대가 진짜인지 확인하고(TLS)** → **요청을 보내 응답을 받습니다(HTTP)**. 1단계에서 DNS를 `dig`로 보고, 2단계에서 나머지 세 가지를 `curl` 한 번으로 봅니다. 3단계에서 쿠버네티스 클러스터 안의 이름 찾기(CoreDNS)를 봅니다. (교안 01장)

**필요한 것**: 서버 VM과 지금 클러스터(todo의 `load` 파드 — 모니터링 과목에서 만듦). 새로 만들거나 지우는 것은 없습니다.

> **바로 가기** · [1. 이름을 주소로 — dig](#1단계-이름을-주소로--dig) · [2. TCP 연결 · TLS · HTTP 응답 — curl](#2단계-tcp-연결--tls--http-응답--curl) · [3. 클러스터 안의 이름 — CoreDNS](#3단계-클러스터-안의-이름--coredns) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

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
- `300` = 이 답을 300초 동안 기억해 둬도 됨(TTL)
- `SERVER: 127.0.0.53` = VM 안의 중계에게 물었고, 중계는 `1.1.1.1`·`8.8.8.8`에 물어 답을 받아 왔습니다
- 주소만 보고 싶으면 `dig +short example.com`

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `dig: command not found` | 로컬 환경에 도구 없음 | `sudo apt-get install -y dnsutils` (서버 VM에는 있음) |
| `status: SERVFAIL`, ANSWER 없음 | 바깥 DNS에 못 닿음 | `dig @8.8.8.8 example.com`로 직접 물어보기. 그래도 안 되면 질문 |
| 주소가 문서와 다름 | 사이트가 주소를 바꿈 | 정상. A 줄이 있으면 됨 |

</details>

## 2단계. TCP 연결 · TLS · HTTP 응답 — curl

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

- `Connected to example.com (104.20.23.154) port 443` = 1단계에서 얻은 주소로 **TCP 연결**을 맺음(443 = https 포트)
- `SSL connection` ~ `SSL certificate verify ok.` = **TLS**. 주고받을 내용을 암호화하고, 서버가 내민 인증서의 이름(`example.com`)이 내가 부른 이름과 맞는지 확인함
- `>` = 내가 보낸 **HTTP** 요청(`GET /`), `<` = 받은 응답. `200` = 성공

| 칸 | 끝난 일 | 첫 줄 기준 |
|---|---|---|
| 이름 | DNS (1단계) | 0.001초 — 기억해 둔 답 |
| 연결 | TCP 연결 맺기 | 0.039초 — 왕복 한 번 |
| TLS | 인증서 확인·암호 맞추기 | 0.085초 — 왕복 한 번 더 |
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

## 3단계. 클러스터 안의 이름 — CoreDNS

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
- ☐ `curl -v` 출력에서 `Connected`(TCP) · `SSL certificate verify ok`(TLS) · `HTTP/2 200`(HTTP) 줄을 찾음
- ☐ `curl -w`의 시간 칸을 DNS · TCP · TLS · HTTP에 짝지음
- ☐ 파드에서는 `web.todo.svc.cluster.local`이 풀리고 VM에서는 `SERVFAIL`

## 정리

지울 것 없음. 읽기만 했습니다.

### 클라우드에서는

- 이 실습의 DNS 서버 자리를 AWS에서는 **Route 53**이 맡습니다. 도메인의 주소를 적어 두는 일도, 망 안에서만 풀리는 내부 이름(3단계와 같은 성질 — "비공개 호스팅 영역")도 Route 53으로 만듭니다
- AWS의 쿠버네티스(EKS)에서도 클러스터 안 이름은 CoreDNS가 맡고, 모르는 이름은 VPC의 DNS(Route 53 Resolver)에 넘깁니다
- 인증서(2단계에서 curl이 확인한 것)는 AWS에서 **ACM**이 발급해 로드밸런서에 붙입니다. 전체 대응은 교안 06장 대응표

## 확인 문제

1. `curl -s -o /dev/null -w "%{http_code} [%{time_connect}]\n" https://1.1.1.1`의 연결 칸과 2단계 `example.com`의 연결 칸을 비교하세요. 어느 쪽 서버가 더 가까운가요?
2. 3단계의 `load` 파드에서 `kubectl -n todo exec deploy/load -c curl -- nslookup frontend.shop.svc.cluster.local`을 해 보세요. 나온 주소는 무엇의 주소인가요? 같은 이름을 VM에서 물으면 왜 안 풀리나요?
