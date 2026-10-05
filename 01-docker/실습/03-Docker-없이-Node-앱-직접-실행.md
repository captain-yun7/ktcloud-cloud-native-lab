[← 실습 2](./02-셸-조합과-nano.md) · [목차](../Docker-실습.md) · [실습 4 →](./04-Docker-설치와-hello-world.md)

# 실습 3. Docker 없이 Node 앱 직접 실행

**무엇을 하나요**: 실습 앱을 내 VM으로 받고, VM에 Node.js를 직접 설치해 `hello` 앱을 실행합니다. "앱 하나를 돌리려면 무엇을 준비해야 하는지"를 손으로 겪어 보는 실습입니다. 03장에서 이 경험을 컨테이너와 비교하고, 실습 7에서 같은 일을 Dockerfile로 합니다. (교안 02장)

**필요한 것**: 서버 VM 터미널. 3·4단계에서 터미널 두 개를 씁니다.

(Node.js = 자바스크립트로 만든 앱을 실행하는 프로그램. npm = Node.js용 라이브러리를 받아 주는 도구. 라이브러리 = 남이 만들어 둔 코드 묶음)

> **바로 가기** · [1. 실습 저장소 받기](#1단계-실습-저장소-받기) · [2. Node.js 설치](#2단계-nodejs-설치) · [3. 라이브러리 받고 실행 — 터미널 1](#3단계-라이브러리-받고-실행--터미널-1) · [4. 요청 보내기 — 터미널 2](#4단계-요청-보내기--터미널-2) · [5. 앱 끄기](#5단계-앱-끄기) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 실습 저장소 받기

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

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `fatal: destination path 'ktcloud-cloud-native-lab' already exists and is not an empty directory.` | 이미 받아 둔 폴더가 있음(전에 한 번 받았음) | 다시 받을 필요 없습니다. 그대로 `cd ~/ktcloud-cloud-native-lab/lab/docker/hello`부터 이어 갑니다. 최신 내용으로 맞추려면 아래 `git pull` |
| `bash: cd: …: No such file or directory` | 폴더 이름 오타, 또는 홈 폴더가 아닌 곳에서 clone함 | `cd ~` 후 `ls` → `ktcloud-cloud-native-lab`이 보이는지 확인. 안 보이면 `cd ~`에서 clone을 다시 |
| `ls`에 파일이 다르게 나옴 | 다른 폴더에 있음 | `pwd`(지금 위치 보기)로 확인 → `/home/lab/ktcloud-cloud-native-lab/lab/docker/hello`여야 함 |

</details>

이미 받아 둔 저장소를 최신으로 맞추기:

```bash
cd ~/ktcloud-cloud-native-lab
git pull
# Already up to date.
```

- `git pull` = GitHub의 바뀐 내용을 받아 옴. `Already up to date.` = 이미 최신이라 받을 것이 없음

## 2단계. Node.js 설치

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

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `E:`로 시작하는 줄 | 설치 실패 | 1~2분 뒤 두 명령(`update`, `install`)을 다시 실행. 그래도 같으면 `E:` 줄을 복사해 질문 |
| `node: command not found` | 설치가 끝나지 않음 | 위 `install` 명령을 다시 실행하고 마지막에 오류가 없는지 확인 |

</details>

## 3단계. 라이브러리 받고 실행 — 터미널 1

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

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `npm ERR! enoent ENOENT: no such file or directory, open '…/package.json'` | `hello` 폴더가 아닌 곳에서 실행 | `cd ~/ktcloud-cloud-native-lab/lab/docker/hello` 후 다시 |
| `Error: Cannot find module '…/app.js'` | `hello` 폴더가 아닌 곳에서 실행 | 위와 같음 |

</details>

## 4단계. 요청 보내기 — 터미널 2

터미널을 하나 더 엽니다([시작하기 전에 7](./00-시작하기-전에.md#7-터미널-두-개-여는-법)). 새 터미널은 어느 폴더에서든 됩니다.

```bash
curl localhost:3000          # hello, docker
```

**이렇게 나오면 성공**: `hello, docker`. 앱이 보낸 응답입니다.

## 5단계. 앱 끄기

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

## 끝났는지 확인
- ☐ `node -v`에 `v18.19.1`이 나온다
- ☐ `node app.js`를 띄운 동안 `curl localhost:3000`에 `hello, docker`가 나왔다
- ☐ Ctrl+C로 끈 뒤에는 `Failed to connect`가 나왔다

## 정리
- 앱은 Ctrl+C로 끄면 끝입니다
- 설치한 Node.js는 **지우지 말고 둡니다**. 실습 6에서 VM의 `node -v`와 컨테이너의 `node -v`를 비교합니다. (과목이 끝난 뒤 지우려면 `sudo apt-get remove -y nodejs npm && sudo apt-get autoremove -y`)
- `~/ktcloud-cloud-native-lab` 폴더는 이 과목 내내 씁니다. **지우지 마세요**

## 확인 문제
1. 앱이 쓰는 포트는 환경변수 `PORT`로 바꿀 수 있습니다. 터미널 1에서 `PORT=3001 node app.js`로 실행하고, 터미널 2에서 `curl localhost:3001`과 `curl localhost:3000`의 결과를 각각 확인하세요.
2. 앱을 켜 둔 채 nano로 `app.js`의 `hello, docker`를 `hello, node`로 바꿔 저장하고 `curl localhost:3001`을 해 보세요. 바뀌었나요? 앱을 Ctrl+C로 끄고 다시 실행한 뒤에는 어떤가요? 확인이 끝나면 문구를 **`hello, docker`로 되돌리고** 앱을 끕니다(실습 7에서 이 폴더를 그대로 씁니다).

> nano 사용법(다시): `nano app.js`로 열기 → 화살표로 `hello, docker`가 있는 줄로 이동 → 고치기 → **Ctrl+O → Enter**(저장) → **Ctrl+X**(나가기). 앱이 켜진 터미널 1이 아니라 터미널 2에서 엽니다(터미널 2는 `cd ~/ktcloud-cloud-native-lab/lab/docker/hello` 먼저).
