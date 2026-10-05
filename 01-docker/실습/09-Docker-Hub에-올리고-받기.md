[← 실습 8](./08-빌드-캐시와-COPY-순서.md) · [목차](../Docker-실습.md) · [실습 10 →](./10-볼륨-컨테이너를-지워도-남는-데이터.md)

# 실습 9. Docker Hub에 올리고 받기

**무엇을 하나요**: 실습 7에서 만든 `hello:v2` 이미지를 내 Docker Hub(인터넷의 이미지 창고, 레지스트리) 계정에 올리고(push), 내 VM에서 지운 뒤 다시 받아(pull) 실행합니다. 옆 사람의 이미지도 받아 실행해 봅니다. 이미지를 한 번 올려 두면 어느 컴퓨터에서든 같은 앱을 받아 실행할 수 있다는 것을 확인합니다. (교안 06장)

**필요한 것**: 실습 7의 `hello:v2` 이미지, Docker Hub 계정(없으면 0단계에서 만듦).

아래 `<아이디>`는 본인 Docker Hub 아이디로 바꿉니다(예: `kim123`). 꺾쇠(`<` `>`)도 지웁니다.

> **바로 가기** · [0. Docker Hub 가입 (계정이 있으면 건너뜀)](#0단계-docker-hub-가입-계정이-있으면-건너뜀) · [1. 로그인](#1단계-로그인) · [2. 이름 붙이기(tag) → 올리기(push)](#2단계-이름-붙이기tag--올리기push) · [3. 지우고 다시 받아 실행](#3단계-지우고-다시-받아-실행) · [4. 옆 사람 이미지 받아 보기](#4단계-옆-사람-이미지-받아-보기) · [Docker Hub 로그인이 막히면 — 연습용 레지스트리](#docker-hub-로그인이-막히면--연습용-레지스트리) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 0단계. Docker Hub 가입 (계정이 있으면 건너뜀)

내 노트북 브라우저에서 합니다.

1. https://hub.docker.com 에 들어갑니다
2. **Sign up**(가입)을 누릅니다
3. 이메일, **아이디(Username)**, 비밀번호를 정합니다. Google·GitHub 계정으로 가입해도 됩니다
   - 아이디는 **영어 소문자와 숫자**로 정합니다. 이미지 이름 맨 앞에 붙으므로(`kim123/hello`) 짧고 쉬운 것이 좋습니다
4. 가입한 이메일로 온 **인증 메일**을 열어 확인 버튼을 누릅니다
5. Docker Hub에 로그인되면 끝입니다. 오른쪽 위 프로필에서 내 아이디를 확인해 둡니다

## 1단계. 로그인

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

## 2단계. 이름 붙이기(tag) → 올리기(push)

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

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `push access denied, repository does not exist or may require authorization: server message: insufficient_scope: authorization failed` | 로그인을 안 했거나, 이름 앞의 `<아이디>/`가 빠졌거나 틀림 | `docker login`을 다시 하고, `docker tag`의 아이디가 Docker Hub 아이디와 같은지 확인 |
| `bash: 아이디: No such file or directory` | `<아이디>`를 본인 아이디로 바꾸지 않고 꺾쇠째 붙여 넣음 | `kim123/hello:v2`처럼 꺾쇠 없이 본인 아이디로 바꿔서 |

</details>

## 3단계. 지우고 다시 받아 실행

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

## 4단계. 옆 사람 이미지 받아 보기

옆 사람의 Docker Hub 아이디를 물어 받아 실행합니다. 공개 저장소는 로그인 없이도 받을 수 있습니다.

```bash
docker run --rm -d --name friend -p 8012:3000 <옆사람아이디>/hello:v2
curl localhost:8012         # hello, 옆사람이름
docker rm -f friend
```

**이렇게 나오면 성공**: `hello, 옆사람이름` — 옆 사람이 실습 7에서 넣은 이름이 나옵니다.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `failed to resolve reference "docker.io/…/hello:v2": … not found` | 그런 이미지가 없음 — 옆 사람 아이디 오타, 또는 옆 사람이 아직 push 전 | 아이디 확인, 옆 사람이 2단계를 끝냈는지 확인 |

</details>

## Docker Hub 로그인이 막히면 — 연습용 레지스트리

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

## 끝났는지 확인
- ☐ Docker Hub 웹에서 내 `hello` 저장소에 `v2`가 보인다 (연습용 레지스트리를 썼다면 `_catalog`에 `hello`)
- ☐ 받아서 실행한 `curl localhost:8002`에 내 이름이 나온다

## 정리
확인 문제까지 끝났으면, 실습 7부터 켜 둔 컨테이너는 이제 지워도 됩니다. 이미지(`hello:v1`, `hello:v2`)는 두어도 됩니다.

```bash
docker rm -f hello hello2 from-hub
```

- 연습용 레지스트리를 띄웠다면 `docker rm -f reg`도 함께
- 실습이 끝나면 `docker logout`으로 VM에 저장된 로그인 정보를 지울 수 있습니다(확인 문제 1을 한 뒤에)

## 확인 문제
1. `hello:v1`에도 `<아이디>/hello:v1` 이름을 붙여 올리세요. Docker Hub 웹의 Tags 탭에 태그가 몇 개 보이나요?
2. 이미지를 공유할 때 `docker push`로 올리는 것은 이미지일까요, 컨테이너일까요? `from-hub` 컨테이너 안에서 바꾼 파일은 다른 사람에게 전달될까요?
