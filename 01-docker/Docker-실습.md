# Docker — 실습

이 문서는 Docker 과목의 실습 1~13입니다. 처음 해 보는 분도 혼자 끝까지 따라올 수 있게 한 단계씩 적었습니다. 길어 보여도 한 단계는 짧습니다. 위에서부터 순서대로 하면 됩니다.

- 교안에 **실습 안내** 슬라이드가 나오면 이 문서의 해당 실습을 처음부터 끝까지 스스로 진행합니다. 막히면 Discord에 질문합니다([질문하는 법](#9-막히면--질문하는-법)).
- 실습 앱은 학생 저장소의 `lab/docker/` 폴더에 있습니다(실습 3에서 받습니다). `hello`(인사말 한 줄), `files`(글을 파일로 저장), `todo`(할 일 목록 — 화면·API·DB 3개) 세 가지를 씁니다.

**실습 하나는 이렇게 생겼습니다**

| 부분 | 내용 |
|---|---|
| **무엇을 하나요** | 이 실습에서 할 일과 왜 하는지 |
| **필요한 것** | 앞 실습에서 만들어 둔 것 |
| **1단계, 2단계 …** | 명령 → **이 명령은**(쉬운 풀이) → **이렇게 나오면 성공**(화면 예) → **이렇게 나오면?**(자주 나는 오류와 해결) |
| **끝났는지 확인** | ☐ 체크리스트. 모두 ☑이면 끝 |
| **정리** | 다음 실습에 방해되지 않게 지울 것, 지우면 안 되는 것 |
| **확인 문제** | 방금 한 명령을 조금 바꿔 보는 문제. 필요한 명령은 모두 그 실습까지 나왔습니다 |

---

## 시작하기 전에

실습 1을 시작하기 전에 한 번 읽어 주세요. 실습 중에 막히면 여기로 돌아와 다시 봅니다.

### 1. 서버에 접속하기

여러분은 각자 **실습 서버(VM, 가상 머신)** 를 한 대씩 씁니다. 이 문서의 모든 명령은 그 서버에서 실행합니다.

- 접속 명령: `ssh ktc-sNN` — `NN`은 본인 번호 두 자리입니다. 7번이면 `ssh ktc-s07`
- 비밀번호는 VM 비밀번호입니다. 입력해도 화면에 보이지 않는 것이 정상입니다
- `~/.ssh/config` 파일에 아래 네 줄이 있어야 `ssh ktc-sNN`이 됩니다

```
Host ktc-sNN
  HostName 3.39.33.142
  User lab
  Port 220NN
```

- `NN`은 두 곳입니다. 7번이면 `Host ktc-s07`, `Port 22007`
- 설정 파일 없이 한 줄로 접속할 수도 있습니다: `ssh -p 220NN lab@3.39.33.142`
- **예전 방식(브라우저 이메일 인증)으로 설정한 분**: `~/.ssh/config`의 `ktc-sNN` 항목을 위 네 줄로 바꿉니다(`HostName` 줄 고치기, `ProxyCommand` 줄 지우기, `Port` 줄 추가)
- 접속할 때 **브라우저가 열리며 이메일을 물으면** 예전 설정이 남아 있는 것입니다. 위 네 줄로 바꿉니다
- 자세한 절차와 오류 대처는 [접속 안내](../00-접속-안내.md)에 있습니다

### 2. VS Code가 서버에 붙어 있는지 확인

VS Code로 서버에 연결해 두면 파일 보기·편집·터미널을 한 창에서 쓸 수 있습니다. 연결 방법은 [접속 안내 4절](../00-접속-안내.md#4-vs-code에서-쓰기-권장)에 있습니다.

연결된 상태인지 두 가지로 확인합니다.

| 어디를 보나 | 이렇게 보이면 연결됨 |
|---|---|
| VS Code 창 **왼쪽 아래** | 파란 칸에 `SSH: ktc-sNN` |
| 터미널(메뉴 **Terminal → New Terminal**)의 맨 앞 글자(프롬프트) | `lab@sNN:~$` |

- 프롬프트의 `~`는 지금 있는 폴더입니다. `~`는 내 홈 폴더(`/home/lab`)라는 뜻입니다. 폴더를 옮기면 `lab@sNN:~/basics$`처럼 바뀝니다
- 왼쪽 아래에 `SSH: ktc-sNN`이 없으면 내 노트북의 터미널입니다. 아래 3을 보세요

### 3. 명령은 어디에 치나요

**이 문서의 명령은 전부 서버 VM의 터미널에 칩니다.** 내 노트북의 터미널(PowerShell, macOS 터미널)이 아닙니다.

| 구분 | 프롬프트 모양 | 이 문서의 명령을 쳐도 되나 |
|---|---|---|
| 서버 VM 터미널 | `lab@sNN:~$` | 됩니다 |
| 내 노트북 — Windows PowerShell | `PS C:\Users\이름>` | 안 됩니다 (`ssh ktc-sNN`만 여기서) |
| 내 노트북 — macOS 터미널 | `이름@MacBook ~ %` | 안 됩니다 (`ssh ktc-sNN`만 여기서) |

명령을 쳤는데 `docker`나 `nano`를 찾을 수 없다는 오류가 나오면, 먼저 프롬프트가 `lab@sNN`인지 봅니다.

### 4. 명령 복사해서 붙여 넣기

명령은 직접 타이핑하지 말고 복사해서 붙여 넣는 것이 안전합니다(오타가 가장 흔한 실수입니다).

1. 이 문서의 회색 코드 블록에 마우스를 올리면 **오른쪽 위에 복사 버튼**(겹친 네모 모양)이 나옵니다. 누르면 블록 전체가 복사됩니다
2. 서버 터미널을 한 번 클릭한 뒤 붙여 넣습니다

| 내 컴퓨터 | VS Code 터미널에 붙여넣기 |
|---|---|
| Windows | **Ctrl+V** 또는 **Ctrl+Shift+V**, 또는 마우스 오른쪽 버튼 |
| macOS | **Cmd+V** |

3. 마지막 줄이 실행되지 않고 남아 있으면 **Enter**를 한 번 더 누릅니다
4. "여러 줄을 붙여 넣겠느냐"는 확인 창이 뜨면 **Paste**(붙여넣기)를 누릅니다

알아 둘 것:

- `#` 뒤는 **설명(주석)** 입니다. 같이 붙여 넣어도 실행되지 않으니 괜찮습니다. 예: `node -v   # v18.19.1` → `node -v`만 실행되고, `# v18.19.1`은 "이렇게 나온다"는 설명입니다
- 다른 문서에서 명령 앞에 `$`가 붙어 있으면 그 `$`는 치지 않습니다(프롬프트 표시입니다). 이 문서의 명령 블록에는 `$`를 붙이지 않았습니다
- `<아이디>`처럼 꺾쇠로 감싼 부분은 **본인 값으로 바꿔서** 칩니다. 꺾쇠(`<` `>`)도 지웁니다. 예: `<아이디>/hello` → `kim123/hello`
- **화면 예** 블록(명령 바로 아래, 명령이 아닌 결과만 적힌 블록)은 붙여 넣는 것이 아닙니다. 내 화면과 비교만 합니다
- 터미널의 글자를 **복사**할 때는 드래그로 선택한 뒤 마우스 오른쪽 버튼(Windows) 또는 **Cmd+C**(macOS)를 씁니다. 터미널에서 선택 없이 **Ctrl+C**를 누르면 복사가 아니라 "실행 중인 프로그램 멈추기"입니다(6 참고)

### 5. 출력이 문서와 조금 달라도 되는 것

내 화면이 문서의 화면 예와 글자 하나까지 같을 필요는 없습니다. 아래는 사람마다·때마다 달라지는 값입니다.

| 달라도 되는 것 | 예 |
|---|---|
| 컨테이너 ID, 이미지 ID, `sha256:…` 같은 긴 글자 | `deebf9cc55bc`, `ddc229905116` |
| 시간·날짜 | `1 second ago`, `Up 3 minutes`, 로그의 날짜 |
| 걸린 시간, 크기 | `Building 2.0s`, `in 2s`, `249MB` |
| 내 VM 번호가 들어간 곳 | `10.10.1.N`, `lab@sNN` |
| 받는 중(Pull) 진행 줄의 개수와 순서 | `Pull complete`, `Pushed` 줄 |

**같아야 하는 것**은 문서에서 "이렇게 나오면 성공"으로 짚은 줄(예: `hello, docker`, `200 OK`, `Up`)입니다.

### 6. 명령이 끝나지 않고 멈춰 있을 때

웹 서버나 앱을 **화면 앞에서(포그라운드로)** 띄우면 명령이 끝나지 않고 멈춰 있습니다. **고장이 아니라 정상**입니다. 요청이 오기를 기다리는 중입니다.

- 이 문서에서 멈춰 있는 것이 정상인 명령: `python3 -m http.server …`(실습 1·2), `node app.js`(실습 3), `docker logs -f …`(실습 6)
- 끝내려면 그 터미널을 클릭하고 **Ctrl+C**를 누릅니다(macOS도 Cmd가 아니라 **Ctrl**+C). 프롬프트(`lab@sNN:…$`)가 다시 나오면 끝난 것입니다
- 멈춰 있는 동안 다른 명령을 치려면 **터미널을 하나 더** 엽니다(7 참고)
- 그 밖의 명령(설치, `docker build` 등)이 몇 분 넘게 움직이지 않으면 Ctrl+C로 멈추고 같은 명령을 다시 실행합니다. 그래도 같으면 질문합니다(9 참고)

### 7. 터미널 두 개 여는 법

실습 1·2·3은 터미널 두 개가 필요합니다(하나는 서버를 띄우고, 하나는 요청을 보냄).

1. VS Code 아래쪽 터미널 패널의 오른쪽 위에서 **`+`** 를 누릅니다
2. 새 터미널이 열립니다. 오른쪽 목록에 터미널이 두 개(`bash`, `bash`) 보이고, 눌러서 오갈 수 있습니다
3. 새 터미널도 서버 VM입니다(프롬프트 `lab@sNN:~$`). 따로 접속할 필요가 없습니다
4. 새 터미널은 홈 폴더(`~`)에서 시작합니다. 앞 터미널에서 `cd`로 들어간 폴더가 아닙니다

이 문서에서는 처음 연 터미널을 **터미널 1**, 새로 연 터미널을 **터미널 2**라고 부릅니다. VS Code를 쓰지 않는다면 내 노트북에서 터미널 창을 하나 더 열고 `ssh ktc-sNN`으로 한 번 더 접속하면 됩니다.

### 8. 브라우저로 서버의 웹 페이지 보기 (PORTS 탭)

서버 VM에서 띄운 웹 페이지를 내 노트북 브라우저로 보려면 VS Code의 **PORTS** 탭에서 포트를 이어 줍니다(포트 전달). 실습 10(8003), 실습 13(8088), 미션 2(8080)에서 씁니다.

1. 서버에서 앱을 먼저 띄웁니다(예: 실습 10의 files 앱 → VM 포트 8003)
2. VS Code 아래쪽 패널에서 **TERMINAL** 탭 옆의 **PORTS** 탭을 누릅니다
   - PORTS 탭이 안 보이면: 메뉴 **View → Open View…** → `Ports` 입력 → 선택
3. 파란 **Forward a Port** 버튼을 누릅니다(이미 줄이 있으면 목록 아래의 **Add Port**)
4. 칸에 포트 번호(예: `8003`)를 입력하고 **Enter**
5. 표에 줄이 생기고 **Forwarded Address** 칸에 `localhost:8003`이 보입니다
6. 그 주소에 마우스를 올리면 나오는 **지구 아이콘**(Open in Browser)을 누르거나, 브라우저 주소창에 `http://localhost:8003`을 직접 입력합니다

알아 둘 것:

- 앱을 띄우면 VS Code가 오른쪽 아래에 "포트를 쓸 수 있다"는 알림을 띄울 때가 있습니다. 그 알림의 **Open in Browser**를 눌러도 됩니다
- Forwarded Address가 내가 입력한 번호와 다를 때가 있습니다(노트북에서 그 번호를 이미 쓰는 경우). 그때는 **표에 적힌 주소**로 엽니다
- 다 봤으면 PORTS 탭의 줄에 마우스를 올려 **X**(Stop Forwarding)를 눌러 닫아도 됩니다

### 9. 막히면 — 질문하는 법

1. 에러가 나면 **첫 줄**부터 읽습니다. 이 문서의 해당 단계 **이렇게 나오면?** 표에 같은 문구가 있는지 찾아봅니다
2. 그래도 모르겠으면 Discord에 질문합니다. 에러는 **사진이 아니라 글자로**, 첫 줄부터 그대로 복사해 붙입니다
3. 아래 네 가지를 같이 적으면 빨리 답할 수 있습니다

```
[실습 7 - 4단계] (몇 번 실습, 몇 단계)
한 일: docker run -d --name hello -p 8000:3000 hello:v1 을 실행
기대: curl localhost:8000 에 hello, docker
실제: (에러 첫 줄부터 그대로 붙여넣기)
해 본 것: docker ps 로 보니 hello 가 없음
```

- 질문할 때 비밀번호, 토큰(Docker Hub 액세스 토큰 등)은 지우고 올립니다

---

## 이 문서에 나오는 말

처음 보는 말은 여기서 찾아봅니다. 실습 본문에서도 처음 나올 때 괄호로 풀어 둡니다.

| 말 | 쉬운 뜻 |
|---|---|
| VM (가상 머신) | 큰 서버 안에 만든 나만의 리눅스 컴퓨터. 이 문서의 "VM"은 내 실습 서버 |
| 터미널 · 프롬프트 | 글자로 명령을 치는 창 · 명령을 기다리는 맨 앞 표시(`lab@sNN:~$`) |
| 폴더 경로 | 파일이 있는 위치. `~` = 내 홈 폴더(`/home/lab`), `.` = 지금 폴더 |
| IP 주소 | 네트워크에서 컴퓨터를 찾는 주소. 예: `10.10.1.7` |
| 포트 | 한 컴퓨터 안에서 프로그램을 구분하는 번호. 건물 주소(IP) 안의 호수(포트) |
| DNS | 이름(`github.com`)을 IP 주소로 바꿔 주는 전화번호부 |
| HTTP 상태 코드 | 요청 결과를 숫자로 알려 줌. 200 성공, 404 없는 주소, 500 서버 오류 |
| 환경변수 | `이름=값`으로 프로그램에 넘겨주는 설정. 예: `PORT=3001` |
| 이미지 | 앱과 앱을 실행하는 데 필요한 것(Node.js, 라이브러리 등)을 한데 묶은 꾸러미. 실행하지 않은 상태 |
| 컨테이너 | 이미지를 실행한 것. 이미지 하나로 컨테이너를 여러 개 띄울 수 있음 |
| 태그 | 이미지 이름 뒤의 버전 표시. `nginx:1.29-alpine`의 `1.29-alpine`, `hello:v1`의 `v1` |
| Dockerfile | 이미지를 만드는 순서를 적은 파일 |
| 빌드 | Dockerfile대로 이미지를 만드는 것(`docker build`) |
| 레지스트리 | 이미지를 올려 두고 받아 가는 창고. Docker Hub가 대표 |
| 볼륨 | 컨테이너를 지워도 남는 저장 공간 |
| 바인드 마운트 | VM의 폴더를 컨테이너 안에 그대로 연결하는 것 |
| 네트워크 (Docker) | 컨테이너끼리 이름으로 서로 찾을 수 있게 묶어 둔 것 |
| Compose | 여러 컨테이너를 파일 하나(`compose.yaml`)에 적어 한 번에 띄우고 내리는 도구 |

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

**무엇을 하나요**: 내 VM의 주소(IP), 이름을 주소로 바꾸는 일(DNS), 프로그램의 문 번호(포트), 요청 결과 번호(HTTP 상태 코드)를 명령으로 직접 봅니다. 뒤에서 컨테이너에 접속할 때 이 네 가지를 계속 씁니다. (교안 01장)

**필요한 것**: 서버 VM 터미널. 가운데에서 터미널을 하나 더 엽니다([시작하기 전에 7](#7-터미널-두-개-여는-법)).

### 1단계. 실습용 폴더와 파일 만들기

명령의 자세한 뜻은 실습 2에서 봅니다. 지금은 그대로 붙여 넣으세요.

```bash
mkdir -p ~/basics && cd ~/basics
echo "<h1>hello basics</h1>" > index.html
```

**이 명령은**
- `mkdir -p ~/basics` = 홈 폴더(`~`) 안에 `basics` 폴더를 만듦. `-p` = 이미 있어도 오류를 내지 않음
- `&&` = 앞 명령이 성공하면 이어서 뒤 명령을 실행
- `cd ~/basics` = 그 폴더 안으로 들어감(cd = change directory, 폴더 바꾸기)
- `echo "…" > index.html` = 따옴표 안의 글자를 `index.html` 파일로 저장

**이렇게 나오면 성공**: 아무것도 출력되지 않습니다. 프롬프트가 `lab@sNN:~/basics$`로 바뀌었으면 폴더 안에 들어온 것입니다. 리눅스 명령은 성공하면 조용한 경우가 많습니다.

### 2단계. 내 VM의 IP와 DNS 보기

```bash
hostname -I                 # 내 VM의 IP 주소 → 10.10.1.N
getent hosts github.com     # DNS에 이름을 물어 IP를 받음
# 20.200.245.247  github.com   (IP는 때와 장소에 따라 다를 수 있음)
```

**이 명령은**
- `hostname -I` = 이 VM의 IP 주소(네트워크에서 이 컴퓨터를 찾는 주소)를 보여 줌. `-I`는 대문자 i
- `getent hosts github.com` = DNS(이름 → IP 전화번호부)에 `github.com`의 IP를 물어봄

**이렇게 나오면 성공**
- `hostname -I` → `10.10.1.`로 시작하는 주소 하나(끝 숫자는 본인 VM 번호). Docker를 설치한 뒤에는 `172.17.0.1` 같은 주소가 더 붙습니다
- `getent hosts github.com` → 숫자 주소와 `github.com`이 한 줄. 숫자는 문서와 달라도 됩니다

### 3단계. 웹 서버 띄우기 — 터미널 1

파이썬에 들어 있는 간단한 웹 서버를 8000번 포트로 띄웁니다. 지금 폴더(`~/basics`)의 파일을 돌려줍니다.

```bash
cd ~/basics
python3 -m http.server 8000
# Serving HTTP on 0.0.0.0 port 8000 (http://0.0.0.0:8000/) ...
```

**이 명령은**
- `python3 -m http.server 8000` = 파이썬의 웹 서버 기능을 8000번 포트로 켬

**이렇게 나오면 성공**: `Serving HTTP on 0.0.0.0 port 8000 …` 한 줄이 나오고 **멈춰 있습니다**("8000번에서 서비스 중"이라는 뜻). 요청을 기다리는 중이라 정상입니다([시작하기 전에 6](#6-명령이-끝나지-않고-멈춰-있을-때)).

**이렇게 나오면?**

| 화면 | 원인 | 해결 |
|---|---|---|
| `OSError: [Errno 98] Address already in use` | 8000번을 다른 프로그램이 이미 쓰는 중(앞에서 띄운 웹 서버가 다른 터미널에 켜져 있음) | 다른 터미널들을 둘러보고 켜 둔 웹 서버를 Ctrl+C로 끈 뒤 다시 실행 |

이 터미널(터미널 1)은 그대로 둡니다.

### 4단계. 터미널 하나 더 열기

VS Code 터미널 패널 오른쪽 위의 **`+`** 를 눌러 **터미널 2**를 엽니다. 자세한 방법은 [시작하기 전에 7](#7-터미널-두-개-여는-법). 4~6단계는 터미널 2에서 합니다.

> 가장 흔한 실수: 웹 서버가 떠 있는 터미널 1에 명령을 치는 것. 터미널 1은 웹 서버가 쓰고 있어서 쳐도 아무 일도 일어나지 않습니다.

### 5단계. 기다리는 포트 보기 — 터미널 2

```bash
ss -tln
```

**이 명령은**: 이 VM에서 요청을 기다리고 있는(LISTEN) 포트 목록을 보여 줌

**이렇게 나오면 성공** — 화면 예(줄 순서·개수는 VM마다 다름). `Local Address:Port` 열의 콜론(`:`) 뒤 숫자가 포트입니다. **`:8000` 줄이 있으면 성공**입니다.

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

### 6단계. 요청 보내고 상태 코드 보기 — 터미널 2

```bash
curl localhost:8000              # 본문: <h1>hello basics</h1>
curl -I localhost:8000           # 머리(헤더)만: HTTP/1.0 200 OK
curl -I localhost:8000/nothing   # 없는 주소: HTTP/1.0 404 File not found
curl -I 127.0.0.1:8000           # localhost = 127.0.0.1 → 200 OK
curl -I https://github.com       # 인터넷의 서버 → HTTP/2 200
```

**이 명령은**
- `curl 주소` = 그 주소로 요청을 보내고 받은 응답을 보여 줌(글자로 보는 브라우저)
- `localhost` = 지금 이 컴퓨터 자신. `127.0.0.1`과 같습니다
- `:8000` = 8000번 포트(문 번호)로 보냄
- `-I` = 응답의 머리(헤더, 응답에 대한 정보)만 보여 줌. 첫 줄의 숫자가 **상태 코드**

**이렇게 나오면 성공**: 각 줄의 `#` 뒤에 적은 결과가 나오면 됩니다. `-I`를 붙인 명령은 여러 줄이 나오는데 **첫 줄**만 보면 됩니다.

| 첫 줄 | 뜻 |
|---|---|
| `HTTP/1.0 200 OK` | 성공. 요청한 것을 찾아서 돌려줌 |
| `HTTP/1.0 404 File not found` | 그런 파일(주소)이 없음 |
| `HTTP/2 200` | 성공(github.com은 더 새로운 HTTP/2를 씀) |

상태 코드: 200 성공, 404 없는 주소, 500 서버 오류.

**이렇게 나오면?**

| 화면 | 원인 | 해결 |
|---|---|---|
| `curl: (7) Failed to connect …` | 8000번에서 기다리는 프로그램이 없음 | 터미널 1의 웹 서버가 켜져 있는지 확인. 꺼졌으면 3단계부터 다시 |
| 명령을 쳤는데 아무 반응이 없음 | 웹 서버가 떠 있는 터미널 1에 친 것 | 터미널 2를 눌러 거기서 다시 |

### 7단계. 터미널 1에서 요청 기록 보고 끄기

터미널 1을 눌러 봅니다. 방금 보낸 요청이 한 줄씩 찍혀 있습니다(`-I`는 `HEAD`, 그냥 `curl`은 `GET`으로 찍힘).

```
127.0.0.1 - - [28/Sep/2026 15:13:51] "GET / HTTP/1.1" 200 -
127.0.0.1 - - [28/Sep/2026 15:13:51] "HEAD /nothing HTTP/1.1" 404 -
```

- 한 줄 = 요청 하나. "누가(127.0.0.1) 언제 무엇을(`GET /`) 요청했고 결과는 몇 번(200)이었다"
- 이런 기록을 **로그**라고 합니다. Docker에서도 `docker logs`로 같은 기록을 봅니다

다 봤으면 터미널 1에서 **Ctrl+C**로 웹 서버를 끕니다. 프롬프트(`lab@sNN:~/basics$`)가 다시 나오면 꺼진 것입니다.

### 끝났는지 확인
- ☐ `curl -I localhost:8000`에 `200 OK`가 나왔다
- ☐ `curl -I localhost:8000/nothing`에 `404`가 나왔다
- ☐ 터미널 1에 요청 줄(`"GET / HTTP/1.1" 200`)이 찍혔다
- ☐ 웹 서버를 Ctrl+C로 껐다

### 정리
- 웹 서버는 Ctrl+C로 끄면 끝입니다
- `~/basics` 폴더는 실습 2에서 씁니다. **지우지 마세요**
- 터미널 2는 닫지 않고 계속 써도 됩니다

### 확인 문제
1. 웹 서버를 끈 상태에서 `curl localhost:8000`을 하면 어떤 오류가 나오나요? 이때 `ss -tln`에 8000 줄이 있나요?
2. 웹 서버를 이번에는 포트 8001로 띄우고(`python3 -m http.server 8001`), 다른 터미널에서 `curl -I localhost:8001/index.html`의 상태 코드를 확인하세요. 같은 때 `curl -I localhost:8000`은 어떻게 되나요? 확인이 끝나면 Ctrl+C로 끕니다.

## 실습 2. 셸 조합과 nano

**무엇을 하나요**: 명령을 이어 붙이고(`|`), 결과를 파일로 보내고(`>`, `>>`), 환경변수와 종료 코드를 확인합니다. 터미널 안에서 편집기 nano로 파일을 고칩니다. Docker 실습 내내 쓰는 기본기입니다. (교안 02장)

**필요한 것**: 실습 1에서 만든 `~/basics` 폴더. (셸 = 지금 명령을 받아 실행하는 프로그램. 터미널 안에서 돌아갑니다)

### 1단계. 파이프와 리다이렉트

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

**이 명령은**

| 부분 | 뜻 |
|---|---|
| `cat 파일` | 파일 내용을 화면에 보여 줌 |
| `/etc/os-release` | 이 VM의 운영체제 정보가 적힌 파일 |
| `\|` (파이프, Shift+역슬래시 키) | 앞 명령의 출력을 뒤 명령의 입력으로 넘김 |
| `grep 글자` | 그 글자가 든 줄만 골라 보여 줌 |
| `echo "글자"` | 글자를 출력 |
| `> 파일` | 출력을 화면 대신 파일에 씀. **있던 내용은 지워짐** |
| `>> 파일` | 출력을 파일 **끝에 이어** 씀 |

**이렇게 나오면 성공**
- `grep CODENAME` → `VERSION_CODENAME=noble`, `UBUNTU_CODENAME=noble` 두 줄
- 첫 `cat note.txt` → `first`, `second` 두 줄
- 마지막 `cat note.txt` → `new` 한 줄(`>`가 앞 내용을 지웠기 때문)

`noble`은 우분투 24.04의 코드명입니다. 실습 4의 Docker 설치 명령이 이 값을 꺼내 씁니다.

### 2단계. 환경변수와 종료 코드

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

**이 명령은**

| 부분 | 뜻 |
|---|---|
| `$HOME` | 환경변수 `HOME`의 값. 내 홈 폴더 |
| `export 이름=값` | 환경변수를 만듦. `=` 앞뒤에 **띄어쓰기 없이** |
| `$이름` | 그 환경변수의 값을 꺼냄 |
| `env` | 지금 있는 환경변수를 모두 보여 줌. `grep`으로 하나만 골라 봄 |
| `ls 파일` | 파일이 있는지 보여 줌. `nothing.txt`는 일부러 없는 파일 |
| `echo $?` | 바로 앞 명령의 **종료 코드**. 0이면 성공, 0이 아니면 실패 |

**이렇게 나오면 성공**: 각 줄의 `#` 뒤와 같으면 됩니다. `ls nothing.txt`의 오류(`No such file or directory` = 그런 파일이나 폴더가 없음)는 **일부러 낸 것**이니 괜찮습니다.

- 환경변수 = 이름=값으로 둔 설정. 실습 3에서 `PORT=3001 node app.js`로 앱의 포트를 바꾸고, 실습 6부터는 `docker run -e`로 컨테이너에 넣습니다
- `docker ps -a`의 `Exited (0)` 괄호 안 숫자도 종료 코드입니다

### 3단계. 터미널 편집기 nano

터미널 안에서 파일을 고치는 편집기입니다. 마우스 대신 **화살표 키**로 움직입니다.

```bash
nano memo.txt                # 없는 파일이면 새로 만듦
```

화면 맨 아래 두 줄이 단축키 안내입니다. `^`는 **Ctrl** 키입니다(`^O` = Ctrl+O). macOS도 Cmd가 아니라 **Ctrl**입니다.

1. 두 줄을 입력합니다: `hello nano`, `second line` (줄 바꿈은 Enter)
2. **Ctrl+O**(저장) → 맨 아래에 `File Name to Write: memo.txt`가 나오면 **Enter** → `[ Wrote 2 lines ]`(2줄 저장함)
3. **Ctrl+X**로 나옵니다
4. `cat memo.txt`로 두 줄을 확인합니다

| 할 일 | 키 |
|---|---|
| 저장 | Ctrl+O → Enter |
| 종료 | Ctrl+X (저장 안 했으면 아래에 `Save modified buffer?`(고친 내용 저장할까요?)가 나옴 → Y → Enter, 저장하지 않으려면 N) |
| 붙여넣기 | VS Code 터미널 붙여넣기와 같음(Windows Ctrl+V 또는 Ctrl+Shift+V, macOS Cmd+V) |
| 찾기 · 줄 잘라내기 · 붙이기 | Ctrl+W · Ctrl+K · Ctrl+U |

**이렇게 나오면?**

| 상황 | 해결 |
|---|---|
| 저장했는데 `cat`에 아무것도 없음 | Ctrl+O 뒤에 **Enter**를 안 누른 것. nano로 다시 열어 Ctrl+O → Enter |
| 화면 아래에 `File Name to Write`가 떠 있는 채로 멈춤 | Enter를 누르면 저장됩니다 |
| 실수로 엉뚱한 키를 눌러 화면이 이상함 | Ctrl+X → 저장할지 물으면 N → 다시 `nano memo.txt` |

**vi가 열렸을 때 빠져나오기** — `git commit`처럼 편집기를 여는 명령이 nano 대신 vi(vim)를 열 때가 있습니다. vi는 nano와 조작이 전혀 다릅니다. `vi memo.txt`로 한 번 들어갔다가 **Esc** → `:q!` → **Enter**로 나와 봅니다(저장하지 않고 나감. 저장하고 나가려면 `:wq`).

### 끝났는지 확인
- ☐ `cat note.txt`에 `new` 한 줄이 보인다
- ☐ `ls nothing.txt` 바로 뒤 `echo $?`에 `2`가 나왔다
- ☐ `cat memo.txt`에 nano로 쓴 두 줄이 보인다
- ☐ vi에서 `:q!`로 빠져나왔다

### 정리
- 지울 것은 없습니다. `~/basics` 폴더와 파일은 확인 문제에서 씁니다

### 확인 문제
1. `>>`로 `note.txt`에 `apple`, `banana` 두 줄을 이어 붙인 뒤 `cat note.txt | grep an`을 실행하세요. 무엇이 나오나요? 바로 뒤 `echo $?`의 값은?
2. nano로 `~/basics/index.html`을 열어 내용을 `<h1>edited by nano</h1>`로 바꿔 저장하세요. 실습 1처럼 웹 서버(`python3 -m http.server 8000`)를 띄우고 다른 터미널에서 `curl localhost:8000`으로 바뀐 내용을 확인한 뒤, 웹 서버를 Ctrl+C로 끕니다.

## 실습 3. Docker 없이 Node 앱 직접 실행

**무엇을 하나요**: 실습 앱을 내 VM으로 받고, VM에 Node.js를 직접 설치해 `hello` 앱을 실행합니다. "앱 하나를 돌리려면 무엇을 준비해야 하는지"를 손으로 겪어 보는 실습입니다. 03장에서 이 경험을 컨테이너와 비교하고, 실습 7에서 같은 일을 Dockerfile로 합니다. (교안 02장)

**필요한 것**: 서버 VM 터미널. 3·4단계에서 터미널 두 개를 씁니다.

(Node.js = 자바스크립트로 만든 앱을 실행하는 프로그램. npm = Node.js용 라이브러리를 받아 주는 도구. 라이브러리 = 남이 만들어 둔 코드 묶음)

### 1단계. 실습 저장소 받기

`git clone` = GitHub의 저장소(파일 묶음)를 내 VM으로 복사합니다. **반드시 홈 폴더(`~`)에서** 받습니다. 뒤의 모든 실습이 `~/ktcloud-cloud-native-lab` 위치를 씁니다.

```bash
cd ~
git clone https://github.com/captain-yun7/ktcloud-cloud-native-lab.git
cd ~/ktcloud-cloud-native-lab/lab/docker/hello
ls
# app.js  package-lock.json  package.json
```

**이 명령은**

| 줄 | 뜻 |
|---|---|
| `cd ~` | 홈 폴더(`/home/lab`)로 이동. 어디에 있었든 여기서 시작 |
| `git clone 주소` | 그 주소의 저장소를 지금 폴더 안에 `ktcloud-cloud-native-lab` 폴더로 받음 |
| `cd ~/ktcloud-cloud-native-lab/lab/docker/hello` | 받은 폴더 안의 `lab` → `docker` → `hello` 폴더로 들어감 |
| `ls` | 지금 폴더의 파일 목록 |

**이렇게 나오면 성공**
- `git clone` → 첫 줄 `Cloning into 'ktcloud-cloud-native-lab'...`(받는 중) 뒤에 받는 진행 줄이 나오고 끝납니다
- 프롬프트가 `lab@sNN:~/ktcloud-cloud-native-lab/lab/docker/hello$`로 바뀝니다
- `ls` → `app.js  package-lock.json  package.json` 세 파일

| 파일 | 내용 |
|---|---|
| `app.js` | 앱 코드. 3000번 포트로 요청을 기다리다가 `/`로 오면 `hello, docker`를 돌려줌 |
| `package.json` | 이 앱에 필요한 라이브러리 목록(`express` — Node.js로 웹 서버를 만드는 도구) |
| `package-lock.json` | 라이브러리의 정확한 버전을 적어 둔 파일 |

**이렇게 나오면?**

| 화면 | 원인 | 해결 |
|---|---|---|
| `fatal: destination path 'ktcloud-cloud-native-lab' already exists and is not an empty directory.` | 이미 받아 둔 폴더가 있음(전에 한 번 받았음) | 다시 받을 필요 없습니다. 그대로 `cd ~/ktcloud-cloud-native-lab/lab/docker/hello`부터 이어 갑니다. 최신 내용으로 맞추려면 아래 `git pull` |
| `bash: cd: …: No such file or directory` | 폴더 이름 오타, 또는 홈 폴더가 아닌 곳에서 clone함 | `cd ~` 후 `ls` → `ktcloud-cloud-native-lab`이 보이는지 확인. 안 보이면 `cd ~`에서 clone을 다시 |
| `ls`에 파일이 다르게 나옴 | 다른 폴더에 있음 | `pwd`(지금 위치 보기)로 확인 → `/home/lab/ktcloud-cloud-native-lab/lab/docker/hello`여야 함 |

이미 받아 둔 저장소를 최신으로 맞추기:

```bash
cd ~/ktcloud-cloud-native-lab
git pull
# Already up to date.
```

- `git pull` = GitHub의 바뀐 내용을 받아 옴. `Already up to date.` = 이미 최신이라 받을 것이 없음

### 2단계. Node.js 설치

앱을 실행할 프로그램(Node.js)과 라이브러리 설치 도구(npm)를 VM에 설치합니다.

```bash
sudo apt-get update
sudo apt-get install -y --no-install-recommends nodejs npm
node -v                      # v18.19.1
npm -v                       # 9.2.0
```

**이 명령은**

| 부분 | 뜻 |
|---|---|
| `sudo` | 이 명령 하나만 관리자 권한으로 실행. 비밀번호를 물으면 VM 비밀번호 입력(화면에 안 보임) |
| `apt-get update` | 설치할 수 있는 프로그램 목록을 새로 받음 |
| `apt-get install 이름…` | 프로그램 설치 |
| `-y` | "설치할까요?"에 자동으로 yes |
| `--no-install-recommends` | 꼭 필요한 것만 설치(권장 패키지 빼기) |
| `node -v` · `npm -v` | 설치된 버전 보기 |

**이렇게 나오면 성공**: 설치 중에는 글자가 많이 지나갑니다. 끝난 뒤 `node -v`에 `v18.19.1`, `npm -v`에 `9.2.0`이 나오면 성공입니다. 설치는 1분 안팎 걸립니다.

- 우분투 24.04 저장소의 Node.js는 **18** 버전입니다. 실습 6에서 컨테이너 안의 Node.js 버전과 비교합니다
- `--no-install-recommends`를 빼면 권장 패키지까지 수백 개를 받아 몇 분이 더 걸립니다(깨끗한 우분투 24.04에서 약 45초 → 4분 30초)

**이렇게 나오면?**

| 화면 | 원인 | 해결 |
|---|---|---|
| `E:`로 시작하는 줄 | 설치 실패 | 1~2분 뒤 두 명령(`update`, `install`)을 다시 실행. 그래도 같으면 `E:` 줄을 복사해 질문 |
| `node: command not found` | 설치가 끝나지 않음 | 위 `install` 명령을 다시 실행하고 마지막에 오류가 없는지 확인 |

### 3단계. 라이브러리 받고 실행 — 터미널 1

`hello` 폴더 안에서 실행합니다(프롬프트가 `…/lab/docker/hello$`인지 확인).

```bash
npm install
# added 68 packages, and audited 69 packages in 2s
# ...
node app.js
# hello app listening on port 3000
```

**이 명령은**
- `npm install` = `package.json`에 적힌 라이브러리를 받아 `node_modules` 폴더에 넣음
- `node app.js` = Node.js로 `app.js`를 실행

**이렇게 나오면 성공**
- `npm install` → `added 68 packages …`(라이브러리 68개 추가함). 그 아래 `found 0 vulnerabilities` 같은 줄이 더 나와도 괜찮습니다
- `node app.js` → `hello app listening on port 3000`(3000번 포트에서 기다리는 중)이 나오고 **멈춰 있음** = 정상(실습 1의 파이썬 웹 서버와 같습니다)

**이렇게 나오면?**

| 화면 | 원인 | 해결 |
|---|---|---|
| `npm ERR! enoent ENOENT: no such file or directory, open '…/package.json'` | `hello` 폴더가 아닌 곳에서 실행 | `cd ~/ktcloud-cloud-native-lab/lab/docker/hello` 후 다시 |
| `Error: Cannot find module '…/app.js'` | `hello` 폴더가 아닌 곳에서 실행 | 위와 같음 |

### 4단계. 요청 보내기 — 터미널 2

터미널을 하나 더 엽니다([시작하기 전에 7](#7-터미널-두-개-여는-법)). 새 터미널은 어느 폴더에서든 됩니다.

```bash
curl localhost:3000          # hello, docker
```

**이렇게 나오면 성공**: `hello, docker`. 앱이 보낸 응답입니다.

### 5단계. 앱 끄기

터미널 1을 눌러 **Ctrl+C**를 누릅니다. 그다음 터미널 2에서 다시 요청합니다.

```bash
curl localhost:3000
# curl: (7) Failed to connect to localhost port 3000 after 0 ms: Couldn't connect to server
```

**이렇게 나오면 성공**: `Failed to connect …`(3000번 포트에 연결하지 못함). 앱이 꺼졌으니 정상입니다.

앱은 터미널 1에서 실행한 프로그램이라, Ctrl+C를 누르거나 터미널 1을 닫으면 같이 꺼집니다.

**직접 해 본 순서 정리** — 05장에서 Dockerfile의 줄과 하나씩 맞춰 봅니다.

| 순서 | 한 일 | 명령 |
|---|---|---|
| 1 | 실행 환경(Node.js) 설치 | `sudo apt-get install nodejs npm` |
| 2 | 앱 코드 가져오기 | `git clone …` → `cd …/hello` |
| 3 | 라이브러리 설치 | `npm install` |
| 4 | 실행 | `node app.js` |

### 끝났는지 확인
- ☐ `node -v`에 `v18.19.1`이 나온다
- ☐ `node app.js`를 띄운 동안 `curl localhost:3000`에 `hello, docker`가 나왔다
- ☐ Ctrl+C로 끈 뒤에는 `Failed to connect`가 나왔다

### 정리
- 앱은 Ctrl+C로 끄면 끝입니다
- 설치한 Node.js는 **지우지 말고 둡니다**. 실습 6에서 VM의 `node -v`와 컨테이너의 `node -v`를 비교합니다. (과목이 끝난 뒤 지우려면 `sudo apt-get remove -y nodejs npm && sudo apt-get autoremove -y`)
- `~/ktcloud-cloud-native-lab` 폴더는 이 과목 내내 씁니다. **지우지 마세요**

### 확인 문제
1. 앱이 쓰는 포트는 환경변수 `PORT`로 바꿀 수 있습니다. 터미널 1에서 `PORT=3001 node app.js`로 실행하고, 터미널 2에서 `curl localhost:3001`과 `curl localhost:3000`의 결과를 각각 확인하세요.
2. 앱을 켜 둔 채 nano로 `app.js`의 `hello, docker`를 `hello, node`로 바꿔 저장하고 `curl localhost:3001`을 해 보세요. 바뀌었나요? 앱을 Ctrl+C로 끄고 다시 실행한 뒤에는 어떤가요? 확인이 끝나면 문구를 **`hello, docker`로 되돌리고** 앱을 끕니다(실습 7에서 이 폴더를 그대로 씁니다).

> nano 사용법(다시): `nano app.js`로 열기 → 화살표로 `hello, docker`가 있는 줄로 이동 → 고치기 → **Ctrl+O → Enter**(저장) → **Ctrl+X**(나가기). 앱이 켜진 터미널 1이 아니라 터미널 2에서 엽니다(터미널 2는 `cd ~/ktcloud-cloud-native-lab/lab/docker/hello` 먼저).

## 실습 4. Docker 설치와 hello-world

**무엇을 하나요**: VM에 Docker를 설치하고, `sudo` 없이 `docker` 명령을 쓸 수 있게 한 뒤 첫 컨테이너를 실행합니다. 이후 모든 실습의 준비입니다. (교안 04장)

**필요한 것**: 서버 VM 터미널 하나. 중간에 **서버에 다시 접속**하는 단계가 있습니다.

### 1단계. Docker 설치

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

**이렇게 나오면?**

| 화면 | 원인 | 해결 |
|---|---|---|
| 마지막 줄 `sudo apt-get install -y docker-ce …`가 실행되지 않고 남아 있음 | 붙여넣기 마지막 줄에 Enter가 안 들어감 | Enter를 한 번 누름 |
| `E: Unable to locate package docker-ce` | 6~8줄(저장소 등록)이 제대로 안 들어감 | 블록 전체를 다시 붙여 넣음 |
| 오래 막혀 진행이 안 됨 | — | 강사에게 알립니다 |

### 2단계. sudo 없이 쓰도록 docker 그룹에 추가

```bash
sudo usermod -aG docker $USER
```

**이 명령은**: 내 계정(`$USER` = `lab`)을 `docker` 그룹(같은 권한을 받는 사용자 묶음)에 추가. `-aG` = 기존 그룹은 그대로 두고(append) 그룹(Group)을 더함

**이렇게 나오면 성공**: 아무것도 출력되지 않습니다.

### 3단계. 다시 접속하기

그룹 변경은 **새로 로그인할 때부터** 적용됩니다. 한 번 나갔다가 다시 들어옵니다.

```bash
exit            # 로그아웃 후 ssh ktc-sNN 으로 다시 접속
```

| 접속 방법 | 다시 접속하는 법 |
|---|---|
| VS Code | ① 터미널에서 `exit`(터미널이 닫힘) ② 왼쪽 아래 파란 `SSH: ktc-sNN`을 누름 → 위에 뜬 목록에서 **Close Remote Connection** ③ 왼쪽 아래 `><` → **Connect to Host…** → `ktc-sNN` → 비밀번호 ④ **Terminal → New Terminal** |
| 노트북 터미널에서 `ssh` | `exit` → 내 노트북 프롬프트로 돌아오면 `ssh ktc-sNN` |

### 4단계. 설치 확인

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

**이렇게 나오면?**

| 화면 | 원인 | 해결 |
|---|---|---|
| `permission denied while trying to connect to the docker API at unix:///var/run/docker.sock` | 다시 접속하지 않았거나, 그룹 변경이 아직 적용되지 않음 | `groups`를 쳐서 끝에 `docker`가 있는지 확인. 없으면 3단계를 다시 |
| 3단계를 했는데도 위 오류가 계속됨(VS Code) | VS Code가 서버 쪽 프로그램을 예전 상태로 계속 쓰는 경우 | **F1**(macOS는 Cmd+Shift+P) → `Remote-SSH: Kill VS Code Server on Host` 입력·선택 → `ktc-sNN` → 다시 연결(3단계 ③) |
| `docker: command not found` | 1단계 설치가 끝나지 않음 | 1단계 블록을 다시 붙여 넣음 |

`groups` 화면 예: 다시 접속 전 `lab adm cdrom sudo dip lxd` → 다시 접속 후 `lab adm cdrom sudo dip lxd docker`

> ⚠️ 자주 막히는 곳: 다시 접속하지 않고 `docker ps` → `permission denied ... docker.sock`. 그룹 변경은 새 로그인부터 적용됩니다.

### 5단계. 첫 컨테이너

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

### 끝났는지 확인
- ☐ 다시 접속한 뒤 `sudo` 없이 `docker ps`가 오류 없이 제목 줄을 보여 준다
- ☐ `docker run --rm hello-world`에 `Hello from Docker!`가 보인다

### 정리
- 지울 것은 없습니다(`--rm`이라 컨테이너는 이미 지워졌습니다)

### 확인 문제
1. `groups` 명령으로 내 계정이 `docker` 그룹에 들어 있는지 확인하고, `docker version` 출력에서 Client 버전과 Server(엔진) 버전을 각각 찾으세요.
2. `hello-world`를 이번에는 `--rm` 없이 이름 `hw`(`--name hw`)로 실행하세요. 그다음 `docker ps -a`(멈춘 컨테이너까지 모두 보기)로 `hw`가 남아 있는지 확인하세요. **`hw`는 지우지 말고 둡니다**(실습 6에서 씁니다).

## 실습 5. nginx 웹 서버 띄우기

**무엇을 하나요**: 웹 서버 프로그램(nginx, "엔진엑스")을 컨테이너로 띄우고, VM 포트로 접속해 응답과 로그를 확인합니다. 설치 없이 이미지 이름 하나로 웹 서버가 뜨는 것을 봅니다. (교안 04장)

**필요한 것**: 실습 4에서 설치한 Docker.

### 1단계. nginx 컨테이너 띄우기

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

### 2단계. 실행 중인지 보기

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

### 3단계. 접속해 보기

```bash
curl localhost:8081          # Welcome to nginx!
```

**이렇게 나오면 성공**: HTML(웹 페이지 글) 여러 줄이 나오고, 그 안에 `<title>Welcome to nginx!</title>`과 `<h1>Welcome to nginx!</h1>`이 보입니다("nginx에 오신 것을 환영합니다" = 웹 서버가 잘 동작함).

### 4단계. 로그 보기

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

**이렇게 나오면?**

| 화면 | 원인 | 해결 |
|---|---|---|
| `Conflict. The container name "/web" is already in use …` | 1단계를 두 번 실행해 `web`이 이미 있음 | 이미 떠 있으니 2단계로 넘어가면 됩니다(`docker ps`로 확인) |
| `port is already allocated` | VM 8081번을 다른 컨테이너가 사용 중 | `docker ps`로 8081을 쓰는 컨테이너를 확인. 실습 6에서 자세히 다룹니다 |
| `curl: (7) Failed to connect …` | 컨테이너가 안 떠 있거나 포트 번호가 다름 | `docker ps`에서 `web`이 `Up`이고 PORTS가 `8081->80`인지 확인 |

`web`은 실습 6에서 계속 씁니다. **지우지 마세요.**

### 끝났는지 확인
- ☐ `docker ps`에 `web`이 `Up`으로 보인다
- ☐ `curl localhost:8081`에 `Welcome to nginx!`가 나온다
- ☐ `docker logs web` 끝에 `"GET / HTTP/1.1" 200` 줄이 있다

### 정리
- 지우지 않습니다. `web`은 실습 6에서 씁니다

### 확인 문제
1. `nginx:1.29-alpine`으로 이름 `site`, VM 포트 9090인 컨테이너를 백그라운드로 실행하고 `curl`로 확인하세요. (`site`는 실습 6 확인 문제에서 씁니다)

## 실습 6. 컨테이너 다루기

**무엇을 하나요**: 컨테이너 안의 환경이 VM과 따로 떨어져 있음을 확인하고, 컨테이너를 멈추고·다시 켜고·들여다보고·지우는 명령을 익힙니다. 자주 만나는 오류 3가지도 일부러 내서 고쳐 봅니다. (교안 04장)

**필요한 것**: 실습 3에서 VM에 설치한 Node.js, 실습 5의 `web`(실행 중), 실습 4 확인 문제의 `hw`(멈춘 컨테이너).

### 1단계. VM의 Node.js와 컨테이너의 Node.js

실습 3에서 VM에 Node.js 18을 설치했습니다.

```bash
node -v                                    # v18.19.1  ← VM에 설치한 것
docker run --rm node:22-alpine node -v     # v22.23.3  ← 컨테이너 안
```

**이 명령은**
- `docker run --rm node:22-alpine node -v` = Node.js 22가 든 이미지(`node:22-alpine`)로 컨테이너를 만들고, 그 **안에서** `node -v`를 실행한 뒤 지움
- 이미지 이름 뒤에 적은 명령(`node -v`)은 컨테이너 안에서 실행됩니다

**이렇게 나오면 성공**: VM은 `v18.19.1`, 컨테이너는 `v22.23.3`. (처음에는 이미지를 받는 줄이 먼저 나옵니다)

같은 VM에서 실행했는데 버전이 다릅니다. 컨테이너는 이미지에 들어 있는 Node.js를 쓰고, VM에 설치된 것과 섞이지 않습니다.

### 2단계. 컨테이너 안으로 들어가 보기

컨테이너 안으로 들어가 보면 운영체제도 다릅니다.

```bash
docker run -it --rm node:22-alpine sh
```

**이 명령은**
- `-it` = 키보드 입력과 터미널 화면을 연결(`-i` 입력, `-t` 터미널). 셸처럼 주고받는 프로그램을 실행할 때 붙입니다
- `sh` = 컨테이너 안에서 셸(명령을 받는 프로그램)을 실행

**이렇게 나오면 성공**: 프롬프트가 `/ #`로 바뀝니다. **여기서부터는 컨테이너 안**입니다. 아래 명령을 한 줄씩 입력합니다(`/ #`은 치지 않음).

```
/ # node -v
v22.23.3
/ # cat /etc/os-release | head -2
NAME="Alpine Linux"
ID=alpine
/ # exit
```

- `cat /etc/os-release | head -2` = 운영체제 정보의 앞 2줄. VM은 Ubuntu인데 컨테이너 안은 `Alpine Linux`
- `exit`로 나오면 프롬프트가 `lab@sNN:…$`로 돌아옵니다. `--rm` 때문에 컨테이너는 지워집니다

### 3단계. 같은 이미지로 컨테이너 하나 더

```bash
docker run -d --name web2 -p 8082:80 nginx:1.29-alpine
docker ps                   # web, web2 — 이미지는 같고 이름·포트가 다름
curl localhost:8082         # Welcome to nginx!
```

**이렇게 나오면 성공**: `docker ps`에 `web`(8081)과 `web2`(8082) 두 줄. 이미지 하나로 컨테이너를 여러 개 띄울 수 있습니다. 이름과 VM 포트만 겹치지 않으면 됩니다.

### 4단계. 멈추고, 다시 켜고, 로그 보기

```bash
docker stop web2
docker ps                   # web2가 안 보임
docker ps -a                # web2  Exited (0) ... — 멈췄을 뿐 남아 있음
docker start web2
curl localhost:8082         # 요청 두 번
curl localhost:8082
docker logs --tail 2 web2   # 마지막 2줄만
```

**이렇게 나오면 성공**
- `docker stop web2` → `web2`(이름이 그대로 한 줄 출력됨 = 처리함)
- `docker ps -a`에 `web2`가 `Exited (0)`(종료됨, 종료 코드 0)으로 보임 = 멈췄을 뿐 지워지지 않음
- `docker start web2` 뒤 `curl`이 다시 됨
- `docker logs --tail 2 web2` → `"GET / HTTP/1.1" 200` 요청 줄 두 개

실시간으로 로그 보기 — 이 명령은 **멈춰 있는 것이 정상**입니다.

```bash
docker logs -f web2         # 실시간 (Ctrl+C로 빠져나옴, 컨테이너는 계속 실행)
```

- 멈춰 있는 동안 다른 터미널에서 `curl localhost:8082`를 하면 새 줄이 바로 찍힙니다
- **Ctrl+C**로 빠져나옵니다. 로그 보기만 끝나고 컨테이너 `web2`는 계속 실행됩니다

| 명령 | 하는 일 |
|---|---|
| `docker ps` / `docker ps -a` | 실행 중인 것만 / 멈춘 것까지 모두 (a = all) |
| `docker stop` · `docker start` | 멈춤(컨테이너는 남음) · 다시 시작 |
| `docker logs --tail N` · `-f` | 마지막 N줄 · 실시간 (f = follow, 따라가며 보기) |

### 5단계. 실행 중인 컨테이너 안으로 들어가기

```bash
docker exec -it web sh
```

**이 명령은**: `exec` = **실행 중인** 컨테이너(`web`) 안에서 명령(`sh`)을 실행. 2단계의 `run`은 새 컨테이너를 만들지만, `exec`는 이미 떠 있는 컨테이너에 들어갑니다.

**이렇게 나오면 성공**: 프롬프트가 `/ #`로 바뀝니다. 아래를 한 줄씩 입력합니다.

```
/ # ls /usr/share/nginx/html
50x.html    index.html
/ # exit
```

- `/usr/share/nginx/html` = nginx가 돌려주는 웹 페이지 파일이 있는 폴더. 3단계에서 본 `Welcome to nginx!`가 `index.html`입니다
- `exit`로 나와도 `web`은 계속 실행됩니다

### 6단계. 파일 넣고 빼기

`docker cp 보낼곳 받을곳` — 컨테이너 쪽은 `이름:경로`로 적습니다.

```bash
mkdir -p ~/drill && cd ~/drill
echo "<h1>hello from cp</h1>" > hello.html
docker cp hello.html web:/usr/share/nginx/html/hello.html     # VM → 컨테이너
curl localhost:8081/hello.html                                # <h1>hello from cp</h1>
docker cp web:/etc/nginx/conf.d/default.conf .                # 컨테이너 → VM (. = 지금 폴더)
head -5 default.conf
```

**이 명령은**
- `docker cp hello.html web:/usr/share/nginx/html/hello.html` = VM의 `hello.html`을 컨테이너 `web`의 웹 페이지 폴더로 복사
- `docker cp web:/etc/nginx/conf.d/default.conf .` = 컨테이너 안의 nginx 설정 파일을 VM의 지금 폴더(`.`)로 복사
- `head -5 파일` = 파일의 앞 5줄만 보기

**이렇게 나오면 성공**
- `docker cp`마다 `Successfully copied …`(복사 성공) 줄이 나옵니다
- `curl localhost:8081/hello.html` → `<h1>hello from cp</h1>`
- `head -5 default.conf` → 화면 예

```
server {
    listen       80;
    listen  [::]:80;
    server_name  localhost;

```

(`listen 80` = nginx가 컨테이너 안의 80번에서 기다린다는 설정. 그래서 실습 5에서 `-p 8081:80`의 오른쪽이 80이었습니다)

### 7단계. 일부러 오류 내고 고치기

오류 문구를 한 번 봐 두면 나중에 바로 고칠 수 있습니다. 아래 명령은 **실패하는 것이 정상**입니다.

**① 같은 이름**

```bash
docker run -d --name web -p 8083:80 nginx:1.29-alpine     # 같은 이름
```
화면 예:
```
docker: Error response from daemon: Conflict. The container name "/web" is already in use by container "…". You have to remove (or rename) that container to be able to reuse that name.
```
뜻: "`web`이라는 이름은 이미 다른 컨테이너가 쓰고 있다. 그 이름을 다시 쓰려면 그 컨테이너를 지우거나 이름을 바꿔라."

**② 쓰는 중인 VM 포트**

```bash
docker run -d --name web3 -p 8081:80 nginx:1.29-alpine    # 쓰는 중인 VM 포트
```
화면 예:
```
docker: Error response from daemon: failed to set up container networking: driver failed programming external connectivity on endpoint web3 (…): Bind for 0.0.0.0:8081 failed: port is already allocated
```
뜻: "VM의 8081번은 이미 할당되어(다른 컨테이너 `web`이 쓰는 중) 연결할 수 없다."

실패했는데도 컨테이너는 만들어져 남습니다. 확인하고 지웁니다.

```bash
docker ps -a                # web3  Created — 실패해도 컨테이너는 만들어져 남음
docker rm web3
```
(`Created` = 만들어졌지만 시작하지 못함. `docker rm` = 컨테이너 지우기, 성공하면 이름 `web3`가 출력됨)

**③ 실행 중인 컨테이너 지우기**

```bash
docker rm web2              # 실행 중인 컨테이너 지우기
```
화면 예:
```
Error response from daemon: cannot remove container "web2": container is running: stop the container before removing or force remove
```
뜻: "`web2`는 실행 중이라 지울 수 없다. 먼저 멈추거나 강제로 지워라."

```bash
docker rm -f web2           # -f = 멈추고 지우기를 한 번에
```

| 오류 문구 | 원인 | 고치는 법 |
|---|---|---|
| `Conflict. The container name ... is already in use` | 같은 이름의 컨테이너가 이미 있음 (멈춘 것 포함) | 다른 이름, 또는 `docker rm` 후 다시 |
| `port is already allocated` | VM 포트를 다른 컨테이너가 사용 중 | 다른 VM 포트. 실패한 컨테이너는 `Created`로 남으니 `docker rm` |
| `container is running` | 실행 중인 컨테이너는 그냥 지울 수 없음 | `docker stop` 후 `rm`, 또는 `docker rm -f` |

### 8단계. 이미지 지우기는 컨테이너 먼저

실습 4 확인 문제의 `hw`(hello-world, 멈춤)가 남아 있습니다. (없으면 `docker run --name hw hello-world`로 만듭니다)

```bash
docker rmi hello-world
```
화면 예(실패가 정상):
```
Error response from daemon: conflict: unable to delete hello-world:latest (must be forced) - container … is using its referenced image …
```
뜻: "컨테이너(`hw`)가 이 이미지를 쓰고 있어서 지울 수 없다." (`rmi` = remove image, 이미지 지우기)

```bash
docker rm hw                # 컨테이너 먼저
docker rmi hello-world      # Untagged: hello-world:latest / Deleted: sha256:…
```

**이렇게 나오면 성공**: `Untagged: hello-world:latest`(이름표 뗌)와 `Deleted: sha256:…`(지움) 줄.

멈춘 컨테이너라도 남아 있으면 그 이미지는 지울 수 없습니다. 순서는 **컨테이너(`rm`) → 이미지(`rmi`)** 입니다.

### 9단계. 끝나면 자동 삭제, 환경변수 넣기

```bash
docker run --rm -e GREETING=hi nginx:1.29-alpine sh -c 'echo $GREETING'   # hi
docker ps -a                                     # 방금 컨테이너는 목록에 없음
```

**이 명령은**
- `-e 이름=값` = 컨테이너에 환경변수를 넣음(e = environment). 이미지 이름 뒤에 명령을 적으면 이미지의 기본 명령(nginx 실행) 대신 그 명령을 실행하고 끝냅니다
- `sh -c '…'` = 따옴표 안의 글을 셸 명령으로 실행
- **작은따옴표**(`'`)라야 `$GREETING`을 VM 셸이 아니라 컨테이너가 풉니다. 큰따옴표(`"`)를 쓰면 VM 셸이 먼저 바꿔 빈 줄이 나옵니다

**이렇게 나오면 성공**: `hi` 한 줄. 그리고 `docker ps -a`에 방금 컨테이너가 없음(`--rm`이 지움).

### 10단계. 멈춘 컨테이너 한꺼번에 정리

```bash
docker container prune      # y 입력 — 멈춘 컨테이너 전부 삭제. 실행 중인 web은 남음
```

화면 예 — 아래처럼 물으면 **`y`** 를 입력하고 Enter:
```
WARNING! This will remove all stopped containers.
Are you sure you want to continue? [y/N]
```
뜻: "경고! 멈춘 컨테이너를 모두 지웁니다. 계속할까요?" — `[y/N]`은 그냥 Enter를 누르면 N(아니오)이라는 뜻입니다.

**이렇게 나오면 성공**: `Deleted Containers:` 아래 지운 컨테이너 ID가 나오고 마지막에 `Total reclaimed space:`(되찾은 공간). 지울 것이 없으면 ID 없이 `Total reclaimed space: 0B`.

> ⚠️ **실행하지 말고 알아만 둘 명령**: `docker image prune -a`, `docker system prune -a`(쓰지 않는 이미지·빌드 캐시까지 전부 삭제). 다음 실습에서 이미지를 다시 받아야 합니다. 정리는 이름을 지정한 `rm` · `rmi`로 합니다.

### 끝났는지 확인
- ☐ `docker ps -a`에 `web`이 `Up`으로 있다
- ☐ `docker ps -a`에 `web2`·`web3`·`hw`는 없다 (`site`는 있어도 됩니다)
- ☐ `curl localhost:8081/hello.html`이 `<h1>hello from cp</h1>`를 보여 준다

### 정리
- `web`은 실행 중으로 둡니다. 다음 실습에 방해되지 않습니다(포트 8081은 이후 실습에서 쓰지 않음)
- `site`는 확인 문제 1에서 지웁니다
- `~/drill` 폴더는 지워도 되고 두어도 됩니다

### 확인 문제

> `site`가 없으면 먼저 띄우세요: `docker run -d --name site -p 9090:80 nginx:1.29-alpine`

1. `site`를 멈추고 `docker ps`와 `docker ps -a`를 각각 실행해 `site`가 어디에 어떤 상태로 보이는지 확인한 뒤, 다시 시작하세요. 끝나면 `site`를 지웁니다.
2. 환경변수 `MODE=dev`를 넣은 `nginx:1.29-alpine` 컨테이너를 끝나면 자동으로 지워지게 실행해 `echo $MODE`의 결과를 보고, 실행 뒤 `docker ps -a`에 남지 않았는지 확인하세요.

## 실습 7. 첫 Dockerfile

**무엇을 하나요**: 실습 3에서 손으로 실행한 `hello` 앱을 **이미지**로 만들고(빌드), 컨테이너로 실행합니다. `-p` 없이 실행하면 왜 접속이 안 되는지 보고 고칩니다. 코드를 고치면 이미지를 다시 빌드해야 한다는 것도 확인합니다. (교안 05장)

**필요한 것**: 실습 3에서 받은 `~/ktcloud-cloud-native-lab/lab/docker/hello` 폴더. `app.js`의 문구가 `hello, docker`여야 합니다(실습 3 확인 문제에서 되돌렸는지 확인).

### 1단계. Dockerfile 쓰기

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

### 2단계. 빌드

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

**이렇게 나오면?**

| 화면 | 원인 | 해결 |
|---|---|---|
| `ERROR: docker: 'docker buildx build' requires 1 argument` | 맨 끝의 `.`을 빠뜨림 | `docker build -t hello:v1 .` (점 포함) |
| `failed to read dockerfile: open Dockerfile: no such file or directory` | 지금 폴더에 `Dockerfile`이 없음(다른 폴더에 있거나, 이름이 `dockerfile`·`Dockerfile.txt`) | `pwd`로 `…/lab/docker/hello`인지, `ls`로 이름이 정확히 `Dockerfile`인지 확인 |
| `ERROR` 줄에 `dockerfile parse error` 등 | Dockerfile 내용 오타 | `nano Dockerfile`로 열어 1단계와 비교 |

### 3단계. `-p` 없이 실행 → 접속 안 됨

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

### 4단계. `-p`로 연결

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

**이렇게 나오면?**

| 화면 | 원인 | 해결 |
|---|---|---|
| `Conflict. The container name "/hello" is already in use` | 3단계의 `hello`를 안 지움 | `docker rm -f hello` 후 다시 |
| `failed to bind host port 0.0.0.0:8000/tcp: address already in use` | 실습 1의 파이썬 웹 서버 등 Docker 밖의 프로그램이 VM 8000번을 쓰는 중 | 그 터미널에서 Ctrl+C. 실패한 컨테이너가 남으므로 `docker rm -f hello` 후 다시 |

### 5단계. 코드를 고치면 다시 빌드

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

### 끝났는지 확인
- ☐ `curl localhost:8000`에 `hello, docker`가 나온다
- ☐ `curl localhost:8001`에 `hello, 본인이름`이 나온다
- ☐ `docker image ls hello`에 `v1`, `v2` 두 줄이 있다

### 정리
- `hello`·`hello2` 컨테이너는 **실습 9까지 켜 둡니다**. 지우지 마세요
- `Dockerfile`과 고친 `app.js`는 실습 8에서 그대로 씁니다

### 확인 문제
1. `docker history hello:v2`로 이미지의 층을 보세요. 우리가 Dockerfile에 적은 줄 가운데 크기(SIZE)가 가장 큰 줄은 어느 것인가요? 왜 그럴까요?
2. `hello:v1` 이미지로 이름 `hello3`, VM 포트 8010인 컨테이너를 하나 더 실행해 `curl`로 확인하세요. 어떤 문구가 나오나요? 확인한 뒤 `hello3`는 지웁니다.

## 실습 8. 빌드 캐시와 COPY 순서

**무엇을 하나요**: Docker가 바뀌지 않은 줄은 저장해 둔 결과(**캐시**)를 다시 쓴다는 것을 보고, Dockerfile 줄 순서를 바꿔 오래 걸리는 `npm install`을 캐시로 건너뛰게 만듭니다. 빌드를 빠르게 하는 가장 기본적인 방법입니다. (교안 05장)

**필요한 것**: 실습 7의 `hello` 폴더와 `Dockerfile`.

### 1단계. 아무것도 안 바꾸고 다시 빌드

```bash
cd ~/ktcloud-cloud-native-lab/lab/docker/hello
docker build -t hello:v2 .
```

**이렇게 나오면 성공** — 화면 예(가운데 줄)

```
 => CACHED [2/4] WORKDIR /app
 => CACHED [3/4] COPY . ./
 => CACHED [4/4] RUN npm install
```
모든 줄이 `CACHED` — 저장해 둔 결과를 그대로 썼습니다. 바뀐 것이 없으니 다시 할 일이 없습니다.

### 2단계. app.js만 고치고 다시 빌드

```bash
echo "// v3" >> app.js       # 파일 끝에 주석 한 줄 추가 (동작은 같음)
docker build -t hello:v3 .
```

**이 명령은**
- `echo "// v3" >> app.js` = `app.js` 끝에 `// v3` 한 줄을 이어 씀(실습 2의 `>>`). `//`는 자바스크립트의 주석이라 앱 동작은 같고, 파일 내용만 바뀜

**이렇게 나오면 성공** — 화면 예

```
 => CACHED [2/4] WORKDIR /app
 => [3/4] COPY . ./
 => [4/4] RUN npm install
```
`app.js`가 바뀌어 `COPY . ./`가 다시 실행됐고, **그 뒤 줄은 모두** 다시 실행됩니다. 라이브러리는 그대로인데 `npm install`을 또 합니다.

### 3단계. 순서 바꾸기

라이브러리 목록(`package.json`, `package-lock.json`)만 먼저 복사해 `npm install`을 하고, 나머지 코드는 그다음에 복사합니다.

```bash
nano Dockerfile
```

nano에서 내용을 아래 7줄로 바꿉니다.
- 가장 쉬운 방법: **Ctrl+K**를 눌러 한 줄씩 잘라 내 모든 줄을 지운 뒤(6번), 아래 7줄을 붙여 넣기
- **Ctrl+O → Enter**(저장) → **Ctrl+X**(나가기)

```dockerfile
FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm install
COPY . ./
EXPOSE 3000
CMD ["node", "app.js"]
```

`cat Dockerfile`로 7줄이 위와 같은지 확인한 뒤 빌드합니다.

```bash
docker build -t hello:v3 .   # 순서가 바뀌어 한 번은 전부 다시
echo "// v3 again" >> app.js
docker build -t hello:v3 .
```

**이 명령은**
- 첫 빌드 = Dockerfile이 바뀌었으니 한 번은 처음부터 다시 함
- `echo "// v3 again" >> app.js` = 코드만 한 번 더 바꿈
- 두 번째 빌드 = 이제 캐시가 어떻게 쓰이는지 봄

**이렇게 나오면 성공** — 두 번째 빌드의 화면 예. **`CACHED [4/5] RUN npm install`** 이 보이면 성공입니다.

```
 => CACHED [2/5] WORKDIR /app
 => CACHED [3/5] COPY package.json package-lock.json ./
 => CACHED [4/5] RUN npm install
 => [5/5] COPY . ./
```
이제 코드만 고치면 `npm install`은 `CACHED`, 마지막 `COPY . ./`만 다시 합니다. 이 앱은 라이브러리가 적어 `npm install`이 1초 남짓이지만, 라이브러리가 많은 실제 앱은 이 줄이 몇 분씩 걸립니다. **자주 바뀌는 것(코드)은 아래로, 덜 바뀌는 것(라이브러리 목록)은 위로.**

**이렇게 나오면?**

| 화면 | 원인 | 해결 |
|---|---|---|
| 두 번째 빌드에서도 `[4/5] RUN npm install`에 `CACHED`가 없음 | Dockerfile 순서가 위와 다름(`COPY . ./`가 `RUN npm install`보다 위) | `cat Dockerfile`로 확인하고 nano로 고친 뒤, 위 세 줄을 다시 |
| `[2/4]`처럼 분모가 4 | Dockerfile이 저장되지 않음(아직 6줄) | nano에서 Ctrl+O → **Enter**를 눌렀는지 확인 |

### 끝났는지 확인
- ☐ 순서를 바꾼 Dockerfile(7줄)로 `app.js`만 고쳐 빌드했을 때 `CACHED [4/5] RUN npm install`이 보였다

### 정리
- 지울 것은 없습니다. `hello`·`hello2` 컨테이너는 실습 9까지 켜 둡니다

### 확인 문제
1. 순서를 바꾼 Dockerfile로 아무것도 고치지 않고 다시 빌드하면 `CACHED`가 붙는 줄은 몇 개인가요?
2. 순서를 바꾼 Dockerfile에서 `package.json`을 고치면(예: 라이브러리를 하나 추가) `npm install`은 캐시를 쓸까요, 다시 실행될까요? 이유를 한 줄로 적으세요. (실제로 고치지 않아도 됩니다)

## 실습 9. Docker Hub에 올리고 받기

**무엇을 하나요**: 실습 7에서 만든 `hello:v2` 이미지를 내 Docker Hub(인터넷의 이미지 창고, 레지스트리) 계정에 올리고(push), 내 VM에서 지운 뒤 다시 받아(pull) 실행합니다. 옆 사람의 이미지도 받아 실행해 봅니다. 이미지를 한 번 올려 두면 어느 컴퓨터에서든 같은 앱을 받아 실행할 수 있다는 것을 확인합니다. (교안 06장)

**필요한 것**: 실습 7의 `hello:v2` 이미지, Docker Hub 계정(없으면 0단계에서 만듦).

아래 `<아이디>`는 본인 Docker Hub 아이디로 바꿉니다(예: `kim123`). 꺾쇠(`<` `>`)도 지웁니다.

### 0단계. Docker Hub 가입 (계정이 있으면 건너뜀)

내 노트북 브라우저에서 합니다.

1. https://hub.docker.com 에 들어갑니다
2. **Sign up**(가입)을 누릅니다
3. 이메일, **아이디(Username)**, 비밀번호를 정합니다. Google·GitHub 계정으로 가입해도 됩니다
   - 아이디는 **영어 소문자와 숫자**로 정합니다. 이미지 이름 맨 앞에 붙으므로(`kim123/hello`) 짧고 쉬운 것이 좋습니다
4. 가입한 이메일로 온 **인증 메일**을 열어 확인 버튼을 누릅니다
5. Docker Hub에 로그인되면 끝입니다. 오른쪽 위 프로필에서 내 아이디를 확인해 둡니다

### 1단계. 로그인

서버 VM 터미널에서 실행합니다.

```bash
docker login
```

**이렇게 나오면** — 화면 예(코드 `XXXX-XXXX`는 매번 다름)

```
USING WEB-BASED LOGIN

i Info → To sign in with credentials on the command line, use 'docker login -u <username>'

Your one-time device confirmation code is: XXXX-XXXX
Press ENTER to open your browser or submit your device code here: https://login.docker.com/activate

Waiting for authentication in the browser…
```

뜻: "웹으로 로그인합니다. 한 번만 쓰는 확인 코드는 XXXX-XXXX입니다. 브라우저에서 아래 주소에 코드를 입력하세요. 브라우저 인증을 기다리는 중…"

할 일:
1. VM에는 브라우저가 없으므로, **내 노트북 브라우저**에서 https://login.docker.com/activate 를 직접 엽니다
2. 터미널에 나온 코드(`XXXX-XXXX`)를 입력하고 확인합니다. Docker Hub 로그인을 물으면 로그인합니다
3. 터미널로 돌아오면 `Login Succeeded`(로그인 성공)가 나와 있습니다

**웹 로그인이 안 되면 — 아이디와 토큰으로 로그인**

```bash
docker login -u <아이디>
```

화면 예:
```
i Info → A Personal Access Token (PAT) can be used instead.
         To create a PAT, visit https://app.docker.com/settings

Password:
```

- `Password:`에 Docker Hub 비밀번호 또는 **액세스 토큰**(비밀번호 대신 쓰는 긴 글자, https://app.docker.com/settings 에서 만듦)을 붙여 넣고 Enter. 입력해도 화면에 안 보이는 것이 정상입니다
- `Login Succeeded`가 나오면 됩니다

- 로그인 정보는 VM의 `~/.docker/config.json`에 저장됩니다. 실습이 끝나면 `docker logout`으로 지울 수 있습니다

### 2단계. 이름 붙이기(tag) → 올리기(push)

Docker Hub에 올릴 이미지의 이름은 `아이디/저장소:태그` 모양이어야 합니다. 그래야 Docker가 "누구의 창고에 올릴지" 압니다.

```bash
docker tag hello:v2 <아이디>/hello:v2
docker image ls --filter reference='*hello*'   # hello:v2와 <아이디>/hello:v2의 ID가 같음 = 이미지 하나에 이름 둘
docker push <아이디>/hello:v2
```

**이 명령은**
- `docker tag 원래이름 새이름` = 이미지에 이름표를 하나 더 붙임. 이미지가 복사되는 것이 아님
- `docker image ls --filter reference='*hello*'` = 이름에 `hello`가 들어간 이미지만 보기
- `docker push 이름` = 그 이미지를 레지스트리(Docker Hub)에 올림

**이렇게 나오면 성공** — push 화면 예. 마지막 줄 `v2: digest: sha256:…`가 나오면 다 올라간 것입니다.

```
The push refers to repository [docker.io/<아이디>/hello]
7a3b060021ff: Pushed
…
v2: digest: sha256:… size: 856
```

- `Pushed` = 이 층(이미지의 한 부분)을 올림. 줄 수는 달라도 됩니다
- 브라우저에서 `https://hub.docker.com/r/<아이디>/hello` 를 열면 `v2` 태그가 보입니다

**이렇게 나오면?**

| 화면 | 원인 | 해결 |
|---|---|---|
| `push access denied, repository does not exist or may require authorization: server message: insufficient_scope: authorization failed` | 로그인을 안 했거나, 이름 앞의 `<아이디>/`가 빠졌거나 틀림 | `docker login`을 다시 하고, `docker tag`의 아이디가 Docker Hub 아이디와 같은지 확인 |
| `bash: 아이디: No such file or directory` | `<아이디>`를 본인 아이디로 바꾸지 않고 꺾쇠째 붙여 넣음 | `kim123/hello:v2`처럼 꺾쇠 없이 본인 아이디로 바꿔서 |

### 3단계. 지우고 다시 받아 실행

```bash
docker rmi <아이디>/hello:v2                   # Untagged: <아이디>/hello:v2 (이름표만 뗌)
docker run -d --name from-hub -p 8002:3000 <아이디>/hello:v2
```

**이 명령은**
- `docker rmi <아이디>/hello:v2` = 2단계에서 붙인 이름표를 뗌. VM에 그 이름의 이미지가 없어짐
- `docker run …` = 그 이름으로 실행 → VM에 없으니 Docker Hub에서 받아 옴

**이렇게 나오면 성공** — 화면 예

```
Unable to find image '<아이디>/hello:v2' locally
v2: Pulling from <아이디>/hello
Digest: sha256:…
Status: Downloaded newer image for <아이디>/hello:v2
```

뜻: "VM에 이 이미지가 없어서 → Docker Hub에서 받는 중 → 받기 완료." 그 아래 컨테이너 ID 한 줄이 나옵니다.

```bash
curl localhost:8002         # hello, 본인이름
```

`docker run`은 이미지가 VM에 없으면 레지스트리에서 받아(pull) 실행합니다. 다른 VM, 다른 사람의 컴퓨터에서도 이 명령 한 줄로 같은 앱이 돕니다.

### 4단계. 옆 사람 이미지 받아 보기

옆 사람의 Docker Hub 아이디를 물어 받아 실행합니다. 공개 저장소는 로그인 없이도 받을 수 있습니다.

```bash
docker run --rm -d --name friend -p 8012:3000 <옆사람아이디>/hello:v2
curl localhost:8012         # hello, 옆사람이름
docker rm -f friend
```

**이렇게 나오면 성공**: `hello, 옆사람이름` — 옆 사람이 실습 7에서 넣은 이름이 나옵니다.

**이렇게 나오면?**

| 화면 | 원인 | 해결 |
|---|---|---|
| `failed to resolve reference "docker.io/…/hello:v2": … not found` | 그런 이미지가 없음 — 옆 사람 아이디 오타, 또는 옆 사람이 아직 push 전 | 아이디 확인, 옆 사람이 2단계를 끝냈는지 확인 |

### Docker Hub 로그인이 막히면 — 연습용 레지스트리

VM 안에 연습용 레지스트리를 띄워 같은 순서(tag → push → rmi → run)를 해 봅니다. 레지스트리 주소(`localhost:5000`)가 이미지 이름 맨 앞에 붙는다는 점만 다릅니다.

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

- `registry:3` = 레지스트리 프로그램이 든 이미지. VM의 5000번에서 Docker Hub와 같은 일을 함
- `curl localhost:5000/v2/_catalog` = 이 레지스트리에 올라간 저장소 목록
- 이미 Docker Hub로 `from-hub`를 만든 경우 이름이 겹칩니다(`Conflict`). `docker rm -f from-hub` 후 실행합니다

### 끝났는지 확인
- ☐ Docker Hub 웹에서 내 `hello` 저장소에 `v2`가 보인다 (연습용 레지스트리를 썼다면 `_catalog`에 `hello`)
- ☐ 받아서 실행한 `curl localhost:8002`에 내 이름이 나온다

### 정리
확인 문제까지 끝났으면, 실습 7부터 켜 둔 컨테이너는 이제 지워도 됩니다. 이미지(`hello:v1`, `hello:v2`)는 두어도 됩니다.

```bash
docker rm -f hello hello2 from-hub
```

- 연습용 레지스트리를 띄웠다면 `docker rm -f reg`도 함께
- 실습이 끝나면 `docker logout`으로 VM에 저장된 로그인 정보를 지울 수 있습니다(확인 문제 1을 한 뒤에)

### 확인 문제
1. `hello:v1`에도 `<아이디>/hello:v1` 이름을 붙여 올리세요. Docker Hub 웹의 Tags 탭에 태그가 몇 개 보이나요?
2. 이미지를 공유할 때 `docker push`로 올리는 것은 이미지일까요, 컨테이너일까요? `from-hub` 컨테이너 안에서 바꾼 파일은 다른 사람에게 전달될까요?

## 실습 10. 볼륨 — 컨테이너를 지워도 남는 데이터

**무엇을 하나요**: 파일을 저장하는 앱으로 "컨테이너를 지우면 안의 파일도 사라진다"는 것을 직접 보고, **이름 있는 볼륨**(컨테이너 밖에 따로 두는 저장 공간)으로 데이터를 남깁니다. DB처럼 지워지면 안 되는 데이터를 컨테이너로 다룰 때 꼭 필요합니다. (교안 07장)

**필요한 것**: 실습 3에서 받은 저장소의 `lab/docker/files` 폴더.

### 1단계. files 앱 빌드와 실행

`files`는 이름과 내용을 받아 `/app/files/이름.txt`로 저장하는 앱입니다. Dockerfile은 폴더에 들어 있습니다(이번에는 직접 쓰지 않음).

```bash
cd ~/ktcloud-cloud-native-lab/lab/docker/files
docker build -t files .
docker run -d --name files -p 8003:3000 files
curl -d "name=memo&text=hello volume" localhost:8003/save   # Found. Redirecting to /
curl localhost:8003/files/memo.txt                           # hello volume
docker exec files ls /app/files                              # memo.txt
```

**이 명령은**

| 명령 | 뜻 |
|---|---|
| `docker build -t files .` | 이 폴더의 Dockerfile로 이미지 `files`를 만듦(태그를 안 적으면 `latest`) |
| `docker run -d --name files -p 8003:3000 files` | 이미지 `files`로 컨테이너 `files`를 VM 8003번에 띄움(컨테이너와 이미지 이름이 같아도 됨) |
| `curl -d "name=memo&text=hello volume" localhost:8003/save` | 이름 `memo`, 내용 `hello volume`으로 저장 요청. `-d` = 데이터를 담아 보냄(웹 페이지의 입력 폼에 값을 넣어 보내는 것과 같음) |
| `curl localhost:8003/files/memo.txt` | 저장된 파일 읽기 |
| `docker exec files ls /app/files` | 컨테이너 안의 저장 폴더 목록 |

**이렇게 나오면 성공**
- 저장 → `Found. Redirecting to /`(저장 끝, 첫 화면으로 이동하라는 뜻)
- 읽기 → `hello volume`
- 폴더 목록 → `memo.txt`

브라우저로 보려면 VS Code **PORTS** 탭에서 8003을 전달해 `http://localhost:8003`을 엽니다([시작하기 전에 8](#8-브라우저로-서버의-웹-페이지-보기-ports-탭)). 화면에서 이름(영문·숫자)과 내용을 넣고 **저장**을 눌러도 같습니다.

### 2단계. 컨테이너를 지우고 다시 만들기

```bash
docker rm -f files
docker run -d --name files -p 8003:3000 files
curl localhost:8003/files/memo.txt                           # Where is your file?
```

**이렇게 나오면 성공**: `Where is your file?`(파일이 어디 있나요? = 그런 파일 없음). 1단계에서 저장한 `memo.txt`가 사라졌습니다.

저장한 파일은 **그 컨테이너 안에만** 있었습니다. 같은 이미지로 새로 만든 컨테이너는 빈 상태로 시작합니다.

### 3단계. 이름 있는 볼륨 붙이기

`-v 볼륨이름:컨테이너경로` — 컨테이너 안의 `/app/files` 폴더를, 컨테이너 밖의 볼륨 `files-data`에 연결합니다.

```bash
docker rm -f files
docker run -d --name files -p 8003:3000 -v files-data:/app/files files
curl -d "name=memo&text=hello volume" localhost:8003/save
docker rm -f files
docker run -d --name files -p 8003:3000 -v files-data:/app/files files
curl localhost:8003/files/memo.txt                           # hello volume ← 남아 있음
```

**이 명령은**
- `-v files-data:/app/files` = 볼륨 `files-data`(없으면 새로 만듦)를 컨테이너의 `/app/files`에 붙임. 앱이 `/app/files`에 쓰는 파일은 실제로는 볼륨에 저장됨
- 저장 → 컨테이너 지우기 → **같은 볼륨을 붙여** 새로 만들기 → 읽기

**이렇게 나오면 성공**: 마지막 `curl`에 `hello volume`. 컨테이너를 지웠는데도 남아 있습니다.

볼륨이 어디 있는지 봅니다.

```bash
docker volume ls                                             # local  files-data
docker volume inspect files-data
```
화면 예(`inspect` 일부):
```
"Mountpoint": "/var/lib/docker/volumes/files-data/_data",
"Name": "files-data",
```

- `docker volume ls` = 볼륨 목록. `local` = 이 VM에 있는 볼륨
- `docker volume inspect` = 볼륨의 자세한 정보. `Mountpoint` = VM의 실제 위치

볼륨은 컨테이너 밖, Docker가 관리하는 VM 폴더(`/var/lib/docker/volumes/…`)에 있습니다. 컨테이너를 지워도 볼륨은 남고, 다음 컨테이너에 다시 붙일 수 있습니다.

**이렇게 나오면?**

| 화면 | 원인 | 해결 |
|---|---|---|
| 마지막 `curl`에 `Where is your file?` | 두 `docker run` 중 하나에 `-v files-data:/app/files`가 빠짐 | 3단계 블록을 처음부터 다시 |
| `Conflict. The container name "/files" is already in use` | `docker rm -f files`를 건너뜀 | `docker rm -f files` 후 다시 |

### 끝났는지 확인
- ☐ 볼륨 없이 다시 만들면 `Where is your file?`가 나왔다
- ☐ 볼륨을 붙인 채 컨테이너를 지우고 다시 만든 뒤에도 `curl localhost:8003/files/memo.txt`에 `hello volume`이 나왔다

### 정리
- `files` **이미지**는 실습 11에서 씁니다. **지우지 마세요**
- `files` 컨테이너와 `files-data` 볼륨은 확인 문제에서 지웁니다

### 확인 문제
1. `files` 컨테이너를 지운 뒤(`docker rm -f files`) `docker volume ls`에 `files-data`가 남아 있는지 확인하세요.
2. `files-data` 볼륨을 쓰는 컨테이너가 실행 중일 때 `docker volume rm files-data`를 하면 어떤 오류가 나나요? 컨테이너를 지운 뒤 다시 지워 보세요.

## 실습 11. 바인드 마운트 — 내 폴더를 컨테이너에 연결

**무엇을 하나요**: VM의 폴더를 컨테이너 안에 그대로 연결(**바인드 마운트**)해, 파일을 고치면 이미지를 다시 빌드하지 않아도 바로 반영되는 것을 확인합니다. 개발 중에 코드를 고칠 때마다 빌드하지 않고 확인할 때 씁니다. (교안 07장)

**필요한 것**: 실습 10의 `files` 이미지.

### 1단계. 웹 페이지 폴더 연결

`-v VM경로:컨테이너경로` (VM 경로는 `/` 또는 `~`로 시작하는 전체 경로). 실습 10의 `-v 볼륨이름:…`과 모양이 같고, 왼쪽이 **이름 대신 경로**라는 점이 다릅니다.

```bash
mkdir -p ~/site
echo "<h1>my site v1</h1>" > ~/site/index.html
docker run -d --name mysite -p 8004:80 -v ~/site:/usr/share/nginx/html nginx:1.29-alpine
curl localhost:8004                    # <h1>my site v1</h1>
```

**이 명령은**
- `mkdir -p ~/site` + `echo … > ~/site/index.html` = VM에 웹 페이지 폴더와 파일을 만듦
- `-v ~/site:/usr/share/nginx/html` = VM의 `~/site` 폴더를 nginx가 웹 페이지를 찾는 폴더(실습 6 5단계에서 본 곳) 자리에 연결

**이렇게 나오면 성공**: `<h1>my site v1</h1>` — nginx 기본 페이지(`Welcome to nginx!`) 대신 내 파일이 나옵니다.

### 2단계. VM에서 파일 고치기

```bash
nano ~/site/index.html                 # v1 → v2 로 고쳐 저장
```

- `v1`을 `v2`로 바꿉니다 → **Ctrl+O → Enter**(저장) → **Ctrl+X**(나가기)

```bash
curl localhost:8004                    # <h1>my site v2</h1> ← 바로 반영
```

**이렇게 나오면 성공**: `<h1>my site v2</h1>`. 빌드도, 컨테이너 재시작도 하지 않았는데 바로 바뀌었습니다.

### 3단계. 연결 상태 보기

```bash
docker inspect -f '{{range .Mounts}}{{.Type}} {{.Source}} -> {{.Destination}}{{end}}' mysite
# bind /home/lab/site -> /usr/share/nginx/html
```

**이 명령은**: `docker inspect` = 컨테이너의 자세한 정보. `-f '…'` = 그중 연결(Mounts) 정보만 골라 한 줄로 보여 줌. 복사해서 그대로 붙여 넣으면 됩니다.

**이렇게 나오면 성공**: `bind /home/lab/site -> /usr/share/nginx/html` = "바인드 마운트: VM의 `/home/lab/site` → 컨테이너의 `/usr/share/nginx/html`"

nginx 이미지 안의 `/usr/share/nginx/html` 자리에 VM의 `~/site` 폴더가 그대로 보입니다. 개발 중에 코드를 고칠 때마다 빌드하지 않고 바로 확인할 때 씁니다.

### 4단계. 앱이 저장한 파일을 VM에서 보기

실습 10의 files 앱에 VM 폴더를 연결합니다.

```bash
mkdir -p ~/files-data
docker run -d --name files2 -p 8013:3000 -v ~/files-data:/app/files files
curl -d "name=note&text=from container" localhost:8013/save
ls -l ~/files-data                     # -rw-r--r-- 1 root root 14 … note.txt
cat ~/files-data/note.txt              # from container
docker rm -f files2
```

**이렇게 나오면 성공**
- `ls -l ~/files-data` → `note.txt` 한 줄(`ls -l` = 자세히 보기. `root root` = 파일 주인)
- `cat ~/files-data/note.txt` → `from container`

- 컨테이너가 만든 파일이 VM 폴더에 바로 생깁니다. 컨테이너 안의 앱이 root(관리자 계정)로 실행돼 파일 주인이 `root`입니다(VM에서 고치거나 지우려면 `sudo`)

| | 이름 있는 볼륨 (실습 10) | 바인드 마운트 (실습 11) |
|---|---|---|
| 쓰는 법 | `-v files-data:/app/files` | `-v ~/site:/usr/share/nginx/html` |
| 어디에 | Docker가 관리하는 폴더 | 내가 정한 VM 폴더 |
| 주로 | DB 데이터처럼 남겨야 하는 것 | 개발 중인 코드·설정 파일 |

### 끝났는지 확인
- ☐ `~/site/index.html`을 고친 뒤 `curl localhost:8004`에 바뀐 내용이 바로 나왔다
- ☐ `cat ~/files-data/note.txt`에 `from container`가 나왔다

### 정리
- `files2`는 4단계에서 이미 지웠습니다
- `mysite`는 확인 문제에서 씁니다. 확인 문제까지 끝나면 지워도 됩니다: `docker rm -f mysite`
- `~/files-data`의 파일은 주인이 root라 지우려면 `sudo rm -r ~/files-data`(두어도 됩니다)

### 확인 문제
1. `~/site`에 `about.html`(내용 `<p>about</p>`)을 새로 만들고 `curl localhost:8004/about.html`로 확인하세요. 컨테이너를 다시 만들어야 하나요?

## 실습 12. 네트워크 — API와 DB 연결

**무엇을 하나요**: 할 일 앱의 API 컨테이너(요청을 받아 데이터를 주고받는 서버)와 DB 컨테이너(PostgreSQL, 데이터를 저장하는 프로그램)를 따로 띄워 연결합니다. 기본 상태에서는 서로 이름을 못 찾는 것을 보고, 사용자 네트워크를 만들어 컨테이너 이름으로 연결합니다. 여러 컨테이너로 된 앱의 기본 구조입니다. (교안 08장)

**필요한 것**: 실습 3에서 받은 저장소의 `lab/docker/todo/api` 폴더.

### 1단계. API 이미지 빌드

```bash
cd ~/ktcloud-cloud-native-lab/lab/docker/todo/api
docker build -t todo-api .
```

**이렇게 나오면 성공**: 마지막 즈음 `naming to docker.io/library/todo-api`.

API는 환경변수 `DB_HOST`(DB 주소), `DB_USER`(DB 사용자), `DB_PASSWORD`(비밀번호), `DB_NAME`(DB 이름)을 읽어 DB에 접속합니다(01장의 "설정은 환경변수로"). DB가 준비될 때까지 2초 간격으로 15번 다시 시도합니다.

### 2단계. 그냥 띄우면 — 이름을 못 찾음

명령이 깁니다. 한 줄씩 통째로 복사해 붙여 넣습니다.

```bash
docker run -d --name db -e POSTGRES_USER=todo -e POSTGRES_PASSWORD=todo-pass -e POSTGRES_DB=todo postgres:17-alpine
docker run -d --name api -p 8005:3000 -e DB_HOST=db -e DB_USER=todo -e DB_PASSWORD=todo-pass -e DB_NAME=todo todo-api
docker logs api
```

**이 명령은**

| 부분 | 뜻 |
|---|---|
| `--name db … postgres:17-alpine` | PostgreSQL 17 이미지로 DB 컨테이너 `db`를 띄움 |
| `-e POSTGRES_USER=todo` 등 | DB를 처음 만들 때 쓸 사용자·비밀번호·DB 이름(이 이미지가 정해 둔 환경변수) |
| `--name api -p 8005:3000 … todo-api` | 1단계 이미지로 API 컨테이너 `api`를 VM 8005번에 띄움 |
| `-e DB_HOST=db` | API에게 "DB는 `db`라는 이름으로 찾아가라"고 알려 줌 |

**이렇게 나오면** — `docker logs api` 화면 예(실패가 정상)

```
waiting for database at db (1/15): getaddrinfo ENOTFOUND db
waiting for database at db (2/15): getaddrinfo ENOTFOUND db
```

```bash
docker exec api ping -c 1 db
# ping: bad address 'db'
```

- `waiting for database at db (1/15)` = "`db`의 DB를 기다리는 중(15번 중 1번째 시도)"
- `ENOTFOUND db` = `db`라는 이름을 찾지 못함
- `ping -c 1 db` = `db`에 신호를 한 번 보내 봄 → `bad address 'db'`(그런 주소 없음)

기본 네트워크에서는 컨테이너 이름으로 서로를 찾을 수 없습니다.

### 3단계. 네트워크를 만들어 같이 넣기

```bash
docker rm -f db api
docker network create todo-net
docker run -d --name db --network todo-net -e POSTGRES_USER=todo -e POSTGRES_PASSWORD=todo-pass -e POSTGRES_DB=todo postgres:17-alpine
docker run -d --name api --network todo-net -p 8005:3000 -e DB_HOST=db -e DB_USER=todo -e DB_PASSWORD=todo-pass -e DB_NAME=todo todo-api
docker logs api
```

**이 명령은**
- `docker network create todo-net` = 이름 `todo-net`인 네트워크를 만듦. 같은 네트워크에 넣은 컨테이너끼리는 **이름으로** 서로 찾을 수 있음
- `--network todo-net` = 이 컨테이너를 `todo-net`에 넣음. 2단계 명령과 이것만 다릅니다

**이렇게 나오면 성공** — `docker logs api` 화면 예. **`connected to database at db`** 가 보이면 성공입니다.

```
waiting for database at db (1/15): connect ECONNREFUSED 172.19.0.2:5432
connected to database at db
todo api listening on port 3000
```
- 첫 줄: 이름은 찾았지만(`db` → `172.19.0.2`) DB가 아직 준비 중이라 한 번 다시 시도한 것(ECONNREFUSED = 연결 거부). IP는 VM마다 다를 수 있습니다. 이 줄이 없어도 됩니다
- `connected to database at db` = DB에 연결됨, `todo api listening on port 3000` = API가 3000번에서 기다리는 중
- `docker exec api ping -c 1 db` → `1 packets transmitted, 1 packets received`(1개 보내 1개 받음 = 연결됨)

**이렇게 나오면?**

| 화면 | 원인 | 해결 |
|---|---|---|
| `connected` 없이 `waiting …` 줄만 있음 | DB가 아직 준비 중 | 10초쯤 뒤 `docker logs api`를 다시 |
| `Error response from daemon: network with name todo-net already exists` | 네트워크를 이미 만듦 | 괜찮습니다. 다음 줄부터 이어서 |
| `Conflict. The container name "/db" …` | 2단계 컨테이너를 안 지움 | `docker rm -f db api` 후 3단계를 처음부터 |

### 4단계. API로 할 일 넣고 보기

```bash
curl localhost:8005/api/todos                                   # []
curl -X POST -H 'Content-Type: application/json' -d '{"title":"buy milk"}' localhost:8005/api/todos
# {"id":1,"title":"buy milk"}
curl localhost:8005/api/todos                                   # [{"id":1,"title":"buy milk"}]
docker ps --format 'table {{.Names}}\t{{.Ports}}'
```

**이 명령은**

| 부분 | 뜻 |
|---|---|
| `curl localhost:8005/api/todos` | 할 일 목록 요청. `[]` = 빈 목록 |
| `-X POST` | "새로 만들어 달라"는 요청(기본은 "보여 달라" GET) |
| `-H 'Content-Type: application/json'` | 보내는 데이터가 JSON(중괄호 모양의 데이터 형식)이라고 알려 줌 |
| `-d '{"title":"buy milk"}'` | 보낼 데이터: 제목이 `buy milk`인 할 일 |
| `docker ps --format 'table {{.Names}}\t{{.Ports}}'` | `docker ps`에서 이름과 포트 열만 보기 |

**이렇게 나오면 성공**: 목록이 `[]` → 넣은 뒤 `[{"id":1,"title":"buy milk"}]`. 포트 화면 예:

```
NAMES     PORTS
api       0.0.0.0:8005->3000/tcp, [::]:8005->3000/tcp
db        5432/tcp
```
`db`에는 `-p`가 없습니다. VM 밖에서는 DB에 들어올 수 없고, 같은 네트워크의 `api`만 `db:5432`로 접속합니다. **컨테이너끼리는 `-p` 없이 이름과 컨테이너 포트로 통신**합니다.

### 끝났는지 확인
- ☐ `docker logs api`에 `connected to database at db`가 있다
- ☐ `curl localhost:8005/api/todos`에 넣은 할 일이 보인다

### 정리
- 확인 문제 2가 정리입니다(`db`, `api`, `todo-net` 지우기). 실습 13에서 같은 이름을 쓰지는 않지만, 같은 구성을 Compose로 다시 띄우므로 지우고 넘어갑니다
- `todo-api` 이미지는 두어도 됩니다

### 확인 문제
1. `todo-net`에 붙인 임시 컨테이너에서 `api`를 이름으로 불러 보세요: `docker run --rm --network todo-net nginx:1.29-alpine wget -qO- api:3000/api/todos`. `--network todo-net`을 빼고 실행하면 어떤 오류가 나오나요?
2. 확인이 끝나면 `docker rm -f db api`, `docker network rm todo-net`으로 정리하세요. (실습 13에서 Compose로 같은 구성을 다시 띄웁니다)

## 실습 13. Compose로 할 일 앱(3티어) 띄우기

**무엇을 하나요**: 화면(web) · API(api) · DB(db) 세 컨테이너를 `compose.yaml` 파일 하나에 적고, 명령 한 줄로 띄우고 내립니다. 실습 12에서 긴 명령 여러 줄로 하던 일을 파일로 정리하는 것입니다. (3티어 = 화면·API·DB 세 층으로 나눈 앱 구조) (교안 09장)

**필요한 것**: 실습 3에서 받은 저장소의 `lab/docker/todo` 폴더. 실습 12의 컨테이너는 지운 상태.

### 1단계. 폴더 둘러보기

```bash
cd ~/ktcloud-cloud-native-lab/lab/docker/todo
ls                        # api  web
```

**이렇게 나오면 성공**: `api  web` 두 폴더. 프롬프트가 `…/lab/docker/todo$`(api 폴더 **안이 아니라** todo 폴더).

| 폴더·이미지 | 역할 |
|---|---|
| `web/` (nginx) | 화면(HTML·JS)을 주고, `/api/`로 오는 요청은 `api:3000`으로 넘김 |
| `api/` (Node) | 실습 12의 API |
| `postgres:17-alpine` | DB. 빌드 없이 공식 이미지 사용 |

### 2단계. compose.yaml 쓰기

`todo` 폴더에서 nano로 `compose.yaml`을 만듭니다.

```bash
nano compose.yaml
```

아래 내용을 복사해 붙여 넣고 **Ctrl+O → Enter**(저장) → **Ctrl+X**(나가기). **들여쓰기는 스페이스 2칸**(탭 금지)입니다. YAML(이 파일의 형식)은 들여쓰기로 "무엇 아래에 무엇이 있는지"를 나타내므로 칸 수가 틀리면 오류가 납니다.

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

**이 파일은** — 실습 12의 명령과 하나씩 맞춰 봅니다.

| 키 | 뜻 | 실습 12의 명령에서 |
|---|---|---|
| `services:` 아래 `db`·`api`·`web` | 컨테이너 하나씩. **이름이 곧 주소** | `--name db` |
| `image:` / `build:` | 받아서 쓸 이미지 / 이 폴더의 Dockerfile로 빌드 | `postgres:17-alpine` / `docker build` |
| `environment:` | 환경변수 | `-e` |
| `ports:` | VM 포트:컨테이너 포트 | `-p` |
| `volumes:` | 볼륨:컨테이너 경로 (맨 아래 `volumes:`에 이름 선언) | `-v` |
| `depends_on:` | 먼저 시작할 서비스 | (순서대로 run) |

네트워크는 적지 않아도 됩니다. Compose가 이 파일의 서비스를 한 네트워크(`todo_default`)에 자동으로 넣습니다.

### 3단계. 문법 검사

```bash
docker compose config -q && echo OK       # 문법 검사. 오류가 있으면 줄 번호를 알려 줌
```

**이 명령은**: `docker compose config -q` = `compose.yaml`을 읽어 문법만 검사(`-q` = 문제가 없으면 조용히). 문제가 없으면 `&&` 뒤의 `echo OK`가 실행됩니다.

**이렇게 나오면 성공**: `OK`

**이렇게 나오면?** — 오류 문구의 `L3.C1`은 "3번째 줄(Line) 1번째 칸(Column)"이라는 뜻입니다. `nano compose.yaml`로 그 줄을 고칩니다.

| 화면 | 원인 | 해결 |
|---|---|---|
| `… found character that cannot start any token` | 들여쓰기에 **탭**을 씀 | 그 줄의 탭을 지우고 스페이스로 |
| `… did not find expected key` | 들여쓰기 칸 수가 위아래 줄과 안 맞음 | 2단계 내용과 칸 수를 맞춤(가장 쉬운 방법: 파일 내용을 모두 지우고 다시 붙여 넣기) |
| `no configuration file provided: not found` | 지금 폴더에 `compose.yaml`이 없음 | `pwd`가 `…/lab/docker/todo`인지, `ls`에 `compose.yaml`이 있는지 확인 |

### 4단계. 띄우기

```bash
docker compose up -d --build
docker compose ps
```

**이 명령은**
- `docker compose up` = `compose.yaml`의 서비스를 모두 띄움. `-d` = 뒤에서 실행, `--build` = `build:`가 있는 서비스(api, web)를 먼저 빌드
- `docker compose ps` = 이 Compose의 컨테이너 목록

**이렇게 나오면 성공** — `docker compose ps` 화면 예. 세 줄이 모두 `Up`이면 성공입니다.

```
NAME         IMAGE                SERVICE   STATUS          PORTS
todo-api-1   todo-api             api       Up …            3000/tcp
todo-db-1    postgres:17-alpine   db        Up …            5432/tcp
todo-web-1   todo-web             web       Up …            0.0.0.0:8088->80/tcp, [::]:8088->80/tcp
```
(COMMAND·CREATED 열은 줄여서 적음)

### 5단계. 화면과 API 확인

```bash
curl localhost:8088 | head -5                          # 화면 HTML (<title>todo</title>)
curl localhost:8088/api/todos                          # []  ← web(nginx)이 api로 넘겨 준 응답
curl -X POST -H 'Content-Type: application/json' -d '{"title":"learn compose"}' localhost:8088/api/todos
docker compose logs api
```

**이 명령은**
- `curl localhost:8088 | head -5` = 화면 HTML의 앞 5줄만(`head -5`)
- `curl localhost:8088/api/todos` = web(8088)으로 보냈는데, web이 `/api/` 요청을 api 컨테이너로 넘겨 줌
- `docker compose logs api` = api 서비스의 로그

**이렇게 나오면 성공**: HTML에 `<title>todo</title>`, 목록 `[]`, 추가 뒤 `{"id":1,"title":"learn compose"}`, 로그에 `connected to database at db`.

브라우저로 보려면 VS Code **PORTS** 탭에서 8088을 전달해 `http://localhost:8088`을 열고 할 일을 추가·삭제해 봅니다([시작하기 전에 8](#8-브라우저로-서버의-웹-페이지-보기-ports-탭)).

**이렇게 나오면?**

| 화면 | 원인 | 해결 |
|---|---|---|
| `docker compose ps`에 `todo-web-1`이 없거나 `Exited` | web이 시작할 때 api를 못 찾음(api가 빌드 실패 등) | `docker compose logs web`, `docker compose logs api`의 마지막 줄을 보고 질문 |
| `port is already allocated` (8088) | 앞에서 8088을 쓰는 것을 띄워 둠 | `docker ps`로 확인해 지운 뒤 `docker compose up -d --build` 다시 |

### 6단계. 내리고 다시 올리기

```bash
docker compose down        # 컨테이너·네트워크 삭제, 볼륨은 남음
docker compose up -d
curl localhost:8088/api/todos     # [{"id":1,"title":"learn compose"}] ← 남아 있음
docker compose down -v     # 볼륨까지 삭제
docker compose up -d
curl localhost:8088/api/todos     # [] ← 비어 있음
docker compose down -v
```

**이 명령은**
- `docker compose down` = 띄운 것을 모두 내림(컨테이너·네트워크 삭제). 볼륨 `db-data`는 남음 → 다시 올리면 데이터가 있음
- `docker compose down -v` = 볼륨까지 삭제(`-v` = volumes) → 다시 올리면 빈 DB

**이렇게 나오면 성공**: 첫 `curl`은 `learn compose`가 남아 있고, `down -v` 뒤의 `curl`은 `[]`.

- 실습 12에서 명령 여섯 줄(`network create`, `run` 두 번, 긴 `-e` 옵션들)로 하던 일을 파일 하나와 `up` 한 줄로 합니다
- `up -d` 바로 뒤의 `curl`이 실패하면 DB·API가 아직 시작 중일 수 있습니다. 몇 초 뒤 같은 `curl`을 다시 합니다

### 끝났는지 확인
- ☐ `docker compose ps`에 서비스 3개가 `Up`이었다
- ☐ `curl localhost:8088/api/todos`로 넣은 할 일이 `down` → `up` 뒤에도 남아 있었다
- ☐ `down -v` 뒤에는 `[]`였다

### 정리
- 6단계 마지막의 `docker compose down -v`로 이미 정리됐습니다
- 확인 문제를 하려면 `docker compose up -d`로 다시 띄우고, 끝나면 `docker compose down -v`
- `compose.yaml`은 미션 2에서 모양을 참고하니 **지우지 마세요**

### 확인 문제
1. `docker compose up -d` 상태에서 `docker ps`와 `docker network ls`, `docker volume ls`를 보세요. 컨테이너·네트워크·볼륨 이름은 어떤 규칙으로 붙었나요?
2. `compose.yaml`에서 web의 포트를 `"8089:80"`으로 바꾸고 `docker compose up -d`를 다시 실행하세요. 세 서비스 가운데 어느 것이 다시 만들어지나요? `curl localhost:8089`로 확인한 뒤 8088로 되돌립니다.

## 자주 쓴 명령
- 기초: `hostname -I` `getent hosts` `ss -tln` `curl` (`-I` `-d`) `python3 -m http.server` · `|` `grep` `>` `>>` `export` `echo $?` · `nano` (Ctrl+O · Ctrl+X), vi 나가기 `:q!` · `git clone` `npm install` `node app.js`
- 컨테이너: `run` (`-d` `--name` `-p` `-e` `-v` `--rm` `-it` `--network`) `ps` (`-a`) `stop` `start` `logs` (`--tail` `-f`) `exec` (`-it`) `cp` `inspect` (`-f`) `rm` (`-f`) `container prune`
- 이미지: `build` (`-t`) `image ls` `history` `tag` `rmi` `login` `push` `pull`
- 볼륨·네트워크·Compose: `volume ls/inspect/rm` `network create/ls/rm` `compose config/up -d --build/ps/logs/down (-v)`

## 자주 만나는 오류 한눈에

| 오류 문구(일부) | 뜻 | 먼저 해 볼 것 |
|---|---|---|
| `command not found` | 그런 명령이 없음 | 프롬프트가 `lab@sNN`인지(서버 VM인지), 명령 오타 |
| `No such file or directory` | 그런 파일·폴더가 없음 | `pwd`로 지금 위치, `ls`로 파일 이름 확인 |
| `curl: (7) Failed to connect` | 그 포트에서 기다리는 프로그램이 없음 | `docker ps`로 컨테이너가 `Up`인지, `-p` 왼쪽 번호가 맞는지 |
| `permission denied … docker.sock` | docker 그룹 적용 전 | 실습 4의 3단계(다시 접속) |
| `Conflict. The container name … is already in use` | 같은 이름의 컨테이너가 있음 | `docker rm -f 이름` 후 다시 |
| `port is already allocated` / `address already in use` | VM 포트를 이미 다른 것이 씀(컨테이너 / Docker 밖의 프로그램) | `docker ps`로 그 포트를 쓰는 컨테이너 확인, 켜 둔 웹 서버·앱이 있으면 Ctrl+C |
| `container is running` | 실행 중이라 못 지움 | `docker rm -f 이름` |
| `requires 1 argument` | `docker build` 끝의 `.` 빠짐 | `docker build -t 이름 .` |
| `push access denied` | 로그인 안 함, 또는 이름 앞 아이디 틀림 | `docker login`, `docker tag`의 아이디 확인 |
| `ENOTFOUND` / `bad address` | 컨테이너 이름을 못 찾음 | 같은 `--network`에 넣었는지 |
| `found character that cannot start any token` | YAML에 탭 | 탭을 스페이스로 |
