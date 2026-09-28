# Docker — 실습

> 검증: 2026-09-25, s30(Ubuntu 24.04, 4코어/16GB), Docker 29.8.1 / Compose v5.5.1 / buildx 0.37.1, Online Boutique v0.10.7 (실습 4~6·10은 2026-09-27, 확인 문제 정답은 2026-09-28 s30 실측)
> 모든 명령은 본인 VM(`ssh ktc-sNN`)에서 실행합니다. 교안에 **실습 안내** 슬라이드가 나오면 이 문서의 해당 실습을 처음부터 끝까지 스스로 진행합니다. 막히면 Discord에 질문합니다.
> 실습마다 **목표** → 명령과 설명 → **끝났는지 확인** → **확인 문제** 순서입니다. 확인 문제는 방금 한 명령을 조금 바꿔 보는 문제이고, 필요한 명령은 모두 그 실습까지 나왔습니다.

## 흐름
| 장 | 실습 | 무엇을 하나 |
|---|---|---|
| 01 | — | 리눅스·Git 기초 (설명만) |
| 02 | — | 컨테이너 개념 (설명만) |
| 03 | 실습 1~6 | 설치, 첫 컨테이너, nginx 띄우기, 컨테이너 다루기, 이미지 정리 |
| 04 | 실습 7 | 컨테이너가 VM의 프로세스임을 확인 |
| 05 | 실습 8~11 | 사라지는 파일시스템, 레이어, 첫 Dockerfile, 샘플앱 받기 |
| 06 | 미션 1 | [Docker-미션.md 미션 1](./Docker-미션.md) — frontend 이미지 빌드 |
| 07 | 실습 12 | 싱글스테이지와 멀티스테이지 비교 |
| 08 | 실습 13 | 네트워크 — 컨테이너 이름으로 찾기 |
| 09 | 실습 14 | 첫 Compose |
| 10 | 실습 15 | 볼륨 두 종류 |
| 11 | 실습 16 | 레지스트리에 올리기 |
| 12 | 미션 2 | [Docker-미션.md 미션 2](./Docker-미션.md) — Compose로 Online Boutique 조립 |
| 13 | — | 정리 |

---

## 실습 1. Docker 설치

**목표**: VM에 Docker를 설치하고 `sudo` 없이 `docker` 명령을 쓸 수 있게 합니다.

공식 저장소로 설치합니다. `apt install docker.io`(우분투 패키지)는 버전이 낮아 쓰지 않습니다. 아래 블록을 순서대로 붙여 넣습니다. 중간에 비밀번호를 물으면 VM 계정 비밀번호를 입력합니다.

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

| 단계 | 하는 일 |
|---|---|
| 1~2줄 | 패키지 목록을 새로 받고, 다운로드에 필요한 도구 설치 |
| 3~5줄 | Docker 저장소의 서명 키를 받아 둠 (진짜 Docker 패키지인지 확인하는 데 씀) |
| 6~8줄 | Docker 저장소 주소를 apt에 등록 |
| 9~10줄 | 목록을 다시 받고 Docker 엔진·CLI·Compose 설치 |

`sudo` 없이 쓰도록 docker 그룹에 추가하고 **다시 로그인**합니다.

```bash
sudo usermod -aG docker $USER
exit            # 로그아웃 후 ssh ktc-sNN 으로 다시 접속
docker --version
docker compose version
docker ps
```

기대 출력: `Docker version 29.x`, `Docker Compose version v5.x`, `docker ps`는 제목 줄(`CONTAINER ID   IMAGE ...`)만 나옴

> ⚠️ 자주 막히는 곳: 다시 접속하지 않고 `docker ps` → `permission denied ... docker.sock`. 그룹 변경은 새 로그인부터 적용됩니다.

**끝났는지 확인**: 다시 접속한 뒤 `sudo` 없이 `docker ps`가 오류 없이 제목 줄을 보여 주면 끝입니다.

### 확인 문제
1. `groups` 명령으로 내 계정이 `docker` 그룹에 들어 있는지 확인하고, `docker version` 출력에서 Client 버전과 Server(엔진) 버전을 각각 찾으세요.

## 실습 2. 첫 컨테이너

**목표**: 컨테이너를 처음 실행해 보고, Docker가 이미지를 받아 컨테이너를 만드는 과정을 출력으로 확인합니다.

```bash
docker run --rm hello-world
```

- `docker run` = 이미지로 컨테이너를 만들어 실행. 이미지가 VM에 없으면 먼저 받아 옵니다(pull)
- `--rm` = 실행이 끝나면 컨테이너를 자동으로 지움

출력에 적힌 4단계(클라이언트 → 데몬 → 이미지 pull → 컨테이너 생성)를 읽어 봅니다. 처음 실행하면 맨 위에 `Unable to find image 'hello-world:latest' locally`와 `Pull complete`가 먼저 나옵니다.

**끝났는지 확인**: 출력에 `Hello from Docker!`가 보이면 끝입니다.

### 확인 문제
1. `hello-world`를 이번에는 `--rm` 없이 이름 `hello`(`--name hello`)로 실행하세요. 그다음 `docker ps -a`(멈춘 컨테이너까지 모두 보기)로 `hello`가 남아 있는지 확인하고, `docker rm hello`로 지우세요.

## 실습 3. nginx 웹 서버 띄우기

**목표**: 웹 서버(nginx) 컨테이너를 백그라운드로 띄우고, VM 포트로 접속해 응답과 로그를 확인합니다.

```bash
docker run -d --name web -p 8080:80 nginx:1.29-alpine
docker ps
curl localhost:8080          # Welcome to nginx!
docker logs web              # 방금 요청이 access log로 보임
docker logs -f web           # 실시간 (Ctrl+C로 빠져나옴)
```

| 옵션 | 뜻 |
|---|---|
| `-d` | 백그라운드 실행 |
| `--name web` | 이름 지정 (없으면 무작위 이름) |
| `-p 8080:80` | VM의 8080 → 컨테이너의 80 |

- `nginx:1.29-alpine` = 이미지 이름 `nginx`, 태그(버전) `1.29-alpine`
- `curl`은 터미널에서 웹 페이지를 받아 보는 명령입니다. HTML이 그대로 출력됩니다
- 로그 맨 끝의 `"GET / HTTP/1.1" 200`이 방금 `curl`로 보낸 요청입니다

`web`은 실습 8까지 계속 씁니다. **지우지 마세요.**

**끝났는지 확인**: `docker ps`에 `web`이 `Up`으로 보이고, `curl localhost:8080`에 `Welcome to nginx!`가 나오면 끝입니다.

### 확인 문제
1. `nginx:1.29-alpine`으로 이름 `site`, VM 포트 9090인 컨테이너를 백그라운드로 실행하고 `curl`로 확인하세요. (`site`는 실습 7의 확인 문제까지 계속 씁니다)

## 실습 4. 컨테이너 켜고 끄고 지우기

**목표**: 컨테이너를 멈추고·다시 켜고·지우는 명령을 익히고, 자주 만나는 오류 3가지를 일부러 내서 고쳐 봅니다.

실습 3의 `web`은 그대로 두고, 연습용 `web2`를 하나 더 띄워 상태를 바꿔 봅니다.

```bash
docker run -d --name web2 -p 8081:80 nginx:1.29-alpine
docker ps                   # web, web2 둘 다 STATUS가 Up
docker stop web2
docker ps                   # web2가 안 보임
docker ps -a                # web2  Exited (0) ... — 멈췄을 뿐 남아 있음
docker start web2
docker restart web2         # 멈췄다가 바로 다시 시작
docker ps                   # web2  Up ...
```

로그는 전체를 보지 않고 끝부분만 보거나, 실시간으로 봅니다.

```bash
curl localhost:8081         # 요청 두 번
curl localhost:8081
docker logs --tail 3 web2   # 마지막 3줄만
docker logs -f web2         # 실시간 (Ctrl+C로 빠져나옴, 컨테이너는 계속 실행)
```

기대 출력 (`logs --tail 3`, 날짜·번호는 다름):
```
2026/09/27 14:05:32 [notice] 1#1: start worker process 25
172.17.0.1 - - [27/Sep/2026:14:05:32 +0000] "GET / HTTP/1.1" 200 896 "-" "curl/8.5.0" "-"
172.17.0.1 - - [27/Sep/2026:14:05:32 +0000] "GET / HTTP/1.1" 200 896 "-" "curl/8.5.0" "-"
```

| 명령 | 하는 일 |
|---|---|
| `docker stop` | 멈춤. 컨테이너는 남아 있음 (`ps -a`에 Exited) |
| `docker start` | 멈춘 컨테이너를 다시 시작 |
| `docker restart` | 멈췄다가 다시 시작 |
| `docker logs --tail N` | 마지막 N줄만 |
| `docker logs -f` | 실시간 보기 |

### 일부러 오류 내고 고치기

오류 문구를 한 번 봐 두면 나중에 만났을 때 바로 고칠 수 있습니다.

**① 같은 이름으로 또 실행** — `web`은 실습 3에서 이미 만들었습니다.

```bash
docker run -d --name web -p 8082:80 nginx:1.29-alpine
```
```
docker: Error response from daemon: Conflict. The container name "/web" is already in use by container "…". You have to remove (or rename) that container to be able to reuse that name.
```
고치기: 다른 이름을 쓰거나, 기존 컨테이너를 지운 뒤 다시 실행합니다.

**② 이미 쓰는 VM 포트로 실행** — 8080은 `web`이 쓰고 있습니다.

```bash
docker run -d --name web3 -p 8080:80 nginx:1.29-alpine
```
```
docker: Error response from daemon: failed to set up container networking: driver failed programming external connectivity on endpoint web3 (…): Bind for 0.0.0.0:8080 failed: port is already allocated
```
실패해도 컨테이너는 만들어져 `Created`로 남습니다. 지우고 다른 포트로 다시 실행합니다.

```bash
docker ps -a                # web3  Created
docker rm web3
docker run -d --name web3 -p 8082:80 nginx:1.29-alpine
curl localhost:8082         # Welcome to nginx!
```

**③ 실행 중인 컨테이너 지우기**

```bash
docker rm web3
```
```
Error response from daemon: cannot remove container "web3": container is running: stop the container before removing or force remove
```
고치기: 멈춘 뒤 지우거나(`docker stop web3` → `docker rm web3`), `-f`로 한 번에 지웁니다.

```bash
docker rm -f web3
docker rm -f web2
docker ps -a                # web만 남음
```

| 오류 문구 | 원인 | 고치는 법 |
|---|---|---|
| `Conflict. The container name ... is already in use` | 같은 이름의 컨테이너가 이미 있음 (멈춘 것 포함) | 다른 이름, 또는 `docker rm` 후 다시 |
| `port is already allocated` | VM 포트를 다른 컨테이너가 사용 중 | 다른 VM 포트. 실패한 컨테이너는 `Created`로 남으니 `docker rm` |
| `container is running` | 실행 중인 컨테이너는 그냥 지울 수 없음 | `docker stop` 후 `rm`, 또는 `docker rm -f` |

**끝났는지 확인**: `docker ps -a`에 `web`만 `Up`으로 남아 있으면 끝입니다. (확인 문제용 `site`는 있어도 됩니다)

### 확인 문제

> `site`가 없으면(실습 3 확인 문제를 건너뛰었거나 지웠으면) 먼저 띄우세요: `docker run -d --name site -p 9090:80 nginx:1.29-alpine`

1. `site`를 멈추고 `docker ps`와 `docker ps -a`를 각각 실행해 `site`가 어디에 어떤 상태로 보이는지 확인한 뒤, 다시 시작하세요.
2. `site`에 `curl`로 두 번 접속한 뒤, 로그의 마지막 2줄만 보세요.

## 실습 5. 컨테이너 안 들여다보기

**목표**: 실행 중인 컨테이너 안에 들어가 보고, 파일을 넣고 빼고, 설정 정보와 환경변수를 확인합니다.

**안으로 들어가기** — `exec -it`로 컨테이너 안의 셸을 엽니다.

```bash
docker exec -it web sh
```
```
/ # ls /usr/share/nginx/html
50x.html    index.html
/ # cat /etc/hostname
d5fb959f3c80
/ # exit
```
- 프롬프트가 `/ #`로 바뀌면 컨테이너 안입니다. `exit`로 VM에 돌아와도 컨테이너는 계속 실행됩니다
- `-i`는 키보드 입력 연결, `-t`는 터미널 화면. 둘을 합쳐 `-it`
- hostname은 컨테이너 ID 앞 12자리 (값은 사람마다 다름)

**파일 넣고 빼기** — `docker cp 보낼곳 받을곳`. 컨테이너 쪽은 `이름:경로`로 적습니다.

```bash
mkdir -p ~/drill && cd ~/drill
echo "<h1>hello from cp</h1>" > hello.html
docker cp hello.html web:/usr/share/nginx/html/hello.html     # VM → 컨테이너
curl localhost:8080/hello.html                                # <h1>hello from cp</h1>
docker cp web:/etc/nginx/conf.d/default.conf .                # 컨테이너 → VM (. = 지금 폴더)
head -5 default.conf
```
```
Successfully copied 23B (transferred 2.05kB) to web:/usr/share/nginx/html/hello.html
Successfully copied 1.09kB (transferred 3.07kB) to /home/lab/drill/.
```

**자세한 정보 보기** — `inspect`는 설정 전체를 JSON으로 보여 줍니다(200줄이 넘음). `-f`로 필요한 값만 뽑습니다.

```bash
docker inspect web | head -20
docker inspect -f '{{.State.Status}}' web                                        # running
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' web # 172.17.0.x
```

> ⚠️ 인터넷 자료의 `-f '{{.NetworkSettings.IPAddress}}'`는 Docker 29에서 `map has no entry for key "IPAddress"` 오류가 납니다. 위의 `range` 형태를 씁니다.

**환경변수 넣기** — `-e 이름=값`

```bash
docker run -d --name envtest -e GREETING=hello nginx:1.29-alpine
docker exec envtest printenv GREETING            # hello
docker inspect -f '{{.Config.Env}}' envtest
# [GREETING=hello PATH=/usr/local/sbin:... NGINX_VERSION=1.29.8 ...]
docker rm -f envtest
```

**끝나면 자동 삭제** — `--rm`

```bash
docker run --rm -e GREETING=hi nginx:1.29-alpine sh -c 'echo $GREETING'   # hi
docker ps -a                                     # 방금 컨테이너는 목록에 없음
```
- 이미지 이름 뒤에 명령을 적으면 이미지의 기본 명령(nginx 실행) 대신 그 명령을 실행하고 끝냅니다
- `sh -c '…'` = 따옴표 안의 문장을 컨테이너 안의 셸이 실행. **작은따옴표**라야 `$GREETING`을 VM 셸이 아니라 컨테이너가 풉니다

**`-d` 없이 실행** — 로그가 화면을 차지하고, Ctrl+C를 누르면 컨테이너가 멈춥니다.

```bash
docker run --name fg nginx:1.29-alpine
# ... nginx 시작 로그가 계속 나옴 → Ctrl+C
# ... signal 2 (SIGINT) received, exiting
docker ps -a                                     # fg  Exited (0)
```
`fg`는 지우지 말고 둡니다. 실습 6에서 정리합니다.

| | `-d` 있음 | `-d` 없음 |
|---|---|---|
| 터미널 | 바로 돌아옴 | 로그가 계속 나옴 |
| Ctrl+C | — | 컨테이너가 멈춤 (Exited) |

**끝났는지 확인**: `curl localhost:8080/hello.html`이 `<h1>hello from cp</h1>`를 보여 주고, `docker ps -a`에 `web`(Up)과 `fg`(Exited)가 있으면 끝입니다.

### 확인 문제

> `site`가 없으면(실습 3 확인 문제를 건너뛰었거나 지웠으면) 먼저 띄우세요: `docker run -d --name site -p 9090:80 nginx:1.29-alpine`

1. VM의 `~/drill` 폴더에 `note.html`(내용 `<p>note</p>`)을 만들어 `site`의 `/usr/share/nginx/html/`에 넣고 `curl localhost:9090/note.html`로 확인하세요. 그다음 `site` 안에 셸로 들어가 같은 폴더의 파일 목록에 `note.html`이 있는지 보고 나오세요.
2. 환경변수 `MODE=dev`를 넣은 `nginx:1.29-alpine` 컨테이너를 끝나면 자동으로 지워지게 실행해 `echo $MODE`의 결과를 보고, 실행 뒤 `docker ps -a`에 남지 않았는지 확인하세요.

## 실습 6. 이미지 다루기와 정리

**목표**: 이미지를 받고·이름표를 붙이고·지우는 법과, 멈춘 컨테이너를 정리하는 법을 익힙니다.

```bash
docker pull redis:alpine                          # 08장에서 쓸 이미지 미리 받기
docker image ls
docker tag redis:alpine my-redis:v1               # 같은 이미지에 이름표 하나 더
docker image ls --filter reference='*redis*'
docker rmi my-redis:v1                            # 이름표만 떼어짐
docker system df                                  # 디스크 사용량
```

기대 출력 (처음 받을 때 `pull`):
```
alpine: Pulling from library/redis
…: Pull complete
Digest: sha256:…
Status: Downloaded newer image for redis:alpine
docker.io/library/redis:alpine
```
이미 있으면 `Status: Image is up to date for redis:alpine`

기대 출력 (`tag` 뒤 `image ls`, `rmi`):
```
IMAGE            ID             DISK USAGE   CONTENT SIZE   EXTRA
my-redis:v1      3811787313eb        161MB         39.6MB
redis:alpine     3811787313eb        161MB         39.6MB

Untagged: my-redis:v1
```
- 두 줄의 ID가 같음 → 이미지는 하나이고 이름만 둘
- `rmi`로 이름이 하나 남은 이미지를 지우면 `Deleted:`까지 나오며 실제로 지워짐

기대 출력 (`system df`, 값은 사람마다 다름):
```
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          …         …         …         …
Containers      …         …         …         …
Local Volumes   …         …         …         …
Build Cache     …         …         …         …
```

**멈춘 컨테이너 정리** — 실습 5의 `fg`가 `Exited`로 남아 있습니다.

```bash
docker ps -a                 # fg  Exited (0)
docker container prune       # y 입력
```
```
WARNING! This will remove all stopped containers.
Are you sure you want to continue? [y/N] y
Deleted Containers:
…
Total reclaimed space: 77.82kB
```
실행 중인 `web`은 지워지지 않습니다. 하나만 지울 때는 이름을 지정하는 `docker rm fg`가 안전합니다.

> ⚠️ **실행하지 말고 알아만 둘 명령**: `docker image prune -a`(컨테이너가 쓰지 않는 이미지 전부 삭제), `docker system prune -a`(멈춘 컨테이너·안 쓰는 네트워크·이미지·빌드 캐시 전부 삭제). 내가 만들지 않은 이미지까지 지워, 다음 실습에서 다시 받아야 합니다. 여러 사람이 쓰는 서버에서는 남의 이미지까지 지웁니다. 정리는 이름을 지정한 `rm` · `rmi`로 합니다.

**끝났는지 확인**: `docker image ls`에 `redis:alpine`은 있고 `my-redis:v1`은 없으며, `docker ps -a`에 `fg`가 없으면 끝입니다.

### 확인 문제
1. `nginx:1.29-alpine`에 `my-nginx:test` 이름표를 붙이고 두 이름의 IMAGE ID가 같은지 확인한 뒤, `my-nginx:test`만 지우세요. (`nginx:1.29-alpine`은 남아 있어야 합니다)

## 실습 7. 컨테이너는 프로세스다 ⭐

**목표**: 컨테이너가 VM 위에서 도는 평범한 프로세스이고, 네임스페이스로 따로 떨어져 보일 뿐임을 명령으로 확인합니다.

컨테이너 **밖**(VM)에서 nginx 프로세스를 찾습니다.

```bash
ps -eo pid,user,cmd | grep "[n]ginx: master"
docker inspect -f '{{.State.Pid}}' web
```

두 PID가 **같습니다**. 컨테이너는 가상 머신이 아니라 VM의 리눅스 커널 위에서 도는 평범한 프로세스입니다.

컨테이너 **안**에서 봅니다.

```bash
docker exec web hostname
docker exec web ps
docker exec web cat /etc/os-release
docker exec web uname -r ; uname -r
```

- 안에서는 nginx가 **PID 1**이고 프로세스가 몇 개 안 보임 → PID 네임스페이스
- hostname이 VM과 다름 → UTS 네임스페이스
- OS는 Alpine으로 보이지만 **커널 버전은 VM과 같음** → 파일시스템만 다르고 커널은 공유
- `ps -eo pid,user,cmd` = VM의 모든 프로세스를 PID·사용자·명령으로 출력. `grep "[n]ginx: master"`는 그중 nginx 주 프로세스 줄만 고름(대괄호는 `grep` 자신이 결과에 섞이지 않게 하는 요령)
- 확인 문제용 `site`도 떠 있으면 `nginx: master` 줄이 두 개 보입니다. 그중 하나가 `inspect` PID와 같으면 됩니다

**끝났는지 확인**: VM에서 찾은 nginx PID와 `docker inspect`의 PID가 같고, 컨테이너 안 `uname -r`과 VM의 `uname -r`이 같은 값이면 끝입니다.

### 확인 문제

> `site`가 없으면(실습 3 확인 문제를 건너뛰었거나 지웠으면) 먼저 띄우세요: `docker run -d --name site -p 9090:80 nginx:1.29-alpine`

1. `site`의 PID를 `docker inspect`로 확인하고, VM의 `ps` 출력에서 같은 번호의 nginx 프로세스를 찾으세요. 컨테이너 안(`docker exec site ps`)에서는 이 nginx가 몇 번으로 보이나요? 다 풀었으면 `docker rm -f site`로 정리하세요.

## 실습 8. 컨테이너 파일시스템은 사라진다

**목표**: 컨테이너 안에서 바꾼 파일은 컨테이너를 지우면 함께 사라진다는 것을 확인합니다.

```bash
docker exec web sh -c 'echo "<h1>hello from container</h1>" > /usr/share/nginx/html/index.html'
curl localhost:8080                    # hello from container
docker rm -f web
docker run -d --name web -p 8080:80 nginx:1.29-alpine
curl localhost:8080                    # 다시 Welcome to nginx!
docker rm -f web
```

- 컨테이너 안에서 바꾼 내용은 그 컨테이너 전용 **쓰기 레이어**에 저장됩니다. 컨테이너를 지우면 쓰기 레이어도 같이 사라짐
- 같은 이미지로 새로 만든 컨테이너는 이미지의 원래 상태에서 시작 → 남겨야 하는 데이터는 볼륨(실습 15)에 둡니다
- 실습 3부터 쓰던 `web`은 여기서 지웠습니다

**끝났는지 확인**: 두 번째 `curl`이 다시 `Welcome to nginx!`를 보여 주고, `docker ps -a`에 `web`이 없으면 끝입니다.

### 확인 문제
1. `nginx:1.29-alpine`으로 이름 `memo`, VM 포트 9092인 컨테이너를 띄워 `index.html`을 `<h1>memo</h1>`로 바꾼 뒤, 이번에는 지우지 말고 `docker restart memo`만 하세요. 바꾼 내용이 남아 있나요? 확인한 뒤 `memo`를 지우세요.

## 실습 9. 이미지와 레이어

**목표**: 이미지가 여러 레이어로 쌓여 있다는 것을 `history`로 확인합니다.

```bash
docker image ls
docker image history nginx:1.29-alpine
```

- 이미지 = 읽기 전용 레이어의 묶음. `history`의 한 줄이 Dockerfile 명령 하나이고, 0B인 줄은 설정만 바꾼 것
- 같은 레이어는 이미지끼리 공유 → 디스크와 다운로드가 한 번만 필요

- 맨 위 줄이 가장 나중에 쌓은 것, 맨 아래 줄이 가장 먼저 쌓은 것(베이스)입니다
- `CREATED BY`가 길면 뒤가 잘려 `…`로 보입니다. 앞부분(`RUN`, `COPY`, `ADD`, `CMD` 등)만 보면 됩니다

**끝났는지 확인**: `history` 출력에서 크기가 있는 줄(파일을 바꾼 명령)과 0B인 줄(설정만 바꾼 명령)을 구분할 수 있으면 끝입니다.

### 확인 문제
1. `docker image history redis:alpine`에서 크기가 가장 큰 줄은 몇 MB이고 어떤 명령(CREATED BY의 앞부분)인가요? 맨 아래 줄은 무엇을 넣는 명령인가요?

## 실습 10. 첫 Dockerfile 직접 쓰기

**목표**: Dockerfile을 직접 써서 내 이미지를 만들고, 내용을 바꿔 새 태그로 다시 빌드합니다.

HTML 한 장을 nginx 이미지에 넣은 내 이미지를 만듭니다.

```bash
mkdir -p ~/myweb && cd ~/myweb
echo "<h1>my first image v1</h1>" > index.html
cat > Dockerfile <<'DOCKER'
FROM nginx:1.29-alpine
WORKDIR /usr/share/nginx/html
COPY index.html .
DOCKER
```

| 줄 | 뜻 |
|---|---|
| `FROM nginx:1.29-alpine` | 이 이미지 위에 쌓는다 |
| `WORKDIR /usr/share/nginx/html` | 이후 명령의 기준 폴더 (nginx가 웹 문서를 읽는 곳) |
| `COPY index.html .` | VM의 `index.html`을 기준 폴더(`.`)에 복사 |

`cat > Dockerfile <<'DOCKER'` … `DOCKER`는 두 `DOCKER` 줄 사이의 내용을 파일로 저장하는 셸 문법입니다. `vi Dockerfile`로 직접 써도 됩니다. `cat Dockerfile`로 세 줄이 들어갔는지 확인합니다.

빌드하고 실행합니다. 맨 끝 `.`은 "지금 폴더의 파일을 재료로 쓴다"는 뜻입니다.

```bash
docker build -t myweb:v1 .
docker image ls myweb
docker run -d --name myweb1 -p 8083:80 myweb:v1
curl localhost:8083          # <h1>my first image v1</h1>
```

기대 출력 (`build`, 줄 일부 생략):
```
[+] Building 0.4s (8/8) FINISHED                                 docker:default
 => [internal] load build definition from Dockerfile                       0.0s
 => [1/3] FROM docker.io/library/nginx:1.29-alpine@sha256:5616878291a2eed  0.1s
 => [internal] load build context                                          0.0s
 => [2/3] WORKDIR /usr/share/nginx/html                                    0.0s
 => [3/3] COPY index.html .                                                0.0s
 => exporting to image                                                     0.1s
 => => naming to docker.io/library/myweb:v1                                0.0s
```

HTML을 고치고 **v2**로 다시 빌드합니다.

```bash
echo "<h1>my first image v2</h1>" > index.html
docker build -t myweb:v2 .
```
```
 => CACHED [2/3] WORKDIR /usr/share/nginx/html                             0.0s
 => [3/3] COPY index.html .                                                0.0s
```
- 바뀌지 않은 `WORKDIR` 줄은 `CACHED`(저장된 결과 재사용), 파일이 바뀐 `COPY` 줄만 다시 실행

태그 두 개를 비교합니다.

```bash
docker image ls myweb        # v1, v2 두 줄 — ID가 다름
curl localhost:8083          # 여전히 v1 — 컨테이너는 만들 때의 이미지 그대로
docker run -d --name myweb2 -p 8084:80 myweb:v2
curl localhost:8084          # <h1>my first image v2</h1>
docker rm -f myweb1 myweb2
```
```
IMAGE      ID             DISK USAGE   CONTENT SIZE   EXTRA
myweb:v1   …                   92.6MB           26MB   U
myweb:v2   …                   92.6MB           26MB
```
- EXTRA의 `U` = 이 이미지로 만든 컨테이너가 있음(사용 중)
- 이미지를 새로 빌드해도 이미 실행 중인 컨테이너는 바뀌지 않음 → 새 이미지로 컨테이너를 다시 만들어야 함
- 태그로 버전을 나눠 두면 이전 버전으로 되돌리기 쉬움

**끝났는지 확인**: `curl localhost:8084`가 `my first image v2`를 보여 주고, `docker image ls myweb`에 v1·v2 두 줄이 있으면 끝입니다.

### 확인 문제
1. `~/myweb`에서 문구를 `my first image v3`로 바꿔 `myweb:v3`를 빌드하고, 이름 `myweb3`, VM 포트 9091로 실행해 바뀐 문구를 확인하세요. 확인한 뒤 `myweb3`를 지우세요.

## 실습 11. 샘플앱 받고 Dockerfile 읽기

**목표**: 과정 내내 쓸 샘플앱(Online Boutique)을 받고, frontend의 Dockerfile을 한 줄씩 읽어 무엇을 하는지 이해합니다.

```bash
cd ~
git clone --depth 1 --branch v0.10.7 https://github.com/GoogleCloudPlatform/microservices-demo.git ob
ls ob/src          # 서비스 11개 + shoppingassistantservice(과정에서 사용 안 함)
cat ob/src/frontend/Dockerfile
```

`#`으로 시작하는 줄은 주석입니다. 나머지 줄을 아래 표를 보며 한 줄씩 읽습니다. **빌드는 [미션 1](./Docker-미션.md)에서 직접 합니다.**

| 줄 | 뜻 |
|---|---|
| `ARG …` | 빌드할 때만 쓰는 변수. 값을 주지 않으면 적힌 기본값을 씀 |
| `FROM … golang:1.27.0-alpine… AS builder` | Go 컴파일러가 든 이미지에서 시작. 이 단계에 `builder`라는 이름을 붙임 |
| `WORKDIR /src` | 이후 명령의 기준 폴더 |
| `COPY go.mod go.sum ./` | 의존성 목록 파일 두 개를 먼저 복사 |
| `RUN go mod download` | 빌드 중에 명령 실행 — 의존성(외부 라이브러리) 내려받기 |
| `COPY . .` | 나머지 소스 전부 복사 |
| `RUN … go build … -o /go/bin/frontend .` | 컴파일해서 실행 파일 하나를 만듦 |
| `FROM gcr.io/distroless/static` | 두 번째 `FROM` — 실행 파일만 돌릴 아주 작은 이미지에서 **새로** 시작 |
| `COPY --from=builder /go/bin/frontend /src/server` | `builder` 단계에서 만든 실행 파일만 가져옴 |
| `COPY ./templates ./templates`, `COPY ./static ./static` | 화면 템플릿과 이미지·CSS 파일 복사 |
| `ENV GOTRACEBACK=single` | 환경변수 설정 |
| `EXPOSE 8080` | 이 앱이 8080 포트를 쓴다고 적어 둠 (적어 두기만 하고 포트를 열지는 않음 — 여는 것은 `-p`) |
| `ENTRYPOINT ["/src/server"]` | 컨테이너가 시작할 때 실행할 명령 |

**끝났는지 확인**: `ls ~/ob/src`에 `frontend`를 포함한 서비스 폴더가 보이고, 위 표를 보며 frontend Dockerfile의 줄마다 무엇을 하는지 말할 수 있으면 끝입니다.

### 확인 문제
1. `~/ob/src/productcatalogservice/Dockerfile`을 열어 `FROM` 줄이 몇 개인지, 이 서비스가 `EXPOSE`로 적어 둔 포트가 몇 번인지 찾으세요.

---

> 실습 12부터는 미션 1 과제 1에서 만든 `my-frontend:v1`이 필요합니다. 없으면 `cd ~/ob/src/frontend && docker build -t my-frontend:v1 .`

## 실습 12. 싱글스테이지 vs 멀티스테이지

**목표**: 같은 앱을 `FROM` 한 번(싱글스테이지)으로 빌드해, 멀티스테이지로 만든 `my-frontend:v1`과 크기를 비교합니다.

미션 1에서 빌드한 frontend Dockerfile은 `FROM`이 두 번입니다. 한 번만 쓰면?

```bash
cd ~/ob/src/frontend
cat > Dockerfile.single <<'DOCKER'
FROM golang:1.27.0-alpine
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /src/server .
EXPOSE 8080
ENTRYPOINT ["/src/server"]
DOCKER
docker build -f Dockerfile.single -t my-frontend:single .
docker image ls my-frontend
```

기대 출력 (검증값):

| 태그 | 크기 |
|---|---|
| `single` | **1.68GB** |
| `v1` (멀티스테이지) | **44.2MB** |

- 싱글: Go 컴파일러·소스·캐시가 전부 최종 이미지에 남음
- 멀티: 1단계(`builder`)에서 컴파일만 하고, 2단계(`distroless/static`)에는 실행 파일과 템플릿만 복사
- 작은 이미지 = 빠른 배포 + 적은 공격면

```bash
docker run --rm --entrypoint sh my-frontend:v1    # 실패 — distroless에는 셸조차 없음
```

- `-f Dockerfile.single` = 기본 이름(`Dockerfile`)이 아닌 파일로 빌드
- `--entrypoint sh` = 이미지에 적힌 시작 명령 대신 `sh`를 실행. distroless에는 `sh`가 없어 `executable file not found` 오류가 납니다

**끝났는지 확인**: `docker image ls my-frontend`에 `single`(약 1.68GB)과 `v1`(약 44MB)이 함께 보이고, `--entrypoint sh` 실행이 `executable file not found` 오류로 실패하면 끝입니다.

### 확인 문제
1. `docker run --rm --entrypoint go 이미지 version`으로 `my-frontend:single`에는 Go 컴파일러가 남아 있고 `my-frontend:v1`에는 없음을 확인하세요. 확인한 뒤 디스크를 많이 차지하는 `my-frontend:single`을 지우세요.

## 실습 13. 네트워크 — 이름으로 찾기

**목표**: 기본 네트워크와 직접 만든 네트워크를 비교해, 컨테이너끼리 이름으로 찾으려면 무엇이 필요한지 확인합니다.

기본 네트워크에서는 컨테이너 이름으로 찾을 수 없습니다.

```bash
docker run -d --name r1 redis:alpine
docker run --rm redis:alpine redis-cli -h r1 ping
# Could not connect to Redis at r1:6379: Name does not resolve
```

사용자 정의 네트워크를 만들면 Docker 내장 DNS가 이름을 풀어 줍니다.

```bash
docker network create shop
docker run -d --name r2 --network shop redis:alpine
docker run --rm --network shop redis:alpine redis-cli -h r2 ping
# PONG
docker rm -f r1 r2 && docker network rm shop
```

Online Boutique의 서비스들은 서로를 `productcatalogservice:3550`처럼 **이름:포트**로 부릅니다. 미션 2의 핵심입니다.

- `redis-cli -h r1 ping` = 일회용 redis 컨테이너에서 `r1`에 ping을 보냄. `PONG`이 오면 연결 성공
- `--network shop` = 컨테이너를 `shop` 네트워크에 붙임. 붙이지 않으면 기본 네트워크(`bridge`)에 붙음

**끝났는지 확인**: 기본 네트워크에서는 `Name does not resolve`, `shop` 네트워크에서는 `PONG`이 나오고, 마지막 줄로 `r1`·`r2`·`shop`을 지웠으면 끝입니다.

### 확인 문제
1. 네트워크 `lab`을 만들고 `nginx:1.29-alpine` 컨테이너 `api`를 `lab`에 붙여 띄우세요. 그다음 `lab`에 붙인 일회용 컨테이너(`--rm`)에서 `wget -qO- api`를 실행해 nginx 첫 화면을 받아 보세요.
2. `api`의 IP 주소만 한 줄로 출력해 기본 네트워크 대역(`172.17.`)과 다른지 확인한 뒤, `api`와 `lab` 네트워크를 지우세요.

## 실습 14. 첫 Compose

**목표**: nginx와 redis 두 컨테이너를 `compose.yaml` 파일 하나로 함께 띄우고 관리합니다.

nginx 하나와 redis 하나를 파일 하나로 띄웁니다.

```bash
mkdir -p ~/hello/html && cd ~/hello
echo "<h1>hello compose</h1>" > html/index.html
cat > compose.yaml <<'YAML'
services:
  web:
    image: nginx:1.29-alpine
    ports: ["8081:80"]
    volumes: ["./html:/usr/share/nginx/html:ro"]
  cache:
    image: redis:alpine
    command: ["redis-server", "--appendonly", "yes"]
    volumes: ["cache-data:/data"]
volumes:
  cache-data:
YAML
docker compose up -d
docker compose ps
curl localhost:8081                         # hello compose
docker compose exec web ping -c1 cache      # 이름으로 찾아짐 — Compose가 네트워크를 자동으로 만든다
docker compose logs web
```

| 키 | 뜻 |
|---|---|
| `services` | 컨테이너 목록. 키 이름(web, cache)이 곧 네트워크 안의 이름 |
| `ports` | VM포트:컨테이너포트 |
| `volumes` | 데이터 연결 (다음 실습) |
| `command` | 이미지의 기본 실행 명령을 바꿈 |

> ⚠️ YAML 들여쓰기 오류는 `docker compose config`로 확인합니다.

- `docker compose` 명령은 `compose.yaml`이 있는 폴더(`~/hello`)에서 실행합니다
- `cat > compose.yaml <<'YAML'` … `YAML`은 두 `YAML` 줄 사이의 내용을 파일로 저장하는 셸 문법입니다. `vi compose.yaml`로 직접 써도 됩니다. YAML은 **들여쓰기(공백 2칸)**가 의미를 가지므로 탭 대신 공백을 씁니다

**끝났는지 확인**: `docker compose ps`에 `web`·`cache` 두 서비스가 보이고, `curl localhost:8081`이 `hello compose`, `ping`이 `1 packets received`를 보여 주면 끝입니다. 이 Compose는 실습 15에서 그대로 이어 씁니다.

### 확인 문제
1. `docker ps`와 `docker network ls`에서 Compose가 만든 컨테이너 이름과 네트워크 이름을 찾고, 이름이 어떤 규칙으로 붙었는지 적어 보세요.
2. `cache` 서비스만 멈췄다가 다시 시작하세요. 멈춘 동안 `docker compose ps`에는 무엇이 보이나요? 다시 시작한 뒤 `redis-cli ping`으로 응답을 확인하세요.

## 실습 15. 볼륨 두 종류

**목표**: 바인드 마운트와 이름 있는 볼륨의 차이를 보고, 컨테이너를 지워도 볼륨의 데이터가 남는지 확인합니다.

실습 14의 `~/hello` 폴더에서, 띄워 둔 Compose를 그대로 이어서 씁니다(`cd ~/hello`).

**바인드 마운트** — VM의 폴더를 그대로 연결. 고치면 바로 반영됩니다.

```bash
echo "<h1>hello compose v2</h1>" > html/index.html
curl localhost:8081                          # v2 — 재시작 없이 반영
```

**이름 있는 볼륨** — Docker가 관리하는 저장소. 컨테이너를 지워도 남습니다.

```bash
docker compose exec cache redis-cli set visits 42
docker compose down && docker compose up -d
docker compose exec cache redis-cli get visits    # "42" — 남아 있음
docker compose down -v && docker compose up -d
docker compose exec cache redis-cli get visits    # (nil) — -v는 볼륨까지 삭제
docker compose down -v
```
- `docker compose down` = 컨테이너와 네트워크를 지움. 이름 있는 볼륨은 남김
- `docker compose down -v` = 볼륨까지 지움 → 데이터가 사라짐

**끝났는지 확인**: `down` → `up` 뒤에는 `get visits`가 `"42"`, `down -v` → `up` 뒤에는 `(nil)`이 나오면 끝입니다.

### 확인 문제
1. `docker compose up -d`로 다시 띄운 뒤 `html/about.html`(내용 `<p>about</p>`)을 새로 만들어, 재시작 없이 `curl localhost:8081/about.html`로 보이는지 확인하세요.
2. `docker volume ls`에서 이 Compose가 만든 볼륨 이름을 찾으세요. 그다음 `docker compose down`과 `docker compose down -v`를 차례로 실행하며, 각각 실행한 뒤 볼륨이 남아 있는지 확인하세요.

## 실습 16. 레지스트리에 push

**목표**: VM 안에 연습용 레지스트리를 띄우고, 내 이미지를 레지스트리 주소가 붙은 이름으로 올린 뒤 목록으로 확인합니다.

이미지를 다른 곳(K8s, 팀원)에서 쓰려면 레지스트리에 올려야 합니다. VM 안에 연습용 레지스트리를 띄웁니다.

```bash
docker run -d -p 5000:5000 --name reg registry:3
docker tag my-frontend:v1 localhost:5000/my-frontend:v1
docker push localhost:5000/my-frontend:v1
curl localhost:5000/v2/_catalog        # {"repositories":["my-frontend"]}
```

레지스트리는 미션 2 과제 5에서 다시 씁니다. **지우지 마세요.**

**끝났는지 확인**: `curl localhost:5000/v2/_catalog`에 `my-frontend`가 보이면 끝입니다. 레지스트리 `reg`는 계속 켜 둡니다.

### 확인 문제
1. `nginx:1.29-alpine`에 `localhost:5000/web:v1` 이름표를 붙여 연습용 레지스트리에 올리고, `curl localhost:5000/v2/web/tags/list`로 태그 목록을 확인하세요. 이제 `_catalog`에는 무엇이 보이나요?

## 자주 쓴 명령
- 컨테이너: `run` (`-d` `--name` `-p` `-e` `--rm`) `ps` (`-a`) `stop` `start` `restart` `logs` (`--tail` `-f`) `exec` (`-it`) `cp` `inspect` (`-f`) `rm` (`-f`) `container prune`
- 이미지: `pull` `image ls` `image history` `tag` `rmi` `build` (`-t` `-f`) `system df`
- 네트워크·Compose·레지스트리: `network create` `compose up/ps/logs/exec/down/config` `volume ls` `push`
