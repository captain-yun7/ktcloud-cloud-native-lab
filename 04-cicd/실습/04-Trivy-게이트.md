[← 실습 3](./03-첫-워크플로-테스트-빌드-올리기.md) · [목차](../CICD-실습.md) · [미션 1 →](../미션/01-todo-web-파이프라인.md)

# 실습 4. Trivy 게이트 — job 나누기

**무엇을 하나요**: 파이프라인을 `test` / `scan` / `push` 세 job으로 나누고, 고칠 수 있는 심각한(CRITICAL) 취약점이 있으면 **이미지가 올라가지 않게** 막습니다(게이트). 일부러 오래된 바탕 이미지(`node:18-alpine`)로 PR을 열어 막히는 것을 보고, 바탕 이미지의 OS 패키지를 올려 통과시킵니다. PR에서는 검사만 하고 올리지 않는 것도 확인합니다. 클라우드 보안 실습 2에서 손으로 돌리던 Trivy를 파이프라인이 매번 합니다. (교안 04장)

**필요한 것**: 실습 3의 `api.yml`.

> **바로 가기** · [1. api.yml을 job 세 개로](#1단계-apiyml을-job-세-개로) · [2. 올리고 job 세 개 보기](#2단계-올리고-job-세-개-보기) · [3. 시험 브랜치에 오래된 바탕 이미지](#3단계-시험-브랜치에-오래된-바탕-이미지) · [4. PR 열어 막히는지 보기](#4단계-pr-열어-막히는지-보기) · [5. 고쳐서 다시 — OS 패키지 올리기](#5단계-고쳐서-다시--os-패키지-올리기) · [6. PR 닫고 main으로](#6단계-pr-닫고-main으로) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. api.yml을 job 세 개로

`api.yml` **전체를** 아래로 바꿉니다(가장 쉬운 방법: `rm .github/workflows/api.yml` 뒤 `nano .github/workflows/api.yml`로 새로 쓰기).

```yaml
name: api

on:
  push:
    branches: [main]
    paths:
      - "api/**"
      - ".github/workflows/api.yml"
  pull_request:
    paths:
      - "api/**"
  workflow_dispatch:

permissions:
  contents: read
  packages: write

env:
  APP: api                 # 폴더 이름 = 이미지 이름 (미션 1에서는 web)
  TRIVY_VERSION: v0.74.0

jobs:
  test:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
        with:
          node-version: 22
      - name: 테스트
        working-directory: ${{ env.APP }}
        run: |
          npm ci
          npm test

  scan:
    needs: test
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7
      - name: 이미지 빌드 (검사용)
        run: docker build -t ${{ env.APP }}:ci ${{ env.APP }}
      # 남이 만든 Action은 태그 대신 커밋 SHA로 고정한다 (태그는 다른 코드로 옮겨 달 수 있다)
      - uses: aquasecurity/setup-trivy@81e514348e19b6112ce2a7e3ecbafe19c1e1f567 # v0.3.1
        with:
          version: ${{ env.TRIVY_VERSION }}
          cache: true
      - name: Trivy 게이트 (고칠 수 있는 CRITICAL이 있으면 실패)
        run: trivy image --exit-code 1 --severity CRITICAL --ignore-unfixed ${{ env.APP }}:ci

  push:
    needs: scan
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7
      - name: 이미지 이름 (GHCR는 소문자만)
        id: img
        run: echo "name=ghcr.io/${GITHUB_REPOSITORY,,}/${{ env.APP }}" >> "$GITHUB_OUTPUT"
      - uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: 빌드·올리기
        uses: docker/build-push-action@v7
        with:
          context: ${{ env.APP }}
          push: true
          tags: |
            ${{ steps.img.outputs.name }}:${{ github.sha }}
            ${{ steps.img.outputs.name }}:main
```

**이 파일에서 새로 나온 것**

| 문법 | 뜻 |
|---|---|
| `pull_request:` | PR을 열거나 PR 브랜치에 push하면 실행 |
| `env: APP: api` | 이름을 한 곳에 모음. 아래에서 `${{ env.APP }}`로 씀 — web으로 복사할 때 여기만 바꾸면 됨(미션 1) |
| `needs: test` | test가 성공해야 시작 |
| `if: github.ref == 'refs/heads/main'` | main에 push할 때만 (PR에서는 건너뜀) |
| `trivy image --exit-code 1 --severity CRITICAL --ignore-unfixed` | CRITICAL 취약점 중 **고친 버전이 있는 것**이 하나라도 있으면 실패(종료 코드 1) → 다음 job(push)이 돌지 않음 |

## 2단계. 올리고 job 세 개 보기

```bash
git commit -am "ci: job 나누기와 Trivy 게이트" && git push && gh run watch
```

**이렇게 나오면 성공**: Actions 화면 가운데에 `test → scan → push` 세 상자가 화살표로 이어져 차례로 초록이 됩니다. `gh run watch` 끝에는 이렇게 보입니다.

```
✓ test in 9s
✓ scan in 31s
✓ push in 21s
```

`scan` → `Trivy 게이트` 단계를 펼치면 `api:ci (alpine 3.24.2)`의 Vulnerabilities가 `0`입니다.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| job이 하나만 보임 | 파일 일부만 바꿈(실습 3 `build` job이 남음) | 파일 전체를 지우고 다시 붙여 넣기 |
| main push인데 push job이 회색 | `if:` 줄 오타(따옴표, `refs/heads/main`) | 1단계 파일과 비교 |
| scan이 Action을 찾지 못한다는 오류 | `setup-trivy@` 뒤 40자리를 손으로 치다 틀림 | 복사해서 다시 붙여 넣기 |

</details>

## 3단계. 시험 브랜치에 오래된 바탕 이미지

게이트가 정말 막는지 봅니다. 브랜치에서 바탕 이미지를 지원이 끝난 Node 18로 바꿉니다(실습 2의 브랜치 흐름).

```bash
git switch -c gate-test
sed -i 's#^FROM node:22-alpine$#FROM node:18-alpine#' api/Dockerfile
grep ^FROM api/Dockerfile
git commit -am "시험: 오래된 바탕 이미지" && git push -u origin gate-test
```

**이 명령은**: `api/Dockerfile`의 `FROM node:22-alpine` 줄을 `FROM node:18-alpine`으로 바꿔 새 브랜치에 올립니다. 앱 코드는 그대로라 테스트는 통과합니다.

**이렇게 나오면 성공**

```
FROM node:18-alpine
[gate-test 9ecd4ce] 시험: 오래된 바탕 이미지
 1 file changed, 1 insertion(+), 1 deletion(-)
…
 * [new branch]      gate-test -> gate-test
```

## 4단계. PR 열어 막히는지 보기

```bash
gh pr create -t "게이트 시험" -b "막히는지 확인"
gh run watch
```

**이 명령은**: `gh pr create` = 실습 2에서 브라우저로 한 PR 만들기를 명령 한 줄로. `-t` 제목, `-b` 본문. PR을 열면 `pull_request` 조건으로 실행이 시작됩니다.

**이렇게 나오면 성공** — scan이 실패하고 push는 건너뜁니다(이 단계는 실패하는 것이 맞습니다)

```
X gate-test api <아이디>/cicd-lab#2 · …
Triggered via pull_request

JOBS
✓ test in 12s
X scan in 32s
  …
  X Trivy 게이트 (고칠 수 있는 CRITICAL이 있으면 실패)
- push
```

`scan` → `Trivy 게이트` 로그의 끝:

```
api:ci (alpine 3.21.3)
======================
Total: 2 (CRITICAL: 2)

│ libcrypto3 │ CVE-2026-31789 │ CRITICAL │ fixed  │ 3.3.3-r0          │ 3.3.7-r0      │ openssl: …
│ libssl3    │                │          │        │                   │               │
##[error]Process completed with exit code 1.
```

- 브라우저의 PR 화면 아래쪽 검사 목록에도 `api / scan`이 빨간 X로 보입니다. 이 PR을 합치면 위험한 이미지가 main으로 들어간다는 경고입니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `nothing to commit`, PR 실행이 없음 | sed가 FROM 줄을 못 바꿈 | `grep ^FROM api/Dockerfile`이 `FROM node:18-alpine`이어야 함. 아니면 nano로 |
| `gh run watch`가 main 실행을 보여 줌 | 목록에서 다른 실행을 고름 | `gate-test` 브랜치 실행을 고름 |
| PR이 이미 있다는 문구 | 같은 브랜치로 PR을 두 번 만듦 | 그대로 `gh run watch` |

</details>

## 5단계. 고쳐서 다시 — OS 패키지 올리기

바탕 이미지를 바로 바꿀 수 없다고 칩니다. 대신 바탕 이미지 안의 OS 패키지를 고친 버전으로 올리는 줄을 하나 더합니다.

```bash
sed -i 's#^FROM node:18-alpine$#FROM node:18-alpine\nRUN apk upgrade --no-cache#' api/Dockerfile
head -3 api/Dockerfile
git commit -am "바탕 이미지의 OS 패키지 올리기" && git push
gh run watch
```

**이 명령은**: `FROM` 줄 바로 아래에 `RUN apk upgrade --no-cache`(alpine 패키지를 모두 최신으로)를 더해 같은 PR 브랜치에 올립니다. PR은 열려 있으니 push하면 검사가 다시 돕니다.

**이렇게 나오면 성공** — 이번에는 test·scan 초록, push는 여전히 회색입니다(PR에서는 올리지 않음)

```
FROM node:18-alpine
RUN apk upgrade --no-cache
WORKDIR /app
…
✓ test in 14s
✓ scan in 39s
- push
```

`Trivy 게이트` 로그의 표: `api:ci (alpine 3.21.3)  alpine  0`

| | 게이트 없음 (실습 3) | 게이트 있음 (지금) |
|---|---|---|
| CRITICAL 2건 든 이미지 | 테스트만 통과하면 `:main`으로 올라감 | scan에서 멈춤, 레지스트리 그대로 |
| PR | 검사 없음 | test·scan 결과가 PR에 붙음, 올리지는 않음 |
| 고친 뒤 | — | 같은 PR이 초록 → 합쳐도 됨 |

## 6단계. PR 닫고 main으로

```bash
gh pr close -d gate-test
git branch
grep ^FROM api/Dockerfile
```

**이 명령은**: PR을 닫고(합치지 않음) 브랜치(GitHub 쪽과 VM 쪽)를 지운 뒤 main으로 돌아옵니다.

**이렇게 나오면 성공**

```
✓ Closed pull request <아이디>/cicd-lab#2 (게이트 시험)
✓ Deleted branch gate-test and switched to branch main
* main
FROM node:22-alpine
```

## 끝났는지 확인
- ☐ main 실행에서 `test`·`scan`·`push` 세 job 모두 초록
- ☐ 시험 PR에서 `scan`이 `Total: 2 (CRITICAL: 2)`로 빨간 X, `push`가 회색
- ☐ `apk upgrade`를 더한 뒤 같은 PR이 test·scan 초록, `push`는 회색
- ☐ `git branch`에 `* main`만 남음

## 정리
- 시험 브랜치는 6단계에서 지웠습니다. `api/Dockerfile`은 main에서 바뀌지 않았습니다

## 확인 문제
1. 게이트는 결국 `trivy`의 **종료 코드**로 판단합니다. VM에서 `trivy image -q --exit-code 1 --severity CRITICAL --ignore-unfixed node:18-alpine; echo $?`를 실행하세요. `node:22-alpine`이면 무엇이 나오나요?
2. `aquasecurity/setup-trivy`는 `@v0.3.1` 같은 태그 대신 긴 커밋 번호로 적었습니다. 왜 그렇게 하나요?
