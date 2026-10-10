[← 실습 9](./09-Kyverno-우리-규칙-만들기.md) · [목차](../클라우드-보안-실습.md) · [자주 쓴 명령과 오류 →](./99-자주-쓴-명령과-오류.md)

# 실습 10. SBOM과 서명 — 무엇이 들었나, 바뀌지 않았나

**무엇을 하나요**: 이미지에 **무엇이 들어 있는지의 목록**(SBOM, Software Bill of Materials)을 파일로 만들고, 그 파일만으로 취약점을 찾습니다. 그다음 VM 안에 연습용 레지스트리(이미지 저장소)를 띄워 `todo-api:safe`를 올리고, 서명이 **없을 때** 같은 이름으로 다른 이미지를 덮어 올리면 받는 쪽이 아무것도 모른다는 것을 본 뒤 **서명**합니다. 누군가 같은 태그로 다른 이미지를 올리면 검증이 실패하는 것을 확인합니다. (교안 10장)

**필요한 것**: 실습 3의 이미지 `todo-api:v1`·`todo-api:safe`, cosign([시작하기 전에 3](./00-시작하기-전에.md#3-보안-도구-설치--make-tools)).

> **바로 가기** · [1. SBOM 만들기](#1단계-sbom-만들기) · [2. SBOM으로 취약점 찾기](#2단계-sbom으로-취약점-찾기) · [3. 연습용 레지스트리에 올리기 — 서명 없이 바꿔치기](#3단계-연습용-레지스트리에-올리기--서명-없이-바꿔치기) · [4. 키 만들고 서명하기](#4단계-키-만들고-서명하기) · [5. 검증하기](#5단계-검증하기) · [6. 바꿔치기하고 다시 검증](#6단계-바꿔치기하고-다시-검증) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. SBOM 만들기

```bash
cd ~/sec
trivy image --format cyclonedx -o api-v1.cdx.json todo-api:v1
python3 -c "import json;print(len(json.load(open('api-v1.cdx.json'))['components']))"
python3 -c "import json;[print(c['name'],c.get('version')) for c in json.load(open('api-v1.cdx.json'))['components'] if c['name'] in ('express','pg','npm')]"
```

**이 명령은**
- `--format cyclonedx -o 파일` = 이미지의 구성요소 목록을 **CycloneDX 형식**(SBOM 표준 형식 중 하나, JSON) 파일로 저장. 취약점은 찾지 않고 목록만 만듦
- 둘째 줄 = 그 파일에 구성요소가 몇 개인지 셈(파이썬 한 줄, 그대로 붙여 넣기)
- 셋째 줄 = 그중 `express`·`pg`·`npm`의 이름과 버전만

**이렇게 나오면 성공**

```
… INFO  "--format cyclonedx" disables security scanning. Specify "--scanners vuln" explicitly if you want to include vulnerabilities in the "cyclonedx" report.
300
express 5.1.0
npm 10.9.9
pg 8.16.3
```

- 운영체제 패키지, Node, npm과 그 부품, 우리 앱의 라이브러리까지 **300개**가 목록에 있습니다. 예를 들어 새 express 취약점이 발표되면, 이미지를 다시 받지 않고 **이 목록만 보고** 영향 여부를 판단할 수 있습니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `unable to find the specified image "todo-api:v1"` | 이미지 없음 | 시작하기 전에 4 |
| `FileNotFoundError: … 'api-v1.cdx.json'` | `~/sec`가 아닌 곳, 또는 첫 줄이 실패 | `cd ~/sec` 후 첫 줄부터 |

</details>

## 2단계. SBOM으로 취약점 찾기

```bash
trivy sbom --severity HIGH,CRITICAL api-v1.cdx.json | grep Total
trivy image --severity HIGH,CRITICAL --table-mode detailed todo-api:v1 | grep Total
trivy image --format cyclonedx -o api-safe.cdx.json todo-api:safe
python3 -c "import json;print(len(json.load(open('api-safe.cdx.json'))['components']))"
```

**이 명령은**: 첫 줄 = 이미지 없이 **목록 파일만** 보고 스캔(`trivy sbom`). 둘째 줄 = 이미지를 직접 스캔(실습 2). 셋째·넷째 줄 = 실습 3의 `todo-api:safe`로도 SBOM을 만들어 개수를 셈.

**이렇게 나오면 성공**

```
Total: 11 (HIGH: 11, CRITICAL: 0)
Total: 11 (HIGH: 11, CRITICAL: 0)
104
```

- 목록 파일 스캔과 이미지 스캔의 숫자가 **같습니다**. 숫자는 DB에 따라 달라지니 두 줄이 같은지만 봅니다
- `todo-api:safe`는 **104개** — npm과 그 부품 196개가 빠졌습니다(실습 3에서 지운 것). 새 취약점이 발표됐을 때 해당되는지 살펴볼 줄도 300줄에서 104줄로 줄어듭니다

SBOM 형식은 CycloneDX와 SPDX 두 가지가 표준입니다. 다른 도구로 만든 SBOM은 결과가 달라질 수 있습니다. 예를 들어 syft로 만든 SBOM을 Trivy로 스캔하면 nginx 이미지에서 19개, 같은 이미지를 직접 스캔하면 57개가 나왔습니다. 그래서 이 과정은 만들기·스캔 모두 Trivy로 통일합니다(부록 A7).

## 3단계. 연습용 레지스트리에 올리기 — 서명 없이 바꿔치기

### 가. 올리기

```bash
docker run -d --name reg -p 5001:5000 registry:3
docker tag todo-api:safe localhost:5001/todo-api:1.0
docker push localhost:5001/todo-api:1.0
```

**이 명령은**
- `registry:3` = 이미지 저장소 서버(Docker Hub를 작게 만든 것)를 컨테이너로 띄움. VM 5001번 → 컨테이너 5000번
- `docker tag 원래이름 새이름` = `todo-api:safe`에 새 이름 `localhost:5001/todo-api:1.0`을 붙임(이름 앞부분이 올릴 저장소 주소)
- `docker push` = 그 저장소에 올림(Docker 실습 9의 Docker Hub push와 같은 일)

**이렇게 나오면 성공**: push 마지막 줄

```
1.0: digest: sha256:3e5021e2e38e15c93eca46ff426c523270605b659840deb5cd6e084bef3807c0 size: 856
```

- 다이제스트 값은 사람마다 다릅니다

### 나. 서명 없이 바꿔치기

아직 서명이 없습니다. 누군가 **같은 이름 `todo-api:1.0`** 으로 `todo-api:v1`(root·npm이 그대로인 것)을 덮어 올렸다고 해 봅니다. 그다음 이 이미지를 받아 쓰는 쪽이 되어, 내 컴퓨터의 `1.0`을 지우고 레지스트리에서 다시 받아 실행합니다.

```bash
docker tag todo-api:v1 localhost:5001/todo-api:1.0
docker push localhost:5001/todo-api:1.0
docker rmi localhost:5001/todo-api:1.0
docker pull localhost:5001/todo-api:1.0
docker run --rm --entrypoint id localhost:5001/todo-api:1.0
```

**이 명령은**: 첫 두 줄 = 같은 이름에 다른 이미지를 붙여 올림. `docker rmi 이름` = 내 컴퓨터에서 그 이름표를 뗌. `docker pull` = 레지스트리에서 받음. `run --entrypoint id` = 앱 대신 `id`를 실행해 어떤 사용자로 도는지 봄(실습 3).

**이렇게 나오면 성공** (push는 마지막 줄만)

```
1.0: digest: sha256:148d0ce6c9b4abf36dbecfad6125e2f4adfbfac853b92a18febebf50590500b1 size: 856
Untagged: localhost:5001/todo-api:1.0
1.0: Pulling from todo-api
Digest: sha256:148d0ce6c9b4abf36dbecfad6125e2f4adfbfac853b92a18febebf50590500b1
Status: Downloaded newer image for localhost:5001/todo-api:1.0
localhost:5001/todo-api:1.0
uid=0(root) gid=0(root) groups=0(root),0(root),1(bin),2(daemon),3(sys),4(adm),6(disk),10(wheel),11(floppy),20(dialout),26(tape),27(video)
```

- 이름은 똑같이 `todo-api:1.0`인데 **root로 도는 다른 이미지**가 왔습니다. push·pull 어디에도 경고가 없습니다. 다이제스트가 가와 다르지만, 받는 쪽은 처음 다이제스트를 모르니 비교할 것이 없습니다
- 이것을 알아차리게 하는 것이 4·5단계의 서명입니다

### 다. 원래 이미지로 되돌리기

```bash
docker tag todo-api:safe localhost:5001/todo-api:1.0
docker push localhost:5001/todo-api:1.0
```

**이렇게 나오면 성공**: 마지막 줄의 다이제스트가 **가와 같음**(같은 내용이면 같은 지문)

```
1.0: digest: sha256:3e5021e2e38e15c93eca46ff426c523270605b659840deb5cd6e084bef3807c0 size: 856
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `Conflict. The container name "/reg" is already in use` | 앞에서 띄운 `reg`가 남음 | `docker rm -f reg` 후 다시 |
| `port is already allocated` | 5001번을 다른 것이 씀 | `docker ps`로 확인 |

</details>

## 4단계. 키 만들고 서명하기

```bash
export COSIGN_PASSWORD=labpass
cosign generate-key-pair
ls cosign.*
DIGEST=$(docker buildx imagetools inspect localhost:5001/todo-api:1.0 --format '{{.Manifest.Digest}}')
echo $DIGEST
cosign sign --yes --key cosign.key --use-signing-config=false --tlog-upload=false localhost:5001/todo-api@$DIGEST
```

**이 명령은**

| 명령 | 하는 일 |
|---|---|
| `export COSIGN_PASSWORD=labpass` | 키 암호. **연습용**이라 이렇게 두며, 실제 키 암호는 이렇게 두지 않음 |
| `cosign generate-key-pair` | `cosign.key`(비밀키 — 서명할 때, 나만 가짐) + `cosign.pub`(공개키 — 검증할 때, 누구에게나 줌) |
| `DIGEST=$(… imagetools inspect …)` | 레지스트리에 올라간 내용의 **다이제스트**(내용으로 계산한 지문, `sha256:…`)를 구해 변수에 담음 |
| `cosign sign … todo-api@$DIGEST` | 태그(`:1.0`)가 아니라 **다이제스트**(`@sha256:…`)에 서명. 서명은 같은 레지스트리에 함께 저장됨 |

**이렇게 나오면 성공**

```
Private key written to cosign.key
Public key written to cosign.pub
cosign.key  cosign.pub
sha256:3e5021e2e38e15c93eca46ff426c523270605b659840deb5cd6e084bef3807c0
Flag --tlog-upload has been deprecated, prefer using a --signing-config file with no transparency log services
Signing artifact...
Pushing signature to: localhost:5001/todo-api
```

- 다이제스트 값은 사람마다 다릅니다. `Flag --tlog-upload has been deprecated` 줄은 옵션 이름이 앞으로 바뀐다는 안내라 그대로 둬도 됩니다

**왜 다이제스트에 서명하나**: 태그(`1.0`)는 다른 이미지에 **바꿔 달 수 있지만**, 다이제스트는 내용이 1바이트만 바뀌어도 달라집니다. `--tlog-upload=false`·`--use-signing-config=false`는 인터넷의 공개 기록(Rekor)을 쓰지 않는 **연습용** 설정입니다(실무 방식은 부록 A8).

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 서명이 레지스트리 주소 없는 이름(`todo-api@sha256:…`)으로 실패 | `docker inspect`의 RepoDigests를 씀 | 위처럼 `docker buildx imagetools inspect`로 |
| `--tlog-upload=false`만으로 서명이 안 됨 | cosign 3은 `--use-signing-config=false`도 필요 | 위 명령 그대로 |
| `WARNING: File cosign.key already exists. Overwrite?` `… [y/N]` | 키를 이미 만듦 | `N`(Enter) — `user declined the prompt`가 나와도 있는 키를 그대로 씀 |

</details>

## 5단계. 검증하기

```bash
cosign verify --key cosign.pub --insecure-ignore-tlog=true localhost:5001/todo-api:1.0
```

**이 명령은**: 공개키로 `todo-api:1.0`이 가리키는 다이제스트에 **내 서명이 있는지** 확인. `--insecure-ignore-tlog=true` = 공개 기록 확인을 건너뜀(4단계와 짝).

**이렇게 나오면 성공**

```
WARNING: Skipping tlog verification is an insecure practice that lacks transparency and auditability verification for the signature.

Verification for localhost:5001/todo-api:1.0 --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - Existence of the claims in the transparency log was verified offline
  - The signatures were verified against the specified public key

[{"critical":{"identity":{"docker-reference":"localhost:5001/todo-api:1.0"},"image":{"docker-manifest-digest":"sha256:…"},…
```

- 맨 위 `WARNING` 줄은 공개 기록 확인을 건너뛰었다는 안내입니다(연습용 설정이라 정상)

## 6단계. 바꿔치기하고 다시 검증

누군가 **같은 이름 `todo-api:1.0`** 으로 다른 이미지(`todo-api:v1`, root·npm이 그대로인 것)를 올렸다고 해 봅니다.

```bash
docker tag todo-api:v1 localhost:5001/todo-api:1.0
docker push localhost:5001/todo-api:1.0
cosign verify --key cosign.pub --insecure-ignore-tlog=true localhost:5001/todo-api:1.0
```

**이렇게 나오면 성공** — 실패하는 것이 맞습니다.

```
WARNING: Skipping tlog verification is an insecure practice that lacks transparency and auditability verification for the signature.
Error: no signatures found
error during command execution: no signatures found
```

| 같은 바꿔치기 (`todo-api:v1`을 `1.0`으로 덮어 올림) | 서명 없음 (3단계 나) | 서명 있음 (6단계) |
|---|---|---|
| 받는 쪽이 보는 것 | `Downloaded newer image` — 경고 없음 | `Error: no signatures found` |
| 실행하면 | `uid=0(root)` 이미지가 그대로 돎 | 검증에서 멈춤(실행 전에 거를 수 있음) |

**왜 그런가**: 태그 `1.0`은 이제 **다른 내용(다른 다이제스트)** 을 가리킵니다. 서명은 처음 다이제스트에 붙어 있으니, 새 다이제스트에는 서명이 없어 검증이 실패합니다. 실무에서는 클러스터의 정책 엔진(예: Kyverno의 이미지 검증 규칙)이 파드를 만들 때 이 검증을 해서, `no signatures found`인 이미지의 파드는 **만들지 않게** 합니다(이 과정에서는 설명만). CI/CD 과목에서는 이미지 빌드·스캔을 파이프라인에 넣습니다.

## 끝났는지 확인

- ☐ `api-v1.cdx.json` 구성요소 300, `api-safe.cdx.json` 104
- ☐ `trivy sbom`과 `trivy image`의 `Total`이 같음
- ☐ 서명 없이 바꿔치기한 `1.0`을 받아 `id`가 `uid=0(root)` — 경고 없음
- ☐ 첫 검증에 `The signatures were verified against the specified public key`
- ☐ 바꿔치기 뒤 검증에 `no signatures found`

## 정리

확인 문제를 푼 뒤 레지스트리를 지웁니다. SBOM 파일과 키(`cosign.key`·`cosign.pub`)는 `~/sec`에 남겨도 됩니다.

```bash
docker rm -f reg
```

## 확인 문제

1. `todo-api:safe`를 `localhost:5001/todo-api:2.0`으로 올리고 **내 키로 서명**한 뒤 `cosign.pub`으로 검증하세요. (2.0으로 push한 **뒤에** 다이제스트를 구합니다)
2. 키 쌍을 하나 더 만들어(`cosign generate-key-pair --output-key-prefix other`) `other.pub`으로 2.0을 검증하면 어떻게 되나요? 결과를 한 줄로 정리해 보세요: "공개키를 가진 사람은 ___을 확인할 수 있고, ___은 확인할 수 없다"
