[← 실습 7](./07-첫-Dockerfile.md) · [목차](../Docker-실습.md) · [실습 9 →](./09-Docker-Hub에-올리고-받기.md)

# 실습 8. 빌드 캐시와 COPY 순서

**무엇을 하나요**: Docker가 바뀌지 않은 줄은 저장해 둔 결과(**캐시**)를 다시 쓴다는 것을 보고, Dockerfile 줄 순서를 바꿔 오래 걸리는 `npm install`을 캐시로 건너뛰게 만듭니다. 빌드를 빠르게 하는 가장 기본적인 방법입니다. (교안 05장)

**필요한 것**: 실습 7의 `hello` 폴더와 `Dockerfile`.

> **바로 가기** · [1. 아무것도 안 바꾸고 다시 빌드](#1단계-아무것도-안-바꾸고-다시-빌드) · [2. app.js만 고치고 다시 빌드](#2단계-appjs만-고치고-다시-빌드) · [3. 순서 바꾸기](#3단계-순서-바꾸기) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 아무것도 안 바꾸고 다시 빌드

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

## 2단계. app.js만 고치고 다시 빌드

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

## 3단계. 순서 바꾸기

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

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 두 번째 빌드에서도 `[4/5] RUN npm install`에 `CACHED`가 없음 | Dockerfile 순서가 위와 다름(`COPY . ./`가 `RUN npm install`보다 위) | `cat Dockerfile`로 확인하고 nano로 고친 뒤, 위 세 줄을 다시 |
| `[2/4]`처럼 분모가 4 | Dockerfile이 저장되지 않음(아직 6줄) | nano에서 Ctrl+O → **Enter**를 눌렀는지 확인 |

</details>

## 끝났는지 확인
- ☐ 순서를 바꾼 Dockerfile(7줄)로 `app.js`만 고쳐 빌드했을 때 `CACHED [4/5] RUN npm install`이 보였다

## 정리
- 지울 것은 없습니다. `hello`·`hello2` 컨테이너는 실습 9까지 켜 둡니다

## 확인 문제
1. 순서를 바꾼 Dockerfile로 아무것도 고치지 않고 다시 빌드하면 `CACHED`가 붙는 줄은 몇 개인가요?
2. 순서를 바꾼 Dockerfile에서 `package.json`을 고치면(예: 라이브러리를 하나 추가) `npm install`은 캐시를 쓸까요, 다시 실행될까요? 이유를 한 줄로 적으세요. (실제로 고치지 않아도 됩니다)
