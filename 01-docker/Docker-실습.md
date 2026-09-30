# Docker — 실습

- 모든 명령은 본인 VM(`ssh ktc-sNN`)에서 실행합니다. `NN`은 본인 번호입니다 — 예: 7번이면 `ssh ktc-s07`. 교안에 **실습 안내** 슬라이드가 나오면 이 문서의 해당 실습을 처음부터 끝까지 스스로 진행합니다. 막히면 Discord에 질문합니다.
- 실습마다 **목표** → 명령과 설명 → **끝났는지 확인** → **확인 문제** 순서입니다. 확인 문제는 방금 한 명령을 조금 바꿔 보는 문제이고, 필요한 명령은 모두 그 실습까지 나왔습니다.
- 실습 앱은 학생 저장소의 `lab/docker/` 폴더에 있습니다(실습 3에서 받습니다). `hello`(인사말 한 줄), `files`(글을 파일로 저장), `todo`(할 일 목록 — 화면·API·DB 3개) 세 가지를 씁니다.

## 흐름
| 장 | 실습 | 무엇을 하나 |
|---|---|---|
| 01 | 실습 1 | 네트워크 기초 — IP·포트·DNS·HTTP |
| 02 | 실습 2~3 | 셸 조합·nano, Docker 없이 Node 앱 직접 실행 |
| 03 | — | 왜 컨테이너인가 (설명만) |
| 04 | 실습 4~6 | Docker 설치, nginx 띄우기, 컨테이너 다루기 |
| 05 | 실습 7~8 | 첫 Dockerfile, 빌드 캐시와 COPY 순서 |
| 05 뒤 | 미션 1 | [Docker-미션.md 미션 1](./Docker-미션.md) — 내 앱 이미지 만들기 |
| 06 | 실습 9 | Docker Hub에 올리고 받기 |
| 07 | 실습 10~11 | 볼륨, 바인드 마운트 |
| 08 | 실습 12 | 네트워크 — API와 DB 연결 |
| 09 | 실습 13 | Compose로 할 일 앱(3티어) 띄우기 |
| 09 뒤 | 미션 2 | [Docker-미션.md 미션 2](./Docker-미션.md) — Compose로 Online Boutique 조립 |
| 10 | — | 정리 |

## 쓰는 포트
실습마다 VM 포트가 겹치지 않게 정해 두었습니다. 앞 실습의 컨테이너를 지우지 않았어도 다음 실습이 막히지 않습니다.

| VM 포트 | 쓰는 곳 |
|---|---|
| 8000 · 8001 | 실습 1 파이썬 웹 서버(8000) · 실습 7 hello v1·v2 |
| 3000 | 실습 3 Node 앱 직접 실행 |
| 8081 · 8082 · 9090 | 실습 5·6 nginx(`web`, `web2`, `site`) |
| 8002 | 실습 9 Docker Hub에서 받은 이미지 |
| 8003 · 8004 | 실습 10·11 files 앱 · 바인드 마운트 nginx |
| 8005 | 실습 12 todo API |
| 8088 | 실습 13 todo 화면 |
| 8010 · 8012 · 8013 | 실습 7 확인 문제 · 실습 9 옆 사람 이미지 · 실습 11 files |
| 5000 | 실습 9 연습용 레지스트리(Docker Hub 대신 쓸 때) |
| 8091~8093 | 미션 1 |
| 8080 | 미션 2 Online Boutique |

---

## 실습 1. 네트워크 기초 — 요청과 응답 보기

**목표**: 내 VM에서 IP 주소, DNS, 포트, HTTP 상태 코드를 명령으로 직접 확인합니다. (교안 01장)

실습용 폴더와 파일을 만듭니다. 명령의 뜻은 02장에서 봅니다. 그대로 붙여 넣으세요.

```bash
mkdir -p ~/basics && cd ~/basics
echo "<h1>hello basics</h1>" > index.html
```

**① 내 VM의 IP와 DNS**

```bash
hostname -I                 # 내 VM의 IP 주소 → 10.10.1.N
getent hosts github.com     # DNS에 이름을 물어 IP를 받음
# 20.200.245.247  github.com   (IP는 때와 장소에 따라 다를 수 있음)
```

**② 웹 서버 띄우기 — 터미널 1**

파이썬에 들어 있는 간단한 웹 서버를 8000번 포트로 띄웁니다. 지금 폴더(`~/basics`)의 파일을 돌려줍니다.

```bash
cd ~/basics
python3 -m http.server 8000
# Serving HTTP on 0.0.0.0 port 8000 (http://0.0.0.0:8000/) ...
```

명령이 끝나지 않고 멈춰 있는 것이 정상입니다(요청을 기다리는 중). 이 터미널은 그대로 두고 **터미널을 하나 더** 엽니다 — VS Code는 터미널 창의 `+`, 그 밖에는 새 창에서 `ssh ktc-sNN`.

**③ 기다리는 포트 보기 — 터미널 2**

```bash
ss -tln
```

출력 예(줄 순서·개수는 VM마다 다름). `Local Address:Port` 열의 콜론 뒤 숫자가 포트입니다.

```
State   Recv-Q  Send-Q   Local Address:Port   Peer Address:Port
LISTEN  0       4096     127.0.0.53%lo:53          0.0.0.0:*
LISTEN  0       5              0.0.0.0:8000        0.0.0.0:*
LISTEN  0       4096           0.0.0.0:22          0.0.0.0:*
```

| 옵션 · 값 | 뜻 |
|---|---|
| `-t` `-l` `-n` | TCP 연결만 · 기다리는(LISTEN) 것만 · 이름 대신 숫자로 |
| `:22` | SSH 서버 — 지금 접속해 있는 통로 |
| `:8000` | 방금 띄운 웹 서버 |
| `:53` | VM 안의 DNS 도우미 (127.0.0.53 = 이 VM 안에서만) |
| `0.0.0.0` | 이 VM의 모든 주소로 오는 요청을 받음 |

**④ 요청 보내고 상태 코드 보기 — 터미널 2**

```bash
curl localhost:8000              # 본문: <h1>hello basics</h1>
curl -I localhost:8000           # 머리(헤더)만: HTTP/1.0 200 OK
curl -I localhost:8000/nothing   # 없는 주소: HTTP/1.0 404 File not found
curl -I 127.0.0.1:8000           # localhost = 127.0.0.1 → 200 OK
curl -I https://github.com       # 인터넷의 서버 → HTTP/2 200
```

- `localhost`는 지금 이 컴퓨터 자신입니다. `127.0.0.1`과 같습니다
- `-I`는 응답의 머리(헤더)만 보여 줍니다. 첫 줄의 숫자가 **상태 코드** — 200 성공, 404 없는 주소, 500 서버 오류

터미널 1을 보면 방금 보낸 요청이 한 줄씩 찍혀 있습니다(`-I`는 `HEAD`, 그냥 `curl`은 `GET`으로 찍힘).

```
127.0.0.1 - - [28/Sep/2026 15:13:51] "GET / HTTP/1.1" 200 -
127.0.0.1 - - [28/Sep/2026 15:13:51] "HEAD /nothing HTTP/1.1" 404 -
```

다 봤으면 터미널 1에서 **Ctrl+C**로 웹 서버를 끕니다.

**끝났는지 확인**: `curl -I localhost:8000`에 `200 OK`, `curl -I localhost:8000/nothing`에 `404`가 나오고, 터미널 1에 요청 줄이 찍혔으면 끝입니다.

### 확인 문제
1. 웹 서버를 끈 상태에서 `curl localhost:8000`을 하면 어떤 오류가 나오나요? 이때 `ss -tln`에 8000 줄이 있나요?
2. 웹 서버를 이번에는 포트 8001로 띄우고(`python3 -m http.server 8001`), 다른 터미널에서 `curl -I localhost:8001/index.html`의 상태 코드를 확인하세요. 같은 때 `curl -I localhost:8000`은 어떻게 되나요? 확인이 끝나면 Ctrl+C로 끕니다.

## 실습 2. 셸 조합과 nano

**목표**: 명령을 이어 붙이고(`|`), 결과를 파일로 보내고(`>`, `>>`), 환경변수와 종료 코드를 확인합니다. 터미널 안에서 nano로 파일을 고칩니다. Docker 실습에서 계속 쓰는 문법입니다. (교안 02장)

**① 파이프와 리다이렉트**

```bash
cd ~/basics
cat /etc/os-release | grep CODENAME  # CODENAME이 든 줄만
# VERSION_CODENAME=noble
# UBUNTU_CODENAME=noble
echo "first" > note.txt      # > : 파일에 씀 (있던 내용은 지워짐)
echo "second" >> note.txt    # >> : 파일 끝에 이어 씀
cat note.txt                 # first / second 두 줄
echo "new" > note.txt
cat note.txt                 # new 한 줄만 남음
```

- `|`(파이프) = 앞 명령의 출력을 뒤 명령의 입력으로. `grep 글자` = 그 글자가 든 줄만 보여 줌
- `noble`은 우분투 24.04의 코드명입니다. 실습 4의 Docker 설치 명령이 이 값을 꺼내 씁니다

**② 환경변수와 종료 코드**

```bash
echo $HOME                   # /home/lab
export GREETING=hello        # 환경변수 만들기
echo $GREETING               # hello
env | grep GREETING          # GREETING=hello
ls nothing.txt               # ls: cannot access 'nothing.txt': No such file or directory
echo $?                      # 2
ls note.txt
echo $?                      # 0
```

- 환경변수 = 이름=값으로 둔 설정. `$이름`으로 꺼냅니다. 실습 3에서 `PORT=3001 node app.js`로 앱의 포트를 바꾸고, 실습 6부터는 `docker run -e`로 컨테이너에 넣습니다
- `$?` = 바로 앞 명령의 **종료 코드**. 0이면 성공, 0이 아니면 실패입니다. `docker ps -a`의 `Exited (0)` 괄호 안 숫자도 종료 코드입니다

**③ 터미널 편집기 nano**

```bash
nano memo.txt                # 없는 파일이면 새로 만듦
```

화면 맨 아래 두 줄이 단축키 안내입니다. `^`는 **Ctrl** 키입니다(`^O` = Ctrl+O).

1. 두 줄을 입력합니다: `hello nano`, `second line`
2. **Ctrl+O** → 맨 아래에 `File Name to Write: memo.txt`가 나오면 **Enter** → `[ Wrote 2 lines ]`
3. **Ctrl+X**로 나옵니다
4. `cat memo.txt`로 두 줄을 확인합니다

| 할 일 | 키 |
|---|---|
| 저장 | Ctrl+O → Enter |
| 종료 | Ctrl+X (저장 안 했으면 Y → Enter, 저장하지 않으려면 N) |
| 찾기 · 줄 잘라내기 · 붙이기 | Ctrl+W · Ctrl+K · Ctrl+U |

**vi가 열렸을 때 빠져나오기** — `git commit`처럼 편집기를 여는 명령이 vi(vim)를 열 때가 있습니다. `vi memo.txt`로 한 번 들어갔다가 **Esc** → `:q!` → **Enter**로 나와 봅니다(저장하지 않고 나감. 저장하고 나가려면 `:wq`).

**끝났는지 확인**: `cat note.txt`에 `new` 한 줄, `ls nothing.txt` 바로 뒤 `echo $?`에 `2`, `cat memo.txt`에 nano로 쓴 두 줄이 보이면 끝입니다.

### 확인 문제
1. `>>`로 `note.txt`에 `apple`, `banana` 두 줄을 이어 붙인 뒤 `cat note.txt | grep an`을 실행하세요. 무엇이 나오나요? 바로 뒤 `echo $?`의 값은?
2. nano로 `~/basics/index.html`을 열어 내용을 `<h1>edited by nano</h1>`로 바꿔 저장하세요. 실습 1처럼 웹 서버(`python3 -m http.server 8000`)를 띄우고 다른 터미널에서 `curl localhost:8000`으로 바뀐 내용을 확인한 뒤, 웹 서버를 Ctrl+C로 끕니다.

## 실습 3. Docker 없이 Node 앱 직접 실행

**목표**: 실습 앱을 받고, VM에 Node.js를 직접 설치해 `hello` 앱을 실행합니다. "앱 하나를 돌리려면 무엇을 준비해야 하는지"를 몸으로 겪어 보는 실습입니다. 03장에서 이 경험을 컨테이너와 비교합니다. (교안 02장)

**① 실습 저장소 받기** — `git clone` = GitHub의 저장소를 내 VM으로 복사

```bash
cd ~
git clone https://github.com/captain-yun7/ktcloud-cloud-native-lab.git
cd ~/ktcloud-cloud-native-lab/lab/docker/hello
ls
# app.js  package-lock.json  package.json
```

| 파일 | 내용 |
|---|---|
| `app.js` | 앱 코드. 3000번 포트로 요청을 기다리다가 `/`로 오면 `hello, docker`를 돌려줌 |
| `package.json` | 이 앱에 필요한 라이브러리 목록(`express` — Node.js로 웹 서버를 만드는 도구) |
| `package-lock.json` | 라이브러리의 정확한 버전을 적어 둔 파일 |

**② Node.js 설치** — 앱을 실행할 프로그램(Node.js)과 라이브러리 설치 도구(npm)

```bash
sudo apt-get update
sudo apt-get install -y --no-install-recommends nodejs npm
node -v                      # v18.19.1
npm -v                       # 9.2.0
```

- 우분투 24.04 저장소의 Node.js는 **18** 버전입니다. 실습 6에서 컨테이너 안의 Node.js 버전과 비교합니다
- `--no-install-recommends`를 빼면 권장 패키지까지 수백 개를 받아 몇 분이 더 걸립니다(깨끗한 우분투 24.04에서 약 45초 → 4분 30초)

**③ 라이브러리 받고 실행 — 터미널 1**

```bash
npm install
# added 68 packages, and audited 69 packages in 2s
# ...
node app.js
# hello app listening on port 3000
```

- `npm install` = `package.json`에 적힌 라이브러리를 받아 `node_modules` 폴더에 넣음
- `node app.js`는 끝나지 않고 멈춰 있는 것이 정상입니다(요청을 기다리는 중). 실습 1의 파이썬 웹 서버와 같습니다

**④ 요청 보내기 — 터미널 2** (터미널을 하나 더 엽니다)

```bash
curl localhost:3000          # hello, docker
```

**⑤ 끄기** — 터미널 1에서 **Ctrl+C**를 누른 뒤, 터미널 2에서 다시 요청합니다.

```bash
curl localhost:3000
# curl: (7) Failed to connect to localhost port 3000 after 0 ms: Couldn't connect to server
```

앱은 터미널 1에서 실행한 프로그램이라, Ctrl+C를 누르거나 터미널 1을 닫으면 같이 꺼집니다.

**직접 해 본 순서 정리** — 05장에서 Dockerfile의 줄과 하나씩 맞춰 봅니다.

| 순서 | 한 일 | 명령 |
|---|---|---|
| 1 | 실행 환경(Node.js) 설치 | `sudo apt-get install nodejs npm` |
| 2 | 앱 코드 가져오기 | `git clone …` → `cd …/hello` |
| 3 | 라이브러리 설치 | `npm install` |
| 4 | 실행 | `node app.js` |

설치한 Node.js는 **지우지 말고 둡니다**. 실습 6에서 VM의 `node -v`와 컨테이너의 `node -v`를 비교합니다. (과목이 끝난 뒤 지우려면 `sudo apt-get remove -y nodejs npm && sudo apt-get autoremove -y`)

**끝났는지 확인**: `node app.js`를 띄운 동안 `curl localhost:3000`에 `hello, docker`가 나오고, Ctrl+C 뒤에는 `Failed to connect`가 나오면 끝입니다.

### 확인 문제
1. 앱이 쓰는 포트는 환경변수 `PORT`로 바꿀 수 있습니다. 터미널 1에서 `PORT=3001 node app.js`로 실행하고, 터미널 2에서 `curl localhost:3001`과 `curl localhost:3000`의 결과를 각각 확인하세요.
2. 앱을 켜 둔 채 nano로 `app.js`의 `hello, docker`를 `hello, node`로 바꿔 저장하고 `curl localhost:3001`을 해 보세요. 바뀌었나요? 앱을 Ctrl+C로 끄고 다시 실행한 뒤에는 어떤가요? 확인이 끝나면 문구를 **`hello, docker`로 되돌리고** 앱을 끕니다(실습 7에서 이 폴더를 그대로 씁니다).

## 실습 4. Docker 설치와 hello-world

**목표**: VM에 Docker를 설치하고 `sudo` 없이 `docker` 명령을 쓸 수 있게 한 뒤, 첫 컨테이너를 실행합니다. (교안 04장)

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
| 3~5줄 | Docker 저장소의 서명 키(GPG 키)를 받아 둠 — 받은 패키지가 진짜 Docker가 만든 것인지 확인하는 데 씀 |
| 6~8줄 | Docker 저장소 주소를 apt에 등록 — 우분투 기본 저장소보다 최신 버전을 받기 위함 |
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

**첫 컨테이너**

```bash
docker run --rm hello-world
```

- `docker run` = 이미지로 컨테이너를 만들어 실행. 이미지가 VM에 없으면 먼저 Docker Hub에서 받아 옵니다(pull)
- `--rm` = 실행이 끝나면 컨테이너를 자동으로 지움

처음 실행하면 맨 위에 `Unable to find image 'hello-world:latest' locally`와 `Pull complete`가 먼저 나오고, 이어서 `Hello from Docker!`가 나옵니다. 출력 가운데 적힌 4단계(클라이언트 → 데몬 → 이미지 pull → 컨테이너 생성)가 04장 슬라이드의 `docker run` 3단계(내 VM에 이미지가 있나 → 없으면 Docker Hub에서 받기 → 실행)와 같은 이야기입니다.

**끝났는지 확인**: 다시 접속한 뒤 `sudo` 없이 `docker ps`가 오류 없이 제목 줄을 보여 주고, `docker run --rm hello-world`에 `Hello from Docker!`가 보이면 끝입니다.

### 확인 문제
1. `groups` 명령으로 내 계정이 `docker` 그룹에 들어 있는지 확인하고, `docker version` 출력에서 Client 버전과 Server(엔진) 버전을 각각 찾으세요.
2. `hello-world`를 이번에는 `--rm` 없이 이름 `hw`(`--name hw`)로 실행하세요. 그다음 `docker ps -a`(멈춘 컨테이너까지 모두 보기)로 `hw`가 남아 있는지 확인하세요. **`hw`는 지우지 말고 둡니다**(실습 6에서 씁니다).

## 실습 5. nginx 웹 서버 띄우기

**목표**: 웹 서버(nginx) 컨테이너를 백그라운드로 띄우고, VM 포트로 접속해 응답과 로그를 확인합니다. (교안 04장)

```bash
docker run -d --name web -p 8081:80 nginx:1.29-alpine
docker ps
curl localhost:8081          # Welcome to nginx!
docker logs web              # 방금 요청이 access log로 보임
```

| 옵션 | 뜻 |
|---|---|
| `-d` | 백그라운드 실행 (터미널이 바로 돌아옴) |
| `--name web` | 이름 지정 (없으면 무작위 이름) |
| `-p 8081:80` | VM의 8081 → 컨테이너의 80. 자세한 뜻은 05장에서 |

- `nginx:1.29-alpine` = 이미지 이름 `nginx`, 태그(버전) `1.29-alpine`
- 로그 맨 끝의 `"GET / HTTP/1.1" 200`이 방금 `curl`로 보낸 요청입니다

`web`은 실습 6에서 계속 씁니다. **지우지 마세요.**

**끝났는지 확인**: `docker ps`에 `web`이 `Up`으로 보이고, `curl localhost:8081`에 `Welcome to nginx!`가 나오면 끝입니다.

### 확인 문제
1. `nginx:1.29-alpine`으로 이름 `site`, VM 포트 9090인 컨테이너를 백그라운드로 실행하고 `curl`로 확인하세요. (`site`는 실습 6 확인 문제에서 씁니다)

## 실습 6. 컨테이너 다루기

**목표**: 컨테이너 안의 환경이 VM과 따로 떨어져 있음을 확인하고, 컨테이너를 멈추고·다시 켜고·들여다보고·지우는 명령을 익힙니다. 자주 만나는 오류 3가지도 일부러 내서 고쳐 봅니다. (교안 04장)

**① VM의 Node.js와 컨테이너의 Node.js** — 실습 3에서 VM에 Node.js 18을 설치했습니다.

```bash
node -v                                    # v18.19.1  ← VM에 설치한 것
docker run --rm node:22-alpine node -v     # v22.23.3  ← 컨테이너 안
```

같은 VM에서 실행했는데 버전이 다릅니다. 컨테이너는 이미지에 들어 있는 Node.js를 쓰고, VM에 설치된 것과 섞이지 않습니다. 컨테이너 안으로 들어가 보면 운영체제도 다릅니다.

```bash
docker run -it --rm node:22-alpine sh
```
```
/ # node -v
v22.23.3
/ # cat /etc/os-release | head -2
NAME="Alpine Linux"
ID=alpine
/ # exit
```
- `-it` = 키보드 입력과 터미널 화면을 연결(`-i` 입력, `-t` 터미널). 셸처럼 주고받는 프로그램을 실행할 때 붙입니다
- 프롬프트가 `/ #`로 바뀌면 컨테이너 안입니다. `exit`로 나오면 `--rm` 때문에 컨테이너가 지워집니다

**② 같은 이미지로 컨테이너 하나 더**

```bash
docker run -d --name web2 -p 8082:80 nginx:1.29-alpine
docker ps                   # web, web2 — 이미지는 같고 이름·포트가 다름
curl localhost:8082         # Welcome to nginx!
```

**③ 멈추고, 다시 켜고, 로그 보기**

```bash
docker stop web2
docker ps                   # web2가 안 보임
docker ps -a                # web2  Exited (0) ... — 멈췄을 뿐 남아 있음
docker start web2
curl localhost:8082         # 요청 두 번
curl localhost:8082
docker logs --tail 2 web2   # 마지막 2줄만
docker logs -f web2         # 실시간 (Ctrl+C로 빠져나옴, 컨테이너는 계속 실행)
```

| 명령 | 하는 일 |
|---|---|
| `docker ps` / `docker ps -a` | 실행 중인 것만 / 멈춘 것까지 모두 |
| `docker stop` · `docker start` | 멈춤(컨테이너는 남음) · 다시 시작 |
| `docker logs --tail N` · `-f` | 마지막 N줄 · 실시간 |

**④ 안으로 들어가기, 파일 넣고 빼기**

```bash
docker exec -it web sh
```
```
/ # ls /usr/share/nginx/html
50x.html    index.html
/ # exit
```
- `exec` = **실행 중인** 컨테이너 안에서 명령 실행. `exit`로 나와도 `web`은 계속 실행됩니다

`docker cp 보낼곳 받을곳` — 컨테이너 쪽은 `이름:경로`로 적습니다.

```bash
mkdir -p ~/drill && cd ~/drill
echo "<h1>hello from cp</h1>" > hello.html
docker cp hello.html web:/usr/share/nginx/html/hello.html     # VM → 컨테이너
curl localhost:8081/hello.html                                # <h1>hello from cp</h1>
docker cp web:/etc/nginx/conf.d/default.conf .                # 컨테이너 → VM (. = 지금 폴더)
head -5 default.conf
```

**⑤ 일부러 오류 내고 고치기** — 오류 문구를 한 번 봐 두면 나중에 바로 고칠 수 있습니다.

```bash
docker run -d --name web -p 8083:80 nginx:1.29-alpine     # 같은 이름
```
```
docker: Error response from daemon: Conflict. The container name "/web" is already in use by container "…". You have to remove (or rename) that container to be able to reuse that name.
```
```bash
docker run -d --name web3 -p 8081:80 nginx:1.29-alpine    # 쓰는 중인 VM 포트
```
```
docker: Error response from daemon: failed to set up container networking: driver failed programming external connectivity on endpoint web3 (…): Bind for 0.0.0.0:8081 failed: port is already allocated
```
```bash
docker ps -a                # web3  Created — 실패해도 컨테이너는 만들어져 남음
docker rm web3
docker rm web2              # 실행 중인 컨테이너 지우기
```
```
Error response from daemon: cannot remove container "web2": container is running: stop the container before removing or force remove
```
```bash
docker rm -f web2           # -f = 멈추고 지우기를 한 번에
```

| 오류 문구 | 원인 | 고치는 법 |
|---|---|---|
| `Conflict. The container name ... is already in use` | 같은 이름의 컨테이너가 이미 있음 (멈춘 것 포함) | 다른 이름, 또는 `docker rm` 후 다시 |
| `port is already allocated` | VM 포트를 다른 컨테이너가 사용 중 | 다른 VM 포트. 실패한 컨테이너는 `Created`로 남으니 `docker rm` |
| `container is running` | 실행 중인 컨테이너는 그냥 지울 수 없음 | `docker stop` 후 `rm`, 또는 `docker rm -f` |

**⑥ 이미지 지우기는 컨테이너 먼저** — 실습 4 확인 문제의 `hw`(hello-world, 멈춤)가 남아 있습니다. (없으면 `docker run --name hw hello-world`로 만듭니다)

```bash
docker rmi hello-world
```
```
Error response from daemon: conflict: unable to delete hello-world:latest (must be forced) - container … is using its referenced image …
```
```bash
docker rm hw                # 컨테이너 먼저
docker rmi hello-world      # Untagged: hello-world:latest / Deleted: sha256:…
```

멈춘 컨테이너라도 남아 있으면 그 이미지는 지울 수 없습니다. 순서는 **컨테이너(`rm`) → 이미지(`rmi`)** 입니다.

**⑦ 끝나면 자동 삭제, 환경변수 넣기**

```bash
docker run --rm -e GREETING=hi nginx:1.29-alpine sh -c 'echo $GREETING'   # hi
docker ps -a                                     # 방금 컨테이너는 목록에 없음
```
- `-e 이름=값` = 컨테이너에 환경변수를 넣음. 이미지 이름 뒤에 명령을 적으면 이미지의 기본 명령(nginx 실행) 대신 그 명령을 실행하고 끝냅니다
- **작은따옴표**라야 `$GREETING`을 VM 셸이 아니라 컨테이너가 풉니다

**⑧ 멈춘 컨테이너 한꺼번에 정리**

```bash
docker container prune      # y 입력 — 멈춘 컨테이너 전부 삭제. 실행 중인 web은 남음
```

> ⚠️ **실행하지 말고 알아만 둘 명령**: `docker image prune -a`, `docker system prune -a`(쓰지 않는 이미지·빌드 캐시까지 전부 삭제). 다음 실습에서 이미지를 다시 받아야 합니다. 정리는 이름을 지정한 `rm` · `rmi`로 합니다.

**끝났는지 확인**: `docker ps -a`에 `web`이 `Up`으로 있고 `web2`·`web3`·`hw`는 없으며, `curl localhost:8081/hello.html`이 `<h1>hello from cp</h1>`를 보여 주면 끝입니다. (`site`는 있어도 됩니다)

### 확인 문제

> `site`가 없으면 먼저 띄우세요: `docker run -d --name site -p 9090:80 nginx:1.29-alpine`

1. `site`를 멈추고 `docker ps`와 `docker ps -a`를 각각 실행해 `site`가 어디에 어떤 상태로 보이는지 확인한 뒤, 다시 시작하세요. 끝나면 `site`를 지웁니다.
2. 환경변수 `MODE=dev`를 넣은 `nginx:1.29-alpine` 컨테이너를 끝나면 자동으로 지워지게 실행해 `echo $MODE`의 결과를 보고, 실행 뒤 `docker ps -a`에 남지 않았는지 확인하세요.

## 실습 7. 첫 Dockerfile

**목표**: 실습 3에서 직접 실행한 `hello` 앱을 이미지로 만들고, 컨테이너로 실행합니다. `-p` 없이 실행하면 왜 접속이 안 되는지 보고 고칩니다. 코드를 고치면 이미지를 다시 빌드해야 한다는 것도 확인합니다. (교안 05장)

**① Dockerfile 쓰기** — 실습 3의 `hello` 폴더에서 nano로 `Dockerfile`(확장자 없음, D는 대문자)을 만듭니다.

```bash
cd ~/ktcloud-cloud-native-lab/lab/docker/hello
nano Dockerfile
```

```dockerfile
FROM node:22-alpine
WORKDIR /app
COPY . ./
RUN npm install
EXPOSE 3000
CMD ["node", "app.js"]
```

| 줄 | 뜻 | 실습 3에서 직접 한 일 |
|---|---|---|
| `FROM node:22-alpine` | Node.js 22가 들어 있는 이미지에서 시작 | `apt-get install nodejs npm` |
| `WORKDIR /app` | 이미지 안의 작업 폴더를 `/app`으로 (없으면 만듦) | `cd …/hello` |
| `COPY . ./` | 지금 폴더의 파일을 이미지의 `/app`으로 복사 | `git clone` |
| `RUN npm install` | **이미지를 만들 때** 실행 → 결과(`node_modules`)가 이미지에 들어감 | `npm install` |
| `EXPOSE 3000` | 이 앱이 3000번을 쓴다는 **메모**. 포트를 열지는 않음 | — |
| `CMD ["node", "app.js"]` | **컨테이너를 시작할 때** 실행할 명령 | `node app.js` |

- 폴더에 있는 `.dockerignore` 파일이 `node_modules`를 복사 대상에서 뺍니다(실습 3에서 VM에 받은 것 대신 이미지 안에서 새로 받음)

**② 빌드** — `.`은 "지금 폴더의 Dockerfile과 파일로"라는 뜻입니다.

```bash
docker build -t hello:v1 .
```
```
[+] Building 2.0s (9/9) FINISHED
 => [1/4] FROM docker.io/library/node:22-alpine@sha256:…
 => [2/4] WORKDIR /app
 => [3/4] COPY . ./
 => [4/4] RUN npm install
 => exporting to image
 => => naming to docker.io/library/hello:v1
```
- `-t hello:v1` = 이름 `hello`, 태그 `v1`. 처음 빌드하면 `node:22-alpine`을 받느라 조금 더 걸립니다

**③ `-p` 없이 실행 → 접속 안 됨**

```bash
docker run -d --name hello hello:v1
docker ps
```
```
NAMES     IMAGE      STATUS                  PORTS
hello     hello:v1   Up Less than a second   3000/tcp
```
```bash
curl localhost:3000
# curl: (7) Failed to connect to localhost port 3000 after 0 ms: Couldn't connect to server
```

앱은 **컨테이너 안의** 3000번에서 기다리고 있지만, VM의 3000번과는 연결돼 있지 않습니다. `PORTS`의 `3000/tcp`는 EXPOSE 메모일 뿐입니다.

**④ `-p`로 연결**

```bash
docker rm -f hello
docker run -d --name hello -p 8000:3000 hello:v1
docker ps                   # PORTS: 0.0.0.0:8000->3000/tcp
curl localhost:8000         # hello, docker
```
`-p 8000:3000` = **VM의 8000**으로 온 요청을 **컨테이너의 3000**으로. 왼쪽이 VM, 오른쪽이 컨테이너입니다.

**⑤ 코드를 고치면 다시 빌드**

```bash
nano app.js                 # 'hello, docker' → 'hello, 본인이름' 으로 고쳐 저장
curl localhost:8000         # hello, docker  ← 그대로
docker build -t hello:v2 .
docker run -d --name hello2 -p 8001:3000 hello:v2
curl localhost:8001         # hello, 본인이름
curl localhost:8000         # hello, docker  ← v1은 그대로
docker image ls hello
```
```
IMAGE      ID             DISK USAGE   CONTENT SIZE   EXTRA
hello:v1   ddc229905116        249MB         62.7MB   U
hello:v2   3c54718e611e        249MB         62.7MB   U
```
- 컨테이너는 빌드할 때의 파일로 만들어진 이미지로 실행됩니다. 폴더의 `app.js`를 고쳐도 실행 중인 컨테이너는 바뀌지 않습니다
- v1과 v2가 **동시에** 실행됩니다. VM에 Node.js를 설치하지 않았어도(실습 3의 Node.js 18과 상관없이) 이미지 안의 Node.js 22로 돌아갑니다

**끝났는지 확인**: `curl localhost:8000`에 `hello, docker`, `curl localhost:8001`에 `hello, 본인이름`이 나오면 끝입니다. `hello`·`hello2`는 실습 9까지 켜 둡니다.

### 확인 문제
1. `docker history hello:v2`로 이미지의 층을 보세요. 우리가 Dockerfile에 적은 줄 가운데 크기(SIZE)가 가장 큰 줄은 어느 것인가요? 왜 그럴까요?
2. `hello:v1` 이미지로 이름 `hello3`, VM 포트 8010인 컨테이너를 하나 더 실행해 `curl`로 확인하세요. 어떤 문구가 나오나요? 확인한 뒤 `hello3`는 지웁니다.

## 실습 8. 빌드 캐시와 COPY 순서

**목표**: Docker가 바뀌지 않은 줄은 저장해 둔 결과(캐시)를 다시 쓴다는 것을 보고, Dockerfile 줄 순서를 바꿔 `npm install`을 캐시로 건너뛰게 만듭니다. (교안 05장)

**① 아무것도 안 바꾸고 다시 빌드**

```bash
cd ~/ktcloud-cloud-native-lab/lab/docker/hello
docker build -t hello:v2 .
```
```
 => CACHED [2/4] WORKDIR /app
 => CACHED [3/4] COPY . ./
 => CACHED [4/4] RUN npm install
```
모든 줄이 `CACHED` — 저장해 둔 결과를 그대로 썼습니다.

**② app.js만 고치고 다시 빌드**

```bash
echo "// v3" >> app.js       # 파일 끝에 주석 한 줄 추가 (동작은 같음)
docker build -t hello:v3 .
```
```
 => CACHED [2/4] WORKDIR /app
 => [3/4] COPY . ./
 => [4/4] RUN npm install
```
`app.js`가 바뀌어 `COPY . ./`가 다시 실행됐고, **그 뒤 줄은 모두** 다시 실행됩니다. 라이브러리는 그대로인데 `npm install`을 또 합니다.

**③ 순서 바꾸기** — 라이브러리 목록(`package.json`, `package-lock.json`)만 먼저 복사해 `npm install`을 하고, 나머지 코드는 그다음에 복사합니다.

```bash
nano Dockerfile
```
```dockerfile
FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm install
COPY . ./
EXPOSE 3000
CMD ["node", "app.js"]
```
```bash
docker build -t hello:v3 .   # 순서가 바뀌어 한 번은 전부 다시
echo "// v3 again" >> app.js
docker build -t hello:v3 .
```
```
 => CACHED [2/5] WORKDIR /app
 => CACHED [3/5] COPY package.json package-lock.json ./
 => CACHED [4/5] RUN npm install
 => [5/5] COPY . ./
```
이제 코드만 고치면 `npm install`은 `CACHED`, 마지막 `COPY . ./`만 다시 합니다. 이 앱은 라이브러리가 적어 `npm install`이 1초 남짓이지만, 라이브러리가 많은 실제 앱은 이 줄이 몇 분씩 걸립니다. **자주 바뀌는 것(코드)은 아래로, 덜 바뀌는 것(라이브러리 목록)은 위로.**

**끝났는지 확인**: 순서를 바꾼 Dockerfile로 `app.js`만 고쳐 빌드했을 때 `CACHED [4/5] RUN npm install`이 보이면 끝입니다.

### 확인 문제
1. 순서를 바꾼 Dockerfile로 아무것도 고치지 않고 다시 빌드하면 `CACHED`가 붙는 줄은 몇 개인가요?
2. 순서를 바꾼 Dockerfile에서 `package.json`을 고치면(예: 라이브러리를 하나 추가) `npm install`은 캐시를 쓸까요, 다시 실행될까요? 이유를 한 줄로 적으세요. (실제로 고치지 않아도 됩니다)

## 실습 9. Docker Hub에 올리고 받기

**목표**: 실습 7에서 만든 `hello:v2` 이미지를 내 Docker Hub 계정에 올리고(push), 내 VM에서 지운 뒤 다시 받아(pull) 실행합니다. 옆 사람의 이미지도 받아 실행해 봅니다. (교안 06장)

**준비**: Docker Hub 계정이 필요합니다. 없으면 https://hub.docker.com 에서 가입합니다. 아래 `<아이디>`는 본인 Docker Hub 아이디로 바꿉니다(예: `kim123`).

**① 로그인**

```bash
docker login
```
화면에 나온 안내대로 브라우저에서 코드를 입력하거나, 아이디·비밀번호(또는 Docker Hub에서 만든 액세스 토큰)를 입력합니다. `Login Succeeded`가 나오면 됩니다.

- 로그인 정보는 VM의 `~/.docker/config.json`에 저장됩니다. 실습이 끝나면 `docker logout`으로 지울 수 있습니다

**② 이름 붙이기(tag) → 올리기(push)** — Docker Hub에 올릴 이미지의 이름은 `아이디/저장소:태그` 모양이어야 합니다.

```bash
docker tag hello:v2 <아이디>/hello:v2
docker image ls --filter reference='*hello*'   # hello:v2와 <아이디>/hello:v2의 ID가 같음 = 이미지 하나에 이름 둘
docker push <아이디>/hello:v2
```
```
The push refers to repository [docker.io/<아이디>/hello]
7a3b060021ff: Pushed
…
v2: digest: sha256:… size: 856
```
브라우저에서 `https://hub.docker.com/r/<아이디>/hello` 를 열면 `v2` 태그가 보입니다.

**③ 지우고 다시 받아 실행**

```bash
docker rmi <아이디>/hello:v2                   # Untagged: <아이디>/hello:v2 (이름표만 뗌)
docker run -d --name from-hub -p 8002:3000 <아이디>/hello:v2
```
```
Unable to find image '<아이디>/hello:v2' locally
v2: Pulling from <아이디>/hello
Digest: sha256:…
Status: Downloaded newer image for <아이디>/hello:v2
```
```bash
curl localhost:8002         # hello, 본인이름
```
`docker run`은 이미지가 VM에 없으면 레지스트리에서 받아(pull) 실행합니다. 다른 VM, 다른 사람의 컴퓨터에서도 이 명령 한 줄로 같은 앱이 돕니다.

**④ 옆 사람 이미지 받아 보기** — 옆 사람의 Docker Hub 아이디를 물어 받아 실행합니다. 공개 저장소는 로그인 없이도 받을 수 있습니다.

```bash
docker run --rm -d --name friend -p 8012:3000 <옆사람아이디>/hello:v2
curl localhost:8012         # hello, 옆사람이름
docker rm -f friend
```

**Docker Hub 로그인이 막히면** — VM 안에 연습용 레지스트리를 띄워 같은 순서(tag → push → rmi → run)를 해 봅니다. 레지스트리 주소가 이미지 이름 맨 앞에 붙는다는 점만 다릅니다.

```bash
docker run -d --name reg -p 5000:5000 registry:3
docker tag hello:v2 localhost:5000/hello:v2
docker push localhost:5000/hello:v2           # v2: digest: sha256:… size: 856
docker rmi localhost:5000/hello:v2            # Untagged: localhost:5000/hello:v2
docker run -d --name from-hub -p 8002:3000 localhost:5000/hello:v2
# Unable to find image 'localhost:5000/hello:v2' locally … Status: Downloaded newer image for localhost:5000/hello:v2
curl localhost:8002                           # hello, 본인이름
curl localhost:5000/v2/_catalog               # {"repositories":["hello"]}
```

**끝났는지 확인**: Docker Hub 웹에서 내 `hello` 저장소에 `v2`가 보이고, 받아서 실행한 `curl localhost:8002`에 내 이름이 나오면 끝입니다.

### 확인 문제
1. `hello:v1`에도 `<아이디>/hello:v1` 이름을 붙여 올리세요. Docker Hub 웹의 Tags 탭에 태그가 몇 개 보이나요?
2. 이미지를 공유할 때 `docker push`로 올리는 것은 이미지일까요, 컨테이너일까요? `from-hub` 컨테이너 안에서 바꾼 파일은 다른 사람에게 전달될까요?

## 실습 10. 볼륨 — 컨테이너를 지워도 남는 데이터

**목표**: 파일을 저장하는 앱으로 "컨테이너를 지우면 안의 파일도 사라진다"는 것을 직접 보고, 이름 있는 볼륨으로 데이터를 남깁니다. (교안 07장)

**① files 앱 빌드와 실행** — `files`는 이름과 내용을 받아 `/app/files/이름.txt`로 저장하는 앱입니다. Dockerfile은 폴더에 들어 있습니다.

```bash
cd ~/ktcloud-cloud-native-lab/lab/docker/files
docker build -t files .
docker run -d --name files -p 8003:3000 files
curl -d "name=memo&text=hello volume" localhost:8003/save   # Found. Redirecting to /
curl localhost:8003/files/memo.txt                           # hello volume
docker exec files ls /app/files                              # memo.txt
```
- `curl -d "이름=값&…"` = 웹 페이지의 입력 폼에 값을 넣어 보내는 것과 같습니다. 브라우저로 보려면 VS Code의 **PORTS** 탭에서 8003을 전달해 `http://localhost:8003`을 엽니다

**② 컨테이너를 지우고 다시 만들기**

```bash
docker rm -f files
docker run -d --name files -p 8003:3000 files
curl localhost:8003/files/memo.txt                           # Where is your file?
```
저장한 파일은 **그 컨테이너 안에만** 있었습니다. 같은 이미지로 새로 만든 컨테이너는 빈 상태로 시작합니다.

**③ 이름 있는 볼륨 붙이기** — `-v 볼륨이름:컨테이너경로`

```bash
docker rm -f files
docker run -d --name files -p 8003:3000 -v files-data:/app/files files
curl -d "name=memo&text=hello volume" localhost:8003/save
docker rm -f files
docker run -d --name files -p 8003:3000 -v files-data:/app/files files
curl localhost:8003/files/memo.txt                           # hello volume ← 남아 있음
```
```bash
docker volume ls                                             # local  files-data
docker volume inspect files-data
```
```
"Mountpoint": "/var/lib/docker/volumes/files-data/_data",
"Name": "files-data",
```
볼륨은 컨테이너 밖, Docker가 관리하는 VM 폴더(`/var/lib/docker/volumes/…`)에 있습니다. 컨테이너를 지워도 볼륨은 남고, 다음 컨테이너에 다시 붙일 수 있습니다.

**끝났는지 확인**: 볼륨을 붙인 채 컨테이너를 지우고 다시 만든 뒤에도 `curl localhost:8003/files/memo.txt`에 `hello volume`이 나오면 끝입니다.

### 확인 문제
1. `files` 컨테이너를 지운 뒤(`docker rm -f files`) `docker volume ls`에 `files-data`가 남아 있는지 확인하세요.
2. `files-data` 볼륨을 쓰는 컨테이너가 실행 중일 때 `docker volume rm files-data`를 하면 어떤 오류가 나나요? 컨테이너를 지운 뒤 다시 지워 보세요.

## 실습 11. 바인드 마운트 — 내 폴더를 컨테이너에 연결

**목표**: VM의 폴더를 컨테이너에 연결해, 파일을 고치면 이미지를 다시 빌드하지 않아도 바로 반영되는 것을 확인합니다. (교안 07장)

**① 웹 페이지 폴더 연결** — `-v VM경로:컨테이너경로` (VM 경로는 `/` 또는 `~`로 시작하는 전체 경로)

```bash
mkdir -p ~/site
echo "<h1>my site v1</h1>" > ~/site/index.html
docker run -d --name mysite -p 8004:80 -v ~/site:/usr/share/nginx/html nginx:1.29-alpine
curl localhost:8004                    # <h1>my site v1</h1>
nano ~/site/index.html                 # v1 → v2 로 고쳐 저장
curl localhost:8004                    # <h1>my site v2</h1> ← 바로 반영
```
```bash
docker inspect -f '{{range .Mounts}}{{.Type}} {{.Source}} -> {{.Destination}}{{end}}' mysite
# bind /home/lab/site -> /usr/share/nginx/html
```
nginx 이미지 안의 `/usr/share/nginx/html` 자리에 VM의 `~/site` 폴더가 그대로 보입니다. 개발 중에 코드를 고칠 때마다 빌드하지 않고 바로 확인할 때 씁니다.

**② 앱이 저장한 파일을 VM에서 보기** — 실습 10의 files 앱에 VM 폴더를 연결합니다.

```bash
mkdir -p ~/files-data
docker run -d --name files2 -p 8013:3000 -v ~/files-data:/app/files files
curl -d "name=note&text=from container" localhost:8013/save
ls -l ~/files-data                     # -rw-r--r-- 1 root root 14 … note.txt
cat ~/files-data/note.txt              # from container
docker rm -f files2
```
- 컨테이너가 만든 파일이 VM 폴더에 바로 생깁니다. 컨테이너 안의 앱이 root로 실행돼 파일 주인이 `root`입니다(VM에서 고치려면 `sudo`)

| | 이름 있는 볼륨 (실습 10) | 바인드 마운트 (실습 11) |
|---|---|---|
| 쓰는 법 | `-v files-data:/app/files` | `-v ~/site:/usr/share/nginx/html` |
| 어디에 | Docker가 관리하는 폴더 | 내가 정한 VM 폴더 |
| 주로 | DB 데이터처럼 남겨야 하는 것 | 개발 중인 코드·설정 파일 |

**끝났는지 확인**: `~/site/index.html`을 고친 뒤 `curl localhost:8004`에 바뀐 내용이 바로 나오면 끝입니다.

### 확인 문제
1. `~/site`에 `about.html`(내용 `<p>about</p>`)을 새로 만들고 `curl localhost:8004/about.html`로 확인하세요. 컨테이너를 다시 만들어야 하나요?

## 실습 12. 네트워크 — API와 DB 연결

**목표**: 할 일 앱의 API 컨테이너와 DB(PostgreSQL) 컨테이너를 따로 띄워 연결합니다. 기본 상태에서는 서로 이름을 못 찾는 것을 보고, 사용자 네트워크를 만들어 컨테이너 이름으로 연결합니다. (교안 08장)

**① API 이미지 빌드**

```bash
cd ~/ktcloud-cloud-native-lab/lab/docker/todo/api
docker build -t todo-api .
```
API는 환경변수 `DB_HOST`(DB 주소), `DB_USER`, `DB_PASSWORD`, `DB_NAME`을 읽어 DB에 접속합니다(01장의 "설정은 환경변수로"). DB가 준비될 때까지 2초 간격으로 15번 다시 시도합니다.

**② 그냥 띄우면 — 이름을 못 찾음**

```bash
docker run -d --name db -e POSTGRES_USER=todo -e POSTGRES_PASSWORD=todo-pass -e POSTGRES_DB=todo postgres:17-alpine
docker run -d --name api -p 8005:3000 -e DB_HOST=db -e DB_USER=todo -e DB_PASSWORD=todo-pass -e DB_NAME=todo todo-api
docker logs api
```
```
waiting for database at db (1/15): getaddrinfo ENOTFOUND db
waiting for database at db (2/15): getaddrinfo ENOTFOUND db
```
```bash
docker exec api ping -c 1 db
# ping: bad address 'db'
```
`ENOTFOUND db` = `db`라는 이름을 찾지 못함. 기본 네트워크에서는 컨테이너 이름으로 서로를 찾을 수 없습니다.

**③ 네트워크를 만들어 같이 넣기**

```bash
docker rm -f db api
docker network create todo-net
docker run -d --name db --network todo-net -e POSTGRES_USER=todo -e POSTGRES_PASSWORD=todo-pass -e POSTGRES_DB=todo postgres:17-alpine
docker run -d --name api --network todo-net -p 8005:3000 -e DB_HOST=db -e DB_USER=todo -e DB_PASSWORD=todo-pass -e DB_NAME=todo todo-api
docker logs api
```
```
waiting for database at db (1/15): connect ECONNREFUSED 172.19.0.2:5432
connected to database at db
todo api listening on port 3000
```
- 첫 줄: 이름은 찾았지만(`db` → `172.19.0.2`) DB가 아직 준비 중이라 한 번 다시 시도한 것. IP는 VM마다 다를 수 있습니다
- `docker exec api ping -c 1 db` → `1 packets transmitted, 1 packets received`

**④ API로 할 일 넣고 보기**

```bash
curl localhost:8005/api/todos                                   # []
curl -X POST -H 'Content-Type: application/json' -d '{"title":"buy milk"}' localhost:8005/api/todos
# {"id":1,"title":"buy milk"}
curl localhost:8005/api/todos                                   # [{"id":1,"title":"buy milk"}]
docker ps --format 'table {{.Names}}\t{{.Ports}}'
```
```
NAMES     PORTS
api       0.0.0.0:8005->3000/tcp, [::]:8005->3000/tcp
db        5432/tcp
```
`db`에는 `-p`가 없습니다. VM 밖에서는 DB에 들어올 수 없고, 같은 네트워크의 `api`만 `db:5432`로 접속합니다. **컨테이너끼리는 `-p` 없이 이름과 컨테이너 포트로 통신**합니다.

**끝났는지 확인**: `docker logs api`에 `connected to database at db`가 있고 `curl localhost:8005/api/todos`에 넣은 할 일이 보이면 끝입니다.

### 확인 문제
1. `todo-net`에 붙인 임시 컨테이너에서 `api`를 이름으로 불러 보세요: `docker run --rm --network todo-net nginx:1.29-alpine wget -qO- api:3000/api/todos`. `--network todo-net`을 빼고 실행하면 어떤 오류가 나오나요?
2. 확인이 끝나면 `docker rm -f db api`, `docker network rm todo-net`으로 정리하세요. (실습 13에서 Compose로 같은 구성을 다시 띄웁니다)

## 실습 13. Compose로 할 일 앱(3티어) 띄우기

**목표**: 화면(web) · API(api) · DB(db) 세 컨테이너를 `compose.yaml` 파일 하나에 적고, 명령 한 줄로 띄우고 내립니다. (교안 09장)

```bash
cd ~/ktcloud-cloud-native-lab/lab/docker/todo
ls                        # api  web
```
| 폴더·이미지 | 역할 |
|---|---|
| `web/` (nginx) | 화면(HTML·JS)을 주고, `/api/`로 오는 요청은 `api:3000`으로 넘김 |
| `api/` (Node) | 실습 12의 API |
| `postgres:17-alpine` | DB. 빌드 없이 공식 이미지 사용 |

**① compose.yaml 쓰기** — `nano compose.yaml`로 한 줄씩 입력합니다. **들여쓰기는 스페이스 2칸**(탭 금지)입니다.

```yaml
services:
  db:
    image: postgres:17-alpine
    environment:
      POSTGRES_USER: todo
      POSTGRES_PASSWORD: todo-pass
      POSTGRES_DB: todo
    volumes:
      - db-data:/var/lib/postgresql/data

  api:
    build: ./api
    environment:
      DB_HOST: db
      DB_USER: todo
      DB_PASSWORD: todo-pass
      DB_NAME: todo
    depends_on:
      - db

  web:
    build: ./web
    ports:
      - "8088:80"
    depends_on:
      - api

volumes:
  db-data:
```

| 키 | 뜻 | 실습 12의 명령에서 |
|---|---|---|
| `services:` 아래 `db`·`api`·`web` | 컨테이너 하나씩. **이름이 곧 주소** | `--name db` |
| `image:` / `build:` | 받아서 쓸 이미지 / 이 폴더의 Dockerfile로 빌드 | `postgres:17-alpine` / `docker build` |
| `environment:` | 환경변수 | `-e` |
| `ports:` | VM 포트:컨테이너 포트 | `-p` |
| `volumes:` | 볼륨:컨테이너 경로 (맨 아래 `volumes:`에 이름 선언) | `-v` |
| `depends_on:` | 먼저 시작할 서비스 | (순서대로 run) |

네트워크는 적지 않아도 됩니다. Compose가 이 파일의 서비스를 한 네트워크(`todo_default`)에 자동으로 넣습니다.

**② 띄우기**

```bash
docker compose config -q && echo OK       # 문법 검사. 오류가 있으면 줄 번호를 알려 줌
docker compose up -d --build
docker compose ps
```
```
NAME         IMAGE                SERVICE   STATUS          PORTS
todo-api-1   todo-api             api       Up …            3000/tcp
todo-db-1    postgres:17-alpine   db        Up …            5432/tcp
todo-web-1   todo-web             web       Up …            0.0.0.0:8088->80/tcp, [::]:8088->80/tcp
```
(COMMAND·CREATED 열은 줄여서 적음)
```bash
curl localhost:8088 | head -5                          # 화면 HTML (<title>todo</title>)
curl localhost:8088/api/todos                          # []  ← web(nginx)이 api로 넘겨 준 응답
curl -X POST -H 'Content-Type: application/json' -d '{"title":"learn compose"}' localhost:8088/api/todos
docker compose logs api
```
브라우저로 보려면 VS Code **PORTS** 탭에서 8088을 전달해 `http://localhost:8088`을 열고 할 일을 추가·삭제해 봅니다.

**③ 내리고 다시 올리기**

```bash
docker compose down        # 컨테이너·네트워크 삭제, 볼륨은 남음
docker compose up -d
curl localhost:8088/api/todos     # [{"id":1,"title":"learn compose"}] ← 남아 있음
docker compose down -v     # 볼륨까지 삭제
docker compose up -d
curl localhost:8088/api/todos     # [] ← 비어 있음
docker compose down -v
```
- 실습 12에서 명령 여섯 줄(`network create`, `run` 두 번, 긴 `-e` 옵션들)로 하던 일을 파일 하나와 `up` 한 줄로 합니다

**끝났는지 확인**: `docker compose ps`에 서비스 3개가 `Up`이고, `curl localhost:8088/api/todos`로 넣은 할 일이 `down` → `up` 뒤에도 남아 있으면 끝입니다.

### 확인 문제
1. `docker compose up -d` 상태에서 `docker ps`와 `docker network ls`, `docker volume ls`를 보세요. 컨테이너·네트워크·볼륨 이름은 어떤 규칙으로 붙었나요?
2. `compose.yaml`에서 web의 포트를 `"8089:80"`으로 바꾸고 `docker compose up -d`를 다시 실행하세요. 세 서비스 가운데 어느 것이 다시 만들어지나요? `curl localhost:8089`로 확인한 뒤 8088로 되돌립니다.

## 자주 쓴 명령
- 기초: `hostname -I` `getent hosts` `ss -tln` `curl` (`-I` `-d`) `python3 -m http.server` · `|` `grep` `>` `>>` `export` `echo $?` · `nano` (Ctrl+O · Ctrl+X), vi 나가기 `:q!` · `git clone` `npm install` `node app.js`
- 컨테이너: `run` (`-d` `--name` `-p` `-e` `-v` `--rm` `-it` `--network`) `ps` (`-a`) `stop` `start` `logs` (`--tail` `-f`) `exec` (`-it`) `cp` `inspect` (`-f`) `rm` (`-f`) `container prune`
- 이미지: `build` (`-t`) `image ls` `history` `tag` `rmi` `login` `push` `pull`
- 볼륨·네트워크·Compose: `volume ls/inspect/rm` `network create/ls/rm` `compose config/up -d --build/ps/logs/down (-v)`
