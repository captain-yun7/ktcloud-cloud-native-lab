[← 실습 4](./04-Docker-설치와-hello-world.md) · [목차](../Docker-실습.md) · [실습 6 →](./06-컨테이너-다루기.md)

# 실습 5. nginx 웹 서버 띄우기

**무엇을 하나요**: 웹 서버 프로그램(nginx, "엔진엑스")을 컨테이너로 띄우고, VM 포트로 접속해 응답과 로그를 확인합니다. 설치 없이 이미지 이름 하나로 웹 서버가 뜨는 것을 봅니다. (교안 04장)

**필요한 것**: 실습 4에서 설치한 Docker.

> **바로 가기** · [1. nginx 컨테이너 띄우기](#1단계-nginx-컨테이너-띄우기) · [2. 실행 중인지 보기](#2단계-실행-중인지-보기) · [3. 접속해 보기](#3단계-접속해-보기) · [4. 로그 보기](#4단계-로그-보기) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. nginx 컨테이너 띄우기

```bash
docker run -d --name web -p 8081:80 nginx:1.29-alpine
```

**이 명령은**

| 옵션 | 뜻 |
|---|---|
| `-d` | 백그라운드(뒤에서) 실행 — 터미널이 바로 돌아옴 (d = detached) |
| `--name web` | 컨테이너 이름을 `web`으로 (없으면 무작위 이름) |
| `-p 8081:80` | **VM의 8081번**으로 온 요청을 **컨테이너의 80번**으로 보냄. 왼쪽이 VM, 오른쪽이 컨테이너. 자세한 뜻은 05장에서 |
| `nginx:1.29-alpine` | 이미지 이름 `nginx`, 태그(버전) `1.29-alpine`(alpine = 작은 리눅스를 바탕으로 만든 판) |

**이렇게 나오면 성공**: 처음에는 이미지를 받는 줄(`Pull complete` 등)이 먼저 나오고, 마지막에 긴 글자 한 줄(컨테이너 ID)이 나옵니다. 예: `deebf9cc55bcee6a070f4000f39ee83dbe45af1745b42615bc98a3ac6f83756d`

## 2단계. 실행 중인지 보기

```bash
docker ps
```

**이렇게 나오면 성공** — 화면 예. `NAMES`가 `web`, `STATUS`가 `Up …`(실행 중)이면 성공입니다.

```
CONTAINER ID   IMAGE               COMMAND                  CREATED        STATUS        PORTS                                     NAMES
deebf9cc55bc   nginx:1.29-alpine   "/docker-entrypoint.…"   1 second ago   Up 1 second   0.0.0.0:8081->80/tcp, [::]:8081->80/tcp   web
```

| 열 | 뜻 |
|---|---|
| `CONTAINER ID` | 컨테이너 번호(사람마다 다름) |
| `IMAGE` | 어떤 이미지로 만들었나 |
| `STATUS` | `Up` = 실행 중, `Exited` = 멈춤 |
| `PORTS` | `0.0.0.0:8081->80/tcp` = VM 8081 → 컨테이너 80 |
| `NAMES` | 컨테이너 이름 |

## 3단계. 접속해 보기

```bash
curl localhost:8081          # Welcome to nginx!
```

**이렇게 나오면 성공**: HTML(웹 페이지 글) 여러 줄이 나오고, 그 안에 `<title>Welcome to nginx!</title>`과 `<h1>Welcome to nginx!</h1>`이 보입니다("nginx에 오신 것을 환영합니다" = 웹 서버가 잘 동작함).

## 4단계. 로그 보기

```bash
docker logs web              # 방금 요청이 access log로 보임
```

**이 명령은**: 컨테이너 `web`이 화면에 찍은 기록(로그)을 보여 줌. access log = 받은 요청 기록

**이렇게 나오면 성공** — 화면 예(맨 끝 부분). 로그 맨 끝의 `"GET / HTTP/1.1" 200`이 방금 `curl`로 보낸 요청입니다.

```
2026/09/30 23:57:12 [notice] 1#1: start worker process 33
172.17.0.1 - - [30/Sep/2026:23:57:13 +0000] "GET / HTTP/1.1" 200 896 "-" "curl/8.5.0" "-"
```

- `[notice] … start worker process` = nginx가 일할 준비를 함(시작 기록)
- 요청 줄: 누가(`172.17.0.1` = VM 쪽에서 들어온 요청) 무엇을(`GET /`) 요청했고 결과 200(성공). 실습 1의 파이썬 웹 서버 기록과 같은 모양입니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `Conflict. The container name "/web" is already in use …` | 1단계를 두 번 실행해 `web`이 이미 있음 | 이미 떠 있으니 2단계로 넘어가면 됩니다(`docker ps`로 확인) |
| `port is already allocated` | VM 8081번을 다른 컨테이너가 사용 중 | `docker ps`로 8081을 쓰는 컨테이너를 확인. 실습 6에서 자세히 다룹니다 |
| `curl: (7) Failed to connect …` | 컨테이너가 안 떠 있거나 포트 번호가 다름 | `docker ps`에서 `web`이 `Up`이고 PORTS가 `8081->80`인지 확인 |

</details>

`web`은 실습 6에서 계속 씁니다. **지우지 마세요.**

## 끝났는지 확인
- ☐ `docker ps`에 `web`이 `Up`으로 보인다
- ☐ `curl localhost:8081`에 `Welcome to nginx!`가 나온다
- ☐ `docker logs web` 끝에 `"GET / HTTP/1.1" 200` 줄이 있다

## 정리
- 지우지 않습니다. `web`은 실습 6에서 씁니다

## 확인 문제
1. `nginx:1.29-alpine`으로 이름 `site`, VM 포트 9090인 컨테이너를 백그라운드로 실행하고 `curl`로 확인하세요. (`site`는 실습 6 확인 문제에서 씁니다)
