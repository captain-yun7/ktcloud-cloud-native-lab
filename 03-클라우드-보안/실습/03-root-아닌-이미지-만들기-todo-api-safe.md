[← 실습 2](./02-Trivy로-todo-api-이미지-스캔.md) · [목차](../클라우드-보안-실습.md) · [실습 4 →](./04-SecurityContext-api에-하나씩-켜기.md)

# 실습 3. root 아닌 이미지 만들기 — todo-api:safe

**무엇을 하나요**: todo api의 Dockerfile을 고쳐 **root가 아닌 사용자로 돌고**, 실행에 필요 없는 npm을 지운 이미지 `todo-api:safe`를 만듭니다. 설정 점검(`trivy config`)·실행 사용자·취약점 수를 `todo-api:v1`과 비교하고, 클러스터에 넣어 둡니다(실습 4에서 씀). (교안 04장)

**필요한 것**: trivy, Docker, 실습 2의 결과(취약점은 npm 안).

> **바로 가기** · [1. api 폴더 복사해 오기](#1단계-api-폴더-복사해-오기) · [2. Dockerfile.safe 쓰기](#2단계-dockerfilesafe-쓰기) · [3. 설정 점검 — trivy config](#3단계-설정-점검--trivy-config) · [4. 빌드하고 사용자·취약점 비교](#4단계-빌드하고-사용자취약점-비교) · [5. 클러스터에 넣기](#5단계-클러스터에-넣기) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. api 폴더 복사해 오기

```bash
cp -r ~/ktcloud-cloud-native-lab/lab/docker/todo/api ~/sec/todo-api
cd ~/sec/todo-api
ls
cat Dockerfile
```

**이 명령은**: Docker 과목에서 만든 todo api 소스를 작업 폴더로 복사(`cp -r` = 폴더째)하고 지금 Dockerfile을 봄. 원본은 그대로 둡니다.

**이렇게 나오면 성공**

```
app.js  Dockerfile  package.json  package-lock.json
FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY . .
EXPOSE 3000
CMD ["node", "app.js"]
```

## 2단계. Dockerfile.safe 쓰기

같은 폴더에 새 파일을 만듭니다. 원래 `Dockerfile`은 비교용으로 그대로 둡니다.

```bash
nano Dockerfile.safe
```

```dockerfile
FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx
COPY . .
USER 1000
EXPOSE 3000
HEALTHCHECK CMD wget -q -O /dev/null http://127.0.0.1:3000/api/health || exit 1
CMD ["node", "app.js"]
```

**이 파일은** — 원래 Dockerfile과 달라진 줄은 셋입니다.

| 줄 | 뜻 |
|---|---|
| `RUN npm ci --omit=dev && rm -rf …npm …npm …npx` | 라이브러리를 설치한 **바로 뒤에** npm 자체(`/usr/local/lib/node_modules/npm`)와 실행 파일 `npm`·`npx`를 지움. 실습 2의 취약점 11개가 모두 이 폴더 안에 있었음. 앱이 돌 때는 `node`만 있으면 됨 |
| `USER 1000` | 이 줄 아래부터, 그리고 컨테이너가 돌 때 **1000번 사용자**로 실행. node 이미지에 미리 있는 사용자 `node`의 번호. 이름 대신 **숫자로** 적음(쿠버네티스가 root가 아닌지 숫자로 확인함 — 실습 4) |
| `HEALTHCHECK CMD wget … /api/health \|\| exit 1` | 컨테이너가 정상인지 주기적으로 검사하는 명령(`/api/health`는 todo api에 이미 있는 주소). 쿠버네티스에서는 Probe가 이 일을 함(Kubernetes 실습 9) |

- 1000번 사용자는 1024보다 작은 포트를 열 수 없지만, todo api는 3000번이라 그대로 됩니다

## 3단계. 설정 점검 — trivy config

```bash
trivy config .
```

**이 명령은**: 지금 폴더(`.`)의 Dockerfile들을 **글자 그대로** 읽어 `USER`가 없어 root로 도는 것, `HEALTHCHECK`가 없는 것 같은 설정 문제를 찾음(이미지를 만들지 않고 파일만 봄).

**이렇게 나오면 성공**: 요약 표에서 `Dockerfile`은 2, `Dockerfile.safe`는 0

```
┌─────────────────┬────────────┬───────────────────┐
│     Target      │    Type    │ Misconfigurations │
├─────────────────┼────────────┼───────────────────┤
│ Dockerfile      │ dockerfile │         2         │
├─────────────────┼────────────┼───────────────────┤
│ Dockerfile.safe │ dockerfile │         0         │
└─────────────────┴────────────┴───────────────────┘
…
Dockerfile (dockerfile)
=======================
Tests: 27 (SUCCESSES: 25, FAILURES: 2)
Failures: 2 (UNKNOWN: 0, LOW: 1, MEDIUM: 0, HIGH: 1, CRITICAL: 0)

DS-0002 (HIGH): Specify at least 1 USER command in Dockerfile with non-root user as argument
…
DS-0026 (LOW): Add HEALTHCHECK instruction in your Dockerfile
```

- `DS-0002`(HIGH) = `USER`가 없어 root로 돎, `DS-0026`(LOW) = HEALTHCHECK 없음. `Dockerfile.safe`는 둘 다 고쳤으니 0입니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `Dockerfile.safe`가 표에 없음 | 파일 이름 오타(`dockerfile.safe` 등) | `ls`로 이름 확인. trivy는 `Dockerfile`로 시작하는 이름을 찾음 |
| `Dockerfile.safe`에 `DS-0002`가 남음 | `USER` 줄이 없거나 `USER root`·`USER 0` | 2단계 파일과 비교 |

</details>

## 4단계. 빌드하고 사용자·취약점 비교

```bash
docker build -f Dockerfile.safe -t todo-api:safe .
docker run --rm --entrypoint id todo-api:v1
docker run --rm --entrypoint id todo-api:safe
trivy image --severity HIGH,CRITICAL --table-mode detailed todo-api:safe
```

**이 명령은**
- `docker build -f Dockerfile.safe -t todo-api:safe .` = `-f` = 쓸 Dockerfile 이름(기본은 `Dockerfile`). 새 이미지 이름은 `todo-api:safe`
- `docker run --rm --entrypoint id 이미지` = 앱 대신 `id` 명령만 실행하고 컨테이너를 바로 지움(`--rm`) → 그 이미지가 누구로 도는지
- 마지막 줄 = 실습 2와 같은 스캔

**이렇게 나오면 성공**

```
uid=0(root) gid=0(root) groups=0(root),0(root),1(bin),2(daemon),3(sys),4(adm),6(disk),10(wheel),11(floppy),20(dialout),26(tape),27(video)
uid=1000(node) gid=1000(node) groups=1000(node),1000(node)
… INFO  [node-pkg] Detecting vulnerabilities...
```

- 마지막 스캔은 `INFO` 줄만 있고 **표가 하나도 없습니다** = HIGH·CRITICAL **0건**(실습 2의 11건이 모두 npm 안에 있었으니)

| 이미지 | 실행 사용자 | HIGH·CRITICAL | trivy config |
|---|---|---|---|
| `todo-api:v1` | 0 (root) | 11 | 경고 2 (DS-0002 HIGH · DS-0026 LOW) |
| `todo-api:safe` | 1000 (node) | 0 | 경고 0 |

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 빌드 중 `/bin/sh: npm: not found` … `exit code: 127` | `rm -rf`를 `npm ci` **앞에** 적음 | `npm ci --omit=dev && rm -rf …` 순서로 |
| 마지막 스캔에 표가 그대로 11개 | `rm -rf` 경로 오타 | `docker run --rm --entrypoint ls todo-api:safe /usr/local/lib/node_modules` — `npm`이 없어야 함 |

</details>

## 5단계. 클러스터에 넣기

```bash
kind load docker-image todo-api:safe --name lab
```

**이렇게 나오면 성공**: `Image: "todo-api:safe" with ID "sha256:…" not yet present on node "lab-control-plane", loading...`

- 아직 todo의 api는 `todo-api:v1` 그대로입니다. 실습 4에서 바꿉니다

## 끝났는지 확인

- ☐ `trivy config .`에서 `Dockerfile` 2, `Dockerfile.safe` 0
- ☐ `id`가 v1 `uid=0(root)`, safe `uid=1000(node)`
- ☐ `todo-api:safe` 스캔에 표가 없음(0건)
- ☐ `kind load`로 `todo-api:safe`를 넣음

## 정리

`~/sec/todo-api` 폴더와 `todo-api:safe` 이미지는 실습 4·10에서 씁니다. 지우지 마세요.

Dockerfile을 쓸 때 지킬 것을 정리하면 이렇습니다.

| 원칙 | Dockerfile에서 |
|---|---|
| root로 돌지 않기 | `USER` (숫자 UID) |
| 실행에 필요한 것만 담기 | 빌드 도구(npm 등)는 지우거나, 작은 바탕 이미지를 스캔해 보고 고르기 |
| 비밀값을 넣지 않기 | `ENV`·`ARG`에 키 금지 (이미지 기록에 남음 — 미션 1) |
| 태그 고정 | `:latest` 금지 (실습 9) |

## 확인 문제

1. `docker image inspect todo-api:safe --format '{{.Config.User}}'`와 `todo-api:v1`의 값을 비교하세요. v1의 값이 비어 있는 것은 무슨 뜻일까요?
2. `rm -rf …` 부분은 빼고 `USER 1000`만 넣은 이미지는 어떨까요? `Dockerfile.safe`를 복사해 `Dockerfile.user`를 만들고 `RUN` 줄을 원래대로(`RUN npm ci --omit=dev`) 되돌려 `todo-api:user`로 빌드한 뒤, 실행 사용자와 HIGH·CRITICAL 수를 보세요. 무엇을 알 수 있나요?
