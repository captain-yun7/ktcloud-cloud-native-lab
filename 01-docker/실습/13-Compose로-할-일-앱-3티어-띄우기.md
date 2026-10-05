[← 실습 12](./12-네트워크-API와-DB-연결.md) · [목차](../Docker-실습.md) · [자주 쓴 명령과 오류 →](./99-자주-쓴-명령과-오류.md)

# 실습 13. Compose로 할 일 앱(3티어) 띄우기

**무엇을 하나요**: 화면(web) · API(api) · DB(db) 세 컨테이너를 `compose.yaml` 파일 하나에 적고, 명령 한 줄로 띄우고 내립니다. 실습 12에서 긴 명령 여러 줄로 하던 일을 파일로 정리하는 것입니다. (3티어 = 화면·API·DB 세 층으로 나눈 앱 구조) (교안 09장)

**필요한 것**: 실습 3에서 받은 저장소의 `lab/docker/todo` 폴더. 실습 12의 컨테이너는 지운 상태.

> **바로 가기** · [1. 폴더 둘러보기](#1단계-폴더-둘러보기) · [2. compose.yaml 쓰기](#2단계-composeyaml-쓰기) · [3. 문법 검사](#3단계-문법-검사) · [4. 띄우기](#4단계-띄우기) · [5. 화면과 API 확인](#5단계-화면과-api-확인) · [6. 내리고 다시 올리기](#6단계-내리고-다시-올리기) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 폴더 둘러보기

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

## 2단계. compose.yaml 쓰기

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

## 3단계. 문법 검사

```bash
docker compose config -q && echo OK       # 문법 검사. 오류가 있으면 줄 번호를 알려 줌
```

**이 명령은**: `docker compose config -q` = `compose.yaml`을 읽어 문법만 검사(`-q` = 문제가 없으면 조용히). 문제가 없으면 `&&` 뒤의 `echo OK`가 실행됩니다.

**이렇게 나오면 성공**: `OK`

<details><summary><b>이렇게 나오면? — 오류 문구의 `L3.C1`은 "3번째 줄(Line) 1번째 칸(Column)"이라는 뜻입니다. `nano compose.yaml`로 그 줄을 고칩니다.</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `… found character that cannot start any token` | 들여쓰기에 **탭**을 씀 | 그 줄의 탭을 지우고 스페이스로 |
| `… did not find expected key` | 들여쓰기 칸 수가 위아래 줄과 안 맞음 | 2단계 내용과 칸 수를 맞춤(가장 쉬운 방법: 파일 내용을 모두 지우고 다시 붙여 넣기) |
| `no configuration file provided: not found` | 지금 폴더에 `compose.yaml`이 없음 | `pwd`가 `…/lab/docker/todo`인지, `ls`에 `compose.yaml`이 있는지 확인 |

</details>

## 4단계. 띄우기

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

## 5단계. 화면과 API 확인

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

브라우저로 보려면 VS Code **PORTS** 탭에서 8088을 전달해 `http://localhost:8088`을 열고 할 일을 추가·삭제해 봅니다([시작하기 전에 8](./00-시작하기-전에.md#8-브라우저로-서버의-웹-페이지-보기-ports-탭)).

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `docker compose ps`에 `todo-web-1`이 없거나 `Exited` | web이 시작할 때 api를 못 찾음(api가 빌드 실패 등) | `docker compose logs web`, `docker compose logs api`의 마지막 줄을 보고 질문 |
| `port is already allocated` (8088) | 앞에서 8088을 쓰는 것을 띄워 둠 | `docker ps`로 확인해 지운 뒤 `docker compose up -d --build` 다시 |

</details>

## 6단계. 내리고 다시 올리기

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

## 끝났는지 확인
- ☐ `docker compose ps`에 서비스 3개가 `Up`이었다
- ☐ `curl localhost:8088/api/todos`로 넣은 할 일이 `down` → `up` 뒤에도 남아 있었다
- ☐ `down -v` 뒤에는 `[]`였다

## 정리
- 6단계 마지막의 `docker compose down -v`로 이미 정리됐습니다
- 확인 문제를 하려면 `docker compose up -d`로 다시 띄우고, 끝나면 `docker compose down -v`
- `compose.yaml`은 미션 2에서 모양을 참고하니 **지우지 마세요**

## 확인 문제
1. `docker compose up -d` 상태에서 `docker ps`와 `docker network ls`, `docker volume ls`를 보세요. 컨테이너·네트워크·볼륨 이름은 어떤 규칙으로 붙었나요?
2. `compose.yaml`에서 web의 포트를 `"8089:80"`으로 바꾸고 `docker compose up -d`를 다시 실행하세요. 세 서비스 가운데 어느 것이 다시 만들어지나요? `curl localhost:8089`로 확인한 뒤 8088로 되돌립니다.
