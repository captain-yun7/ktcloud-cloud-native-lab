[← 실습 11](./11-바인드-마운트-내-폴더를-컨테이너에-연결.md) · [목차](../Docker-실습.md) · [실습 13 →](./13-Compose로-할-일-앱-3티어-띄우기.md)

# 실습 12. 네트워크 — API와 DB 연결

**무엇을 하나요**: 할 일 앱의 API 컨테이너(요청을 받아 데이터를 주고받는 서버)와 DB 컨테이너(PostgreSQL, 데이터를 저장하는 프로그램)를 따로 띄워 연결합니다. 기본 상태에서는 서로 이름을 못 찾는 것을 보고, 사용자 네트워크를 만들어 컨테이너 이름으로 연결합니다. 여러 컨테이너로 된 앱의 기본 구조입니다. (교안 08장)

**필요한 것**: 실습 3에서 받은 저장소의 `lab/docker/todo/api` 폴더.

> **바로 가기** · [1. API 이미지 빌드](#1단계-api-이미지-빌드) · [2. 그냥 띄우면 — 이름을 못 찾음](#2단계-그냥-띄우면--이름을-못-찾음) · [3. 네트워크를 만들어 같이 넣기](#3단계-네트워크를-만들어-같이-넣기) · [4. API로 할 일 넣고 보기](#4단계-api로-할-일-넣고-보기) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. API 이미지 빌드

```bash
cd ~/ktcloud-cloud-native-lab/lab/docker/todo/api
docker build -t todo-api .
```

**이렇게 나오면 성공**: 마지막 즈음 `naming to docker.io/library/todo-api`.

API는 환경변수 `DB_HOST`(DB 주소), `DB_USER`(DB 사용자), `DB_PASSWORD`(비밀번호), `DB_NAME`(DB 이름)을 읽어 DB에 접속합니다(01장의 "설정은 환경변수로"). DB가 준비될 때까지 2초 간격으로 15번 다시 시도합니다.

## 2단계. 그냥 띄우면 — 이름을 못 찾음

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

## 3단계. 네트워크를 만들어 같이 넣기

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

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `connected` 없이 `waiting …` 줄만 있음 | DB가 아직 준비 중 | 10초쯤 뒤 `docker logs api`를 다시 |
| `Error response from daemon: network with name todo-net already exists` | 네트워크를 이미 만듦 | 괜찮습니다. 다음 줄부터 이어서 |
| `Conflict. The container name "/db" …` | 2단계 컨테이너를 안 지움 | `docker rm -f db api` 후 3단계를 처음부터 |

</details>

## 4단계. API로 할 일 넣고 보기

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

## 끝났는지 확인
- ☐ `docker logs api`에 `connected to database at db`가 있다
- ☐ `curl localhost:8005/api/todos`에 넣은 할 일이 보인다

## 정리
- 확인 문제 2가 정리입니다(`db`, `api`, `todo-net` 지우기). 실습 13에서 같은 이름을 쓰지는 않지만, 같은 구성을 Compose로 다시 띄우므로 지우고 넘어갑니다
- `todo-api` 이미지는 두어도 됩니다

## 확인 문제
1. `todo-net`에 붙인 임시 컨테이너에서 `api`를 이름으로 불러 보세요: `docker run --rm --network todo-net nginx:1.29-alpine wget -qO- api:3000/api/todos`. `--network todo-net`을 빼고 실행하면 어떤 오류가 나오나요?
2. 확인이 끝나면 `docker rm -f db api`, `docker network rm todo-net`으로 정리하세요. (실습 13에서 Compose로 같은 구성을 다시 띄웁니다)
