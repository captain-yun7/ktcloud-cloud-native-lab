[← 실습 6](./06-컨테이너-다루기.md) · [목차](../Docker-실습.md) · [실습 8 →](./08-빌드-캐시와-COPY-순서.md)

# 실습 7. 첫 Dockerfile

**무엇을 하나요**: 실습 3에서 손으로 실행한 `hello` 앱을 **이미지**로 만들고(빌드), 컨테이너로 실행합니다. `-p` 없이 실행하면 왜 접속이 안 되는지 보고 고칩니다. 코드를 고치면 이미지를 다시 빌드해야 한다는 것도 확인합니다. (교안 05장)

**필요한 것**: 실습 3에서 받은 `~/ktcloud-cloud-native-lab/lab/docker/hello` 폴더. `app.js`의 문구가 `hello, docker`여야 합니다(실습 3 확인 문제에서 되돌렸는지 확인).

> **바로 가기** · [1. Dockerfile 쓰기](#1단계-dockerfile-쓰기) · [2. 빌드](#2단계-빌드) · [3. `-p` 없이 실행 → 접속 안 됨](#3단계--p-없이-실행--접속-안-됨) · [4. `-p`로 연결](#4단계--p로-연결) · [5. 코드를 고치면 다시 빌드](#5단계-코드를-고치면-다시-빌드) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. Dockerfile 쓰기

실습 3의 `hello` 폴더에서 nano로 `Dockerfile`을 만듭니다. 파일 이름은 정확히 `Dockerfile` — **D는 대문자, 확장자 없음**(`.txt` 붙이지 않음).

```bash
cd ~/ktcloud-cloud-native-lab/lab/docker/hello
nano Dockerfile
```

nano가 열리면 아래 6줄을 복사해 붙여 넣고(Windows Ctrl+V 또는 Ctrl+Shift+V, macOS Cmd+V) **Ctrl+O → Enter**(저장) → **Ctrl+X**(나가기).

```dockerfile
FROM node:22-alpine
WORKDIR /app
COPY . ./
RUN npm install
EXPOSE 3000
CMD ["node", "app.js"]
```

**이 파일은** — 실습 3에서 손으로 한 일을 순서대로 적은 것입니다.

| 줄 | 뜻 | 실습 3에서 직접 한 일 |
|---|---|---|
| `FROM node:22-alpine` | Node.js 22가 들어 있는 이미지에서 시작 | `apt-get install nodejs npm` |
| `WORKDIR /app` | 이미지 안의 작업 폴더를 `/app`으로 (없으면 만듦) | `cd …/hello` |
| `COPY . ./` | 지금 폴더(`.`)의 파일을 이미지의 `/app`(`./`)으로 복사 | `git clone` |
| `RUN npm install` | **이미지를 만들 때** 실행 → 결과(`node_modules`)가 이미지에 들어감 | `npm install` |
| `EXPOSE 3000` | 이 앱이 3000번을 쓴다는 **메모**. 포트를 열지는 않음 | — |
| `CMD ["node", "app.js"]` | **컨테이너를 시작할 때** 실행할 명령 | `node app.js` |

- 폴더에 있는 `.dockerignore` 파일이 `node_modules`를 복사 대상에서 뺍니다(실습 3에서 VM에 받은 것 대신 이미지 안에서 새로 받음). 이름이 `.`으로 시작하는 파일은 `ls`에 안 보이고 `ls -a`로 보입니다

저장이 잘 됐는지 확인합니다.

```bash
ls
cat Dockerfile
```

**이렇게 나오면 성공**: `ls`에 `Dockerfile`이 보이고, `cat Dockerfile`에 위 6줄이 그대로 나옵니다.

## 2단계. 빌드

`.`은 "지금 폴더의 Dockerfile과 파일로"라는 뜻입니다. **맨 끝의 점(`.`)을 빠뜨리지 마세요.**

```bash
docker build -t hello:v1 .
```

**이 명령은**
- `docker build` = Dockerfile대로 이미지를 만듦
- `-t hello:v1` = 이름 `hello`, 태그 `v1`을 붙임(t = tag). 처음 빌드하면 `node:22-alpine`을 받느라 조금 더 걸립니다
- `.` = 지금 폴더를 재료로 씀

**이렇게 나오면 성공** — 화면 예. 마지막 즈음 `naming to docker.io/library/hello:v1`(이미지에 이름 붙임)이 보이면 성공입니다.

```
[+] Building 2.0s (9/9) FINISHED
 => [1/4] FROM docker.io/library/node:22-alpine@sha256:…
 => [2/4] WORKDIR /app
 => [3/4] COPY . ./
 => [4/4] RUN npm install
 => exporting to image
 => => naming to docker.io/library/hello:v1
```

- `[1/4]`~`[4/4]` = Dockerfile의 줄을 하나씩 실행한 것(FROM이 1, RUN npm install이 4). `FINISHED` = 끝남

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `ERROR: docker: 'docker buildx build' requires 1 argument` | 맨 끝의 `.`을 빠뜨림 | `docker build -t hello:v1 .` (점 포함) |
| `failed to read dockerfile: open Dockerfile: no such file or directory` | 지금 폴더에 `Dockerfile`이 없음(다른 폴더에 있거나, 이름이 `dockerfile`·`Dockerfile.txt`) | `pwd`로 `…/lab/docker/hello`인지, `ls`로 이름이 정확히 `Dockerfile`인지 확인 |
| `ERROR` 줄에 `dockerfile parse error` 등 | Dockerfile 내용 오타 | `nano Dockerfile`로 열어 1단계와 비교 |

</details>

## 3단계. `-p` 없이 실행 → 접속 안 됨

일부러 포트 연결 없이 실행해 봅니다.

```bash
docker run -d --name hello hello:v1
docker ps
```
화면 예(열 일부만):
```
NAMES     IMAGE      STATUS                  PORTS
hello     hello:v1   Up Less than a second   3000/tcp
```
```bash
curl localhost:3000
# curl: (7) Failed to connect to localhost port 3000 after 0 ms: Couldn't connect to server
```

컨테이너는 `Up`(실행 중)인데 접속이 안 됩니다. 앱은 **컨테이너 안의** 3000번에서 기다리고 있지만, VM의 3000번과는 연결돼 있지 않습니다. `PORTS`의 `3000/tcp`는 EXPOSE 메모일 뿐입니다.

## 4단계. `-p`로 연결

```bash
docker rm -f hello
docker run -d --name hello -p 8000:3000 hello:v1
docker ps                   # PORTS: 0.0.0.0:8000->3000/tcp
curl localhost:8000         # hello, docker
```

**이 명령은**
- `docker rm -f hello` = 3단계의 컨테이너를 지움(같은 이름을 다시 쓰기 위해)
- `-p 8000:3000` = **VM의 8000**으로 온 요청을 **컨테이너의 3000**으로. 왼쪽이 VM, 오른쪽이 컨테이너입니다

**이렇게 나오면 성공**: `docker ps`의 PORTS에 `0.0.0.0:8000->3000/tcp`, `curl localhost:8000`에 `hello, docker`.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `Conflict. The container name "/hello" is already in use` | 3단계의 `hello`를 안 지움 | `docker rm -f hello` 후 다시 |
| `failed to bind host port 0.0.0.0:8000/tcp: address already in use` | 실습 1의 파이썬 웹 서버 등 Docker 밖의 프로그램이 VM 8000번을 쓰는 중 | 그 터미널에서 Ctrl+C. 실패한 컨테이너가 남으므로 `docker rm -f hello` 후 다시 |

</details>

## 5단계. 코드를 고치면 다시 빌드

먼저 `app.js`를 고칩니다.

```bash
nano app.js                 # 'hello, docker' → 'hello, 본인이름' 으로 고쳐 저장
```

- 화살표로 `res.send('hello, docker\n');` 줄로 가서 `docker`만 본인 이름으로 바꿉니다(예: `hello, 홍길동`). 따옴표·`\n`은 그대로 둡니다
- **Ctrl+O → Enter**(저장) → **Ctrl+X**(나가기)

그다음 아래를 실행합니다.

```bash
curl localhost:8000         # hello, docker  ← 그대로
docker build -t hello:v2 .
docker run -d --name hello2 -p 8001:3000 hello:v2
curl localhost:8001         # hello, 본인이름
curl localhost:8000         # hello, docker  ← v1은 그대로
docker image ls hello
```

**이 명령은**
- 첫 `curl` = 파일만 고치고 아직 빌드 안 함 → 실행 중인 컨테이너는 그대로
- `docker build -t hello:v2 .` = 고친 코드로 새 이미지 `hello:v2`
- `docker run … -p 8001:3000 hello:v2` = v2를 다른 이름(`hello2`)·다른 VM 포트(8001)로 실행
- `docker image ls hello` = `hello` 이름의 이미지 목록

**이렇게 나오면 성공**: 8000은 `hello, docker`, 8001은 `hello, 본인이름`. 이미지 목록 화면 예:

```
IMAGE      ID             DISK USAGE   CONTENT SIZE   EXTRA
hello:v1   ddc229905116        249MB         62.7MB   U
hello:v2   3c54718e611e        249MB         62.7MB   U
```

(`EXTRA`의 `U` = 지금 컨테이너가 쓰는(Used) 이미지)

- 컨테이너는 빌드할 때의 파일로 만들어진 이미지로 실행됩니다. 폴더의 `app.js`를 고쳐도 실행 중인 컨테이너는 바뀌지 않습니다
- v1과 v2가 **동시에** 실행됩니다. VM에 Node.js를 설치하지 않았어도(실습 3의 Node.js 18과 상관없이) 이미지 안의 Node.js 22로 돌아갑니다

## 끝났는지 확인
- ☐ `curl localhost:8000`에 `hello, docker`가 나온다
- ☐ `curl localhost:8001`에 `hello, 본인이름`이 나온다
- ☐ `docker image ls hello`에 `v1`, `v2` 두 줄이 있다

## 정리
- `hello`·`hello2` 컨테이너는 **실습 9까지 켜 둡니다**. 지우지 마세요
- `Dockerfile`과 고친 `app.js`는 실습 8에서 그대로 씁니다

## 확인 문제
1. `docker history hello:v2`로 이미지의 층을 보세요. 우리가 Dockerfile에 적은 줄 가운데 크기(SIZE)가 가장 큰 줄은 어느 것인가요? 왜 그럴까요?
2. `hello:v1` 이미지로 이름 `hello3`, VM 포트 8010인 컨테이너를 하나 더 실행해 `curl`로 확인하세요. 어떤 문구가 나오나요? 확인한 뒤 `hello3`는 지웁니다.
