[← 실습 1](./01-빈틈-세-개-직접-보기-root-열린-네트워크-토큰.md) · [목차](../클라우드-보안-실습.md) · [실습 3 →](./03-root-아닌-이미지-만들기-todo-api-safe.md)

# 실습 2. Trivy로 todo-api 이미지 스캔

**무엇을 하나요**: 먼저 스캔 **없이** `docker images`·`docker history`로 이미지를 보면 크기와 층만 나오고 취약점 개수는 보이지 않는다는 것을 확인합니다. 그다음 취약점 스캐너 Trivy로 내가 만든 `todo-api:v1` 이미지를 검사합니다. 결과 표를 읽고, 취약점이 **내 코드가 아니라 바탕 이미지에서** 왔다는 것을 확인한 뒤, 다른 바탕 이미지와 숫자를 비교하고, 마지막으로 취약점이 있으면 **실패로 끝나게** 해 봅니다. (교안 03장)

**필요한 것**: trivy([시작하기 전에 3](./00-시작하기-전에.md#3-보안-도구-설치--make-tools)), 이미지 `todo-api:v1`(시작하기 전에 4).

> **바로 가기** · [1. 스캔 없이 보고, 첫 스캔](#1단계-스캔-없이-보고-첫-스캔) · [2. 결과 표 읽기](#2단계-결과-표-읽기) · [3. 취약점은 어디서 왔나](#3단계-취약점은-어디서-왔나) · [4. 다른 바탕 이미지와 비교](#4단계-다른-바탕-이미지와-비교) · [5. 스캔 결과로 멈추기](#5단계-스캔-결과로-멈추기) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 스캔 없이 보고, 첫 스캔

### 가. 스캔 없이 보기

```bash
cd ~/sec
docker images todo-api:v1
docker history todo-api:v1
```

**이 명령은**: `docker images 이름` = 이미지 크기. `docker history 이름` = 이미지를 만든 층(Dockerfile 한 줄 = 한 층)과 층마다 크기.

**이렇게 나오면 성공**

```
IMAGE         ID             DISK USAGE   CONTENT SIZE   EXTRA
todo-api:v1   148d0ce6c9b4        251MB         62.9MB
IMAGE          CREATED       CREATED BY                                      SIZE      COMMENT
148d0ce6c9b4   2 days ago    CMD ["node" "app.js"]                           0B        buildkit.dockerfile.v0
<missing>      2 days ago    EXPOSE [3000/tcp]                               0B        buildkit.dockerfile.v0
<missing>      2 days ago    COPY . . # buildkit                             61.4kB    buildkit.dockerfile.v0
<missing>      6 days ago    RUN /bin/sh -c npm ci --omit=dev # buildkit     10.9MB    buildkit.dockerfile.v0
…
<missing>      13 days ago   RUN /bin/sh -c addgroup -g 1000 node     && …   162MB     buildkit.dockerfile.v0
…
<missing>      2 weeks ago   ADD alpine-minirootfs-3.24.2-x86_64.tar.gz /…   9.08MB    buildkit.dockerfile.v0
```

- 크기와 만든 명령은 보이지만 **어느 패키지가 어떤 버전인지, 그중 취약한 것이 있는지는 어디에도 없습니다.** 가장 큰 층(162MB)은 바탕 이미지가 Node와 npm을 설치한 층인데, 안에 무엇이 들었는지는 이 화면으로 알 수 없습니다. `ID`·`CREATED` 값은 사람마다 다릅니다

### 나. 첫 스캔

```bash
trivy image --severity HIGH,CRITICAL --table-mode detailed todo-api:v1
```

**이 명령은**
- `trivy image 이미지` = 이미지 안에 든 패키지와 버전을 목록으로 만들고, **알려진 취약점 DB**와 비교
- `--severity HIGH,CRITICAL` = 심각한 것(HIGH·CRITICAL)만
- `--table-mode detailed` = 결과 중 취약점 표만 보여 줌(빼면 맨 앞에 "검사한 파일 목록" 표가 수백 줄 붙음)
- 처음 한 번은 취약점 DB를 내려받느라 수십 초 걸립니다(`Downloading vulnerability DB` 줄)

**이렇게 나오면 성공**: `INFO` 줄 몇 개 뒤에 표 하나

```
… INFO  Detected OS  family="alpine" version="3.24.2"
… INFO  [alpine] Detecting vulnerabilities...  os_version="3.24" repository="3.24" pkg_num=18
… INFO  [node-pkg] Detecting vulnerabilities...

Node.js (node-pkg)
==================
Total: 11 (HIGH: 11, CRITICAL: 0)

┌─────────────────────────────────────┬─────────────────┬──────────┬──────────┬───────────────────┬──────────────────────────────┬──────────────────────────────…
│               Library               │  Vulnerability  │ Severity │  Status  │ Installed Version │        Fixed Version         │                           Title
├─────────────────────────────────────┼─────────────────┼──────────┼──────────┼───────────────────┼──────────────────────────────┼──────────────────────────────…
│ brace-expansion (package.json)      │ CVE-2026-102276 │ HIGH     │ fixed    │ 2.0.2             │ 5.0.10, 3.0.7, 2.1.5, 1.1.19 │ brace-expansion: …
…
```

- 숫자(`Total: 11`)는 취약점 DB에 따라 조금 다릅니다
- `alpine` 줄은 있는데 alpine 표가 없으면 **운영체제 패키지에는 HIGH·CRITICAL이 0건**이라는 뜻입니다. 0건이면 표도 `Total` 줄도 나오지 않습니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 한동안 아무 출력이 없음 | 처음 DB를 내려받는 중 | 기다림(1분 안팎) |
| `unable to find the specified image "todo-api:v1"` | VM 도커에 이미지가 없음 | 시작하기 전에 4 |

</details>

## 2단계. 결과 표 읽기

1단계 표의 칸을 읽는 법입니다.

| 칸 | 뜻 | 예 |
|---|---|---|
| `Library` | 취약점이 있는 패키지 이름 | `brace-expansion` |
| `Vulnerability` | 취약점 번호(CVE) | `CVE-2026-102276` |
| `Severity` | 심각도 | `HIGH` |
| `Status` | `fixed` = 고친 버전이 나옴, `affected` = 아직 고친 버전 없음 | `fixed` |
| `Installed Version` | 이미지에 들어 있는 버전 | `2.0.2` |
| `Fixed Version` | 고친 버전 — 이 버전 이상으로 올리면 사라짐 | `2.1.5` … |
| `Title` | 무슨 문제인지 한 줄, 아래 주소에 자세한 설명 | `Denial of Service …` |

합계 줄만 보고 싶으면 `grep Total`을 붙입니다.

```bash
trivy image --severity HIGH,CRITICAL --table-mode detailed todo-api:v1 | grep Total
```

**이렇게 나오면 성공**

```
Total: 11 (HIGH: 11, CRITICAL: 0)
```

- 표의 `Library`에 우리 앱이 쓰는 `express`·`pg`는 없습니다. 다음 단계에서 이 11개가 어디서 왔는지 찾습니다

## 3단계. 취약점은 어디서 왔나

```bash
trivy image --severity HIGH,CRITICAL --table-mode detailed node:22-alpine | grep Total
trivy image --quiet --severity HIGH,CRITICAL --format json todo-api:v1 | grep '"PkgPath"' | sort | uniq -c
```

**이 명령은**
- 첫 줄 = todo-api의 **바탕 이미지**(Dockerfile의 `FROM node:22-alpine`)만 따로 스캔
- 둘째 줄 = 결과를 JSON(프로그램이 읽는 형식)으로 받아, 취약한 패키지가 **이미지 안 어느 경로에** 있는지(`PkgPath`)만 뽑아 셈. `--quiet` = INFO 줄 없이, `sort | uniq -c` = 같은 줄을 묶어 개수와 함께

**이렇게 나오면 성공**

```
Total: 11 (HIGH: 11, CRITICAL: 0)
      5           "PkgPath": "usr/local/lib/node_modules/npm/node_modules/brace-expansion/package.json",
      1           "PkgPath": "usr/local/lib/node_modules/npm/node_modules/http-cache-semantics/package.json",
      1           "PkgPath": "usr/local/lib/node_modules/npm/node_modules/ip-address/package.json",
      1           "PkgPath": "usr/local/lib/node_modules/npm/node_modules/@npmcli/metavuln-calculator/node_modules/pacote/package.json",
      1           "PkgPath": "usr/local/lib/node_modules/npm/node_modules/pacote/package.json",
      1           "PkgPath": "usr/local/lib/node_modules/npm/node_modules/picomatch/package.json",
      1           "PkgPath": "usr/local/lib/node_modules/npm/node_modules/sigstore/package.json",
```

**왜 그런가**
- 바탕 이미지 `node:22-alpine`만 스캔해도 **같은 11개**입니다. 우리가 쓴 코드와 라이브러리(`/app/node_modules`의 express·pg)에는 0건이고, 11개 모두 바탕 이미지에 딸려 온 것입니다
- 경로가 전부 `usr/local/lib/node_modules/npm/…` — 패키지 설치 도구 **npm 안의 부품**입니다. npm은 이미지를 **만들 때**(`RUN npm ci`)만 쓰고, 앱이 **돌 때**(`node app.js`)는 쓰지 않습니다. 실습 3에서 이 점을 이용합니다

## 4단계. 다른 바탕 이미지와 비교

```bash
trivy image --severity HIGH,CRITICAL --table-mode detailed node:24-alpine | grep Total
trivy image --severity HIGH,CRITICAL --table-mode detailed node:22-slim | grep -E "Total|=="
```

**이 명령은**: 같은 스캔을 Node 24 버전 alpine 이미지와, 데비안 바탕의 `node:22-slim` 이미지에 함. 처음 받는 이미지는 내려받느라 잠시 걸립니다. `grep -E "Total|=="` = 합계 줄과 그 위 제목 밑줄까지.

**이렇게 나오면 성공**

```
Total: 8 (HIGH: 8, CRITICAL: 0)
===========================
Total: 57 (HIGH: 53, CRITICAL: 4)
==================
Total: 11 (HIGH: 11, CRITICAL: 0)
```

| 바탕 이미지 | HIGH·CRITICAL | 어디서 |
|---|---|---|
| `node:22-alpine` (todo-api:v1) | 11 | npm 안 |
| `node:24-alpine` | 8 | npm 안(새 버전 npm) |
| `node:22-slim` | 68 = 57(데비안 패키지, CRITICAL 4) + 11(npm) | 운영체제 + npm |

**왜 그런가**: 같은 Node 22라도 **바탕 운영체제**(alpine / 데비안)에 따라 수가 크게 다르고, 같은 alpine이라도 **버전**에 따라 다릅니다. 이름에 `slim`이 붙었다고 늘 적은 것도 아닙니다. 그래서 바탕 이미지는 **스캔해 보고 고릅니다.** `node:22-slim`은 위 제목 줄이 두 개(운영체제 표 + Node 표)라 `Total`도 두 줄입니다.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `grep Total`이 아무것도 안 보여 줌 | 취약점 0건이면 `Total` 줄이 없음 | `grep Total`을 빼고 표가 있는지 봄 |

</details>

## 5단계. 스캔 결과로 멈추기

지금까지는 사람이 표를 **눈으로 읽고** 판단했습니다. 그런데 이미지를 만들 때마다 사람이 표를 읽을 수는 없습니다. 이 단계에서는 스캔 결과를 **프로그램이 알아듣는 신호**로 바꿉니다. 그 신호가 **종료 코드**입니다.

### 가. 종료 코드란

리눅스의 모든 명령은 끝날 때 화면 출력과 별개로 **숫자 하나**를 남깁니다. 이것이 종료 코드(exit code)입니다.

| 종료 코드 | 뜻 |
|---|---|
| `0` | 성공 |
| `0`이 아닌 수(1, 2, …) | 실패 (숫자는 명령마다 실패 이유를 구분하는 데 씀) |

종료 코드는 화면에 나오지 않습니다. 바로 앞 명령의 종료 코드를 보려면 `echo $?`를 씁니다. 먼저 trivy가 아닌 평범한 명령으로 확인합니다.

```bash
ls / > /dev/null; echo $?
ls /없는폴더; echo $?
```

**이 명령은**: 있는 폴더(`/`)와 없는 폴더를 `ls`로 보고, 매번 바로 뒤에서 종료 코드를 찍습니다.

**이렇게 나오면 성공**

```
0
ls: cannot access '/없는폴더': No such file or directory
2
```

- 성공하면 `0`, 실패하면 `0`이 아닌 수(`ls`는 `2`)가 남습니다. 오류 문구는 사람이 읽는 것이고, `2`는 프로그램이 읽는 것입니다

### 나. trivy의 종료 코드

```bash
trivy image --quiet --severity HIGH,CRITICAL todo-api:v1 > /dev/null; echo $?
trivy image --quiet --severity HIGH,CRITICAL --exit-code 1 todo-api:v1 > /dev/null; echo $?
```

**이 명령은** — 같은 스캔을 두 번 하는데, 둘째 줄에만 `--exit-code 1`이 붙습니다. 조각별로 보면:

| 조각 | 뜻 |
|---|---|
| `trivy image --severity HIGH,CRITICAL todo-api:v1` | 1단계와 같은 스캔 |
| `--quiet` | `INFO` 줄과 진행 표시를 숨김 |
| `> /dev/null` | 결과 표를 **버림**. `>`는 "화면 대신 이 파일로 보내라", `/dev/null`은 "넣으면 사라지는 특수 파일". 표는 1단계에서 이미 봤고, 여기서는 종료 코드만 볼 것이라 화면을 비움 |
| `;` | 앞 명령이 성공하든 실패하든 **이어서** 다음 명령 실행 |
| `echo $?` | 바로 앞 명령(trivy)의 종료 코드를 찍음 |
| `--exit-code 1` | "찾은 취약점이 있으면 종료 코드를 `1`로 남겨라". 이 옵션이 없으면 trivy는 취약점을 찾아도 **스캔 자체는 잘 끝났으니** `0`을 남김 |

**이렇게 나오면 성공**

```
0
1
```

**왜 그런가**
- 첫 줄 `0`: HIGH가 11개 있어도 trivy 입장에서는 "검사를 끝까지 잘 마쳤다"이므로 성공입니다. 기본값의 trivy는 **알려 주기만** 합니다
- 둘째 줄 `1`: `--exit-code 1`을 붙이면 "기준(여기서는 HIGH·CRITICAL)에 걸리는 것이 하나라도 있으면 실패"로 바뀝니다. 걸리는 것이 0건이면 `--exit-code 1`이 있어도 `0`입니다(바로 아래 다의 둘째 줄)

### 다. 종료 코드로 다음 일을 멈추기

종료 코드는 **다음 명령을 할지 말지** 정하는 데 씁니다. `&&` = 앞이 성공(`0`)일 때만 뒤를 실행, `||` = 앞이 실패일 때만 뒤를 실행.

```bash
trivy image --quiet --severity HIGH,CRITICAL --exit-code 1 todo-api:v1 > /dev/null && echo "배포 계속" || echo "여기서 멈춤"
trivy image --quiet --severity CRITICAL --exit-code 1 todo-api:v1 > /dev/null && echo "배포 계속" || echo "여기서 멈춤"
```

**이 명령은**: 실제 배포 대신 `echo`로 "배포 계속"·"여기서 멈춤"을 찍어 흉내 냅니다. 둘째 줄은 기준을 `CRITICAL`만으로 바꾼 것입니다.

**이렇게 나오면 성공**

```
여기서 멈춤
배포 계속
```

**왜 그런가**: todo-api:v1은 HIGH 11개, CRITICAL 0개입니다. 기준이 `HIGH,CRITICAL`이면 걸리는 것이 있어 `1` → "멈춤", 기준이 `CRITICAL`만이면 걸리는 것이 없어 `0` → "계속". **어디까지를 막을지는 `--severity`로 정하는 팀의 판단**입니다.

| | `--exit-code` 없음 | `--exit-code 1` |
|---|---|---|
| HIGH 11개가 있어도 | `0` — 성공으로 끝남 | `1` — 실패로 끝남 |
| 뒤에 `&& 배포`를 붙이면 | 배포됨 | 배포 안 됨 |
| 자동 빌드(CI)에 넣으면 | 표만 찍고 다음 단계(배포)로 넘어감 | 그 단계가 실패로 표시되고 파이프라인이 멈춤 |

자동 빌드 도구(GitHub Actions 등)도 이 방식으로 움직입니다. 단계마다 명령을 실행하고, 종료 코드가 `0`이 아니면 그 단계를 실패로 보고 뒤 단계(이미지 올리기·배포)를 실행하지 않습니다. CI/CD 과목에서 이 스캔을 파이프라인에 넣습니다.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `--exit-code 1`인데 `echo $?`가 `0` | `> /dev/null` 대신 `\| grep Total`처럼 파이프(`\|`)를 붙임 → `$?`는 **마지막 명령(grep)** 의 종료 코드 | 위 명령처럼 `> /dev/null`로 버리고 `echo $?` |
| `echo $?`가 엉뚱한 값 | trivy와 `echo $?` 사이에 다른 명령을 실행함 | `$?`는 **바로 앞** 명령 것. 같은 줄에 `;`로 붙여 실행 |
| 표가 화면 가득 나옴 | `> /dev/null`을 빠뜨림 | 결과는 같음. 마지막 줄 숫자만 보면 됨 |

</details>

## 끝났는지 확인

- ☐ `todo-api:v1`의 `Total`(약 11)을 봤다
- ☐ 취약점 경로가 모두 `usr/local/lib/node_modules/npm/…`인 것을 봤다
- ☐ 바탕 이미지 세 개의 숫자를 비교했다
- ☐ `docker history`로는 취약점이 안 보이는 것을 먼저 봤다
- ☐ `--exit-code 1`을 붙이면 `echo $?`가 `1`
- ☐ `&& … || …`로 기준을 `HIGH,CRITICAL`이면 "여기서 멈춤", `CRITICAL`이면 "배포 계속"을 봤다

## 정리

지울 것은 없습니다. 내려받은 `node:24-alpine`·`node:22-slim`은 지워도 됩니다(`docker rmi node:24-alpine node:22-slim`).

## 확인 문제

1. todo의 화면 이미지 `todo-web:v1`도 HIGH·CRITICAL로 스캔하세요. `Total`은 몇이고, 표 제목(`=====` 위 줄)을 보면 취약점이 어디서 왔나요?
2. 5단계 다의 두 줄에서 `todo-api:v1`만 `node:22-slim`으로 바꿔 실행하면 각각 무엇이 나오나요? `todo-api:v1`과 결과가 왜 다른가요? (4단계 표를 참고하세요)
