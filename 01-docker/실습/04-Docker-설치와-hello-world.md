[← 실습 3](./03-Docker-없이-Node-앱-직접-실행.md) · [목차](../Docker-실습.md) · [실습 5 →](./05-nginx-웹-서버-띄우기.md)

# 실습 4. Docker 설치와 hello-world

**무엇을 하나요**: VM에 Docker를 설치하고, `sudo` 없이 `docker` 명령을 쓸 수 있게 한 뒤 첫 컨테이너를 실행합니다. 이후 모든 실습의 준비입니다. (교안 04장)

**필요한 것**: 서버 VM 터미널 하나. 중간에 **서버에 다시 접속**하는 단계가 있습니다.

> **바로 가기** · [1. Docker 설치](#1단계-docker-설치) · [2. sudo 없이 쓰도록 docker 그룹에 추가](#2단계-sudo-없이-쓰도록-docker-그룹에-추가) · [3. 다시 접속하기](#3단계-다시-접속하기) · [4. 설치 확인](#4단계-설치-확인) · [5. 첫 컨테이너](#5단계-첫-컨테이너) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. Docker 설치

Docker 공식 저장소로 설치합니다. `apt install docker.io`(우분투 패키지)는 버전이 낮아 쓰지 않습니다. 아래 블록을 **통째로 복사해 한 번에** 붙여 넣습니다. 중간에 비밀번호를 물으면 VM 계정 비밀번호를 입력합니다(화면에 안 보임).

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

**이 명령은** — 외울 필요 없습니다. 무슨 일을 하는지만 봅니다.

| 단계 | 하는 일 |
|---|---|
| 1~2줄 | 패키지 목록을 새로 받고, 다운로드에 필요한 도구 설치 |
| 3~5줄 | Docker 저장소의 서명 키(GPG 키)를 받아 둠 — 받은 패키지가 진짜 Docker가 만든 것인지 확인하는 데 씀 |
| 6~8줄 | Docker 저장소 주소를 apt에 등록 — 우분투 기본 저장소보다 최신 버전을 받기 위함. 줄 끝의 `\`는 "다음 줄에 이어짐" 표시. `$VERSION_CODENAME`은 실습 2에서 본 `noble` |
| 9~10줄 | 목록을 다시 받고 Docker 엔진·CLI·Compose 설치 |

**이렇게 나오면 성공**: 글자가 많이 지나간 뒤 프롬프트가 다시 나오고, 마지막 부분에 `E:`로 시작하는 줄이 없으면 성공입니다. 1~3분 걸립니다.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 마지막 줄 `sudo apt-get install -y docker-ce …`가 실행되지 않고 남아 있음 | 붙여넣기 마지막 줄에 Enter가 안 들어감 | Enter를 한 번 누름 |
| `E: Unable to locate package docker-ce` | 6~8줄(저장소 등록)이 제대로 안 들어감 | 블록 전체를 다시 붙여 넣음 |
| 오래 막혀 진행이 안 됨 | — | 강사에게 알립니다 |

</details>

## 2단계. sudo 없이 쓰도록 docker 그룹에 추가

```bash
sudo usermod -aG docker $USER
```

**이 명령은**: 내 계정(`$USER` = `lab`)을 `docker` 그룹(같은 권한을 받는 사용자 묶음)에 추가. `-aG` = 기존 그룹은 그대로 두고(append) 그룹(Group)을 더함

**이렇게 나오면 성공**: 아무것도 출력되지 않습니다.

## 3단계. 다시 접속하기

그룹 변경은 **새로 로그인할 때부터** 적용됩니다. 한 번 나갔다가 다시 들어옵니다.

```bash
exit            # 로그아웃 후 ssh ktc-sNN 으로 다시 접속
```

| 접속 방법 | 다시 접속하는 법 |
|---|---|
| VS Code | ① 터미널에서 `exit`(터미널이 닫힘) ② 왼쪽 아래 파란 `SSH: ktc-sNN`을 누름 → 위에 뜬 목록에서 **Close Remote Connection** ③ 왼쪽 아래 `><` → **Connect to Host…** → `ktc-sNN` → 비밀번호 ④ **Terminal → New Terminal** |
| 노트북 터미널에서 `ssh` | `exit` → 내 노트북 프롬프트로 돌아오면 `ssh ktc-sNN` |

## 4단계. 설치 확인

다시 접속한 터미널에서 실행합니다.

```bash
docker --version
docker compose version
docker ps
```

**이 명령은**
- `docker --version` · `docker compose version` = 설치된 Docker·Compose 버전
- `docker ps` = 지금 실행 중인 컨테이너 목록(ps = process status). 아직 없으니 제목 줄만 나옴

**이렇게 나오면 성공** — 화면 예

```
Docker version 29.8.1, build 4a63305
Docker Compose version v5.5.1
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

기대 출력: `Docker version 29.x`, `Docker Compose version v5.x`, `docker ps`는 제목 줄(`CONTAINER ID   IMAGE ...`)만 나옴. 버전 숫자는 조금 달라도 됩니다.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `permission denied while trying to connect to the docker API at unix:///var/run/docker.sock` | 다시 접속하지 않았거나, 그룹 변경이 아직 적용되지 않음 | `groups`를 쳐서 끝에 `docker`가 있는지 확인. 없으면 3단계를 다시 |
| 3단계를 했는데도 위 오류가 계속됨(VS Code) | VS Code가 서버 쪽 프로그램을 예전 상태로 계속 쓰는 경우 | **F1**(macOS는 Cmd+Shift+P) → `Remote-SSH: Kill VS Code Server on Host` 입력·선택 → `ktc-sNN` → 다시 연결(3단계 ③) |
| `docker: command not found` | 1단계 설치가 끝나지 않음 | 1단계 블록을 다시 붙여 넣음 |

</details>

`groups` 화면 예: 다시 접속 전 `lab adm cdrom sudo dip lxd` → 다시 접속 후 `lab adm cdrom sudo dip lxd docker`

> ⚠️ 자주 막히는 곳: 다시 접속하지 않고 `docker ps` → `permission denied ... docker.sock`. 그룹 변경은 새 로그인부터 적용됩니다.

## 5단계. 첫 컨테이너

```bash
docker run --rm hello-world
```

**이 명령은**
- `docker run` = 이미지로 컨테이너를 만들어 실행. 이미지가 VM에 없으면 먼저 Docker Hub(이미지 창고)에서 받아 옵니다(pull)
- `--rm` = 실행이 끝나면 컨테이너를 자동으로 지움(remove)
- `hello-world` = 인사 글만 출력하고 끝나는 연습용 이미지

**이렇게 나오면 성공**: 처음 실행하면 맨 위에 `Unable to find image 'hello-world:latest' locally`(VM에 이미지가 없음)와 `Pull complete`(받기 완료)가 먼저 나오고, 이어서 아래 글이 나옵니다.

```
Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (amd64)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.
```

- `Hello from Docker!` = Docker가 잘 설치되어 동작함
- 출력 가운데 적힌 4단계(클라이언트 → 데몬 → 이미지 pull → 컨테이너 생성)가 04장 슬라이드의 `docker run` 3단계(내 VM에 이미지가 있나 → 없으면 Docker Hub에서 받기 → 실행)와 같은 이야기입니다
  - 1: `docker` 명령(클라이언트)이 Docker 엔진(데몬, 뒤에서 계속 도는 프로그램)에 연락함
  - 2: 데몬이 Docker Hub에서 `hello-world` 이미지를 받음
  - 3: 그 이미지로 새 컨테이너를 만들어 실행함
  - 4: 컨테이너의 출력을 내 터미널로 보내 줌

## 끝났는지 확인
- ☐ 다시 접속한 뒤 `sudo` 없이 `docker ps`가 오류 없이 제목 줄을 보여 준다
- ☐ `docker run --rm hello-world`에 `Hello from Docker!`가 보인다

## 정리
- 지울 것은 없습니다(`--rm`이라 컨테이너는 이미 지워졌습니다)

## 확인 문제
1. `groups` 명령으로 내 계정이 `docker` 그룹에 들어 있는지 확인하고, `docker version` 출력에서 Client 버전과 Server(엔진) 버전을 각각 찾으세요.
2. `hello-world`를 이번에는 `--rm` 없이 이름 `hw`(`--name hw`)로 실행하세요. 그다음 `docker ps -a`(멈춘 컨테이너까지 모두 보기)로 `hw`가 남아 있는지 확인하세요. **`hw`는 지우지 말고 둡니다**(실습 6에서 씁니다).
