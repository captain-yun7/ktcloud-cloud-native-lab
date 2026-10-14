[← 실습 1](./01-내-저장소와-토큰.md) · [목차](../CICD-실습.md) · [실습 3 →](./03-첫-워크플로-테스트-빌드-올리기.md)

# 실습 2. Git으로 변경 올리기

**무엇을 하나요**: 파일을 고쳐 **커밋**하고 GitHub에 **push**합니다. 일부러 실수 하나(커밋 없이 push)를 해 봅니다. 브랜치에서 고친 것을 **PR**로 main에 합치고, 합친 결과를 VM으로 **pull**합니다. 마지막으로 배포 매니페스트의 이미지 주소에 내 아이디를 넣어 올립니다. 앞으로 파이프라인은 모두 **push로 시작**하므로, 이 흐름이 손에 익어야 03장부터 막히지 않습니다. (교안 02장)

**필요한 것**: 실습 1의 `~/cicd-lab`과 로그인.

> **바로 가기** · [1. 상태 보고 한 줄 고치기](#1단계-상태-보고-한-줄-고치기) · [2. 기록하고 올리기 — add · commit · push](#2단계-기록하고-올리기--add--commit--push) · [3. 일부러 실수 — 커밋 없이 push](#3단계-일부러-실수--커밋-없이-push) · [4. 브랜치에서 고쳐 올리기](#4단계-브랜치에서-고쳐-올리기) · [5. PR 열고 합치기 (브라우저)](#5단계-pr-열고-합치기-브라우저) · [6. 합친 결과 받기 — pull](#6단계-합친-결과-받기--pull) · [7. 배포 주소에 내 아이디 넣기](#7단계-배포-주소에-내-아이디-넣기) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 상태 보고 한 줄 고치기

```bash
cd ~/cicd-lab
git status
```

**이렇게 나오면 성공**: 아직 아무것도 고치지 않았습니다.

```
On branch main
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean
```

`README.md` 맨 아래(`## 실습한 사람` 아래)에 한 줄을 더합니다. `nano README.md`로 열어 적어도 되고, 아래 명령으로 더해도 됩니다.

```bash
echo "- 실습: <이름>" >> README.md
git status
git diff
```

**이 명령은**: `echo "…" >> 파일` = 파일 맨 아래에 한 줄 더하기. `git status` = 무엇이 바뀌었나, `git diff` = 바뀐 내용(더한 줄 앞에 `+`, 뺀 줄 앞에 `-`).

**이렇게 나오면 성공**

```
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   README.md
```

`git diff`의 끝에 이렇게 보입니다.

```
 ## 실습한 사람
+- 실습: <이름>
```

## 2단계. 기록하고 올리기 — add · commit · push

```bash
git add README.md
git status
git commit -m "docs: README에 내 이름"
git push
git log --oneline -3
```

**이 명령은**

| 명령 | 하는 일 |
|---|---|
| `git add 파일` | 이번 커밋에 넣을 파일 고르기 |
| `git commit -m "메시지"` | 내 VM 저장소에 기록 남기기 |
| `git push` | 내 기록을 GitHub로 올리기 |
| `git log --oneline` | 기록 목록 (한 줄에 하나, 앞의 7자리가 커밋 번호) |

**이렇게 나오면 성공** — 차례로 이렇게 나옵니다(커밋 번호는 사람마다 다름)

```
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
	modified:   README.md

[main c98718f] docs: README에 내 이름
 1 file changed, 1 insertion(+)

To https://github.com/<아이디>/cicd-lab.git
   d501611..c98718f  main -> main

c98718f docs: README에 내 이름
d501611 Initial commit
```

GitHub의 내 저장소 화면을 새로고침하면 README 맨 아래에 방금 줄이 보이고, 커밋 수가 하나 늘어 있습니다.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `Author identity unknown ... Please tell me who you are.` | 이름·이메일 설정 안 함 | 실습 1의 5단계 `git config` 줄 실행 후 다시 commit |
| 편집기(vi)가 열려 빠져나올 수 없음 | `git commit`에 `-m "메시지"`를 빠뜨림 | `Esc` → `:q!` → Enter, `-m`을 붙여 다시 |
| `Username for 'https://github.com':` | 실습 1 4단계 `gh auth setup-git`을 빠뜨림 | Ctrl+C → `gh auth setup-git` → 다시 push |
| `! [rejected] main -> main (fetch first)` | GitHub에 내 VM에 없는 커밋이 있음 | 확인 문제 2에서 다룸 — `git pull --rebase` 뒤 `git push` |

</details>

## 3단계. 일부러 실수 — 커밋 없이 push

```bash
echo "- 질문: Discord" >> README.md
git push
git status --short
```

**이렇게 나오면 성공** — 아무것도 올라가지 않습니다(이 단계는 이렇게 나오는 것이 맞습니다)

```
Everything up-to-date
 M README.md
```

- `push`는 **커밋만** 올립니다. 고치기만 하고 커밋하지 않은 변경(` M README.md`)은 아직 내 작업 폴더에만 있습니다

커밋하고 다시 올립니다.

```bash
git commit -am "docs: 질문 방법"
git push
```

**이 명령은**: `git commit -a` = 이미 기록된 파일의 변경을 add까지 한 번에. 새로 만든 파일은 들어가지 않으므로 `git add 파일`을 먼저 해야 합니다(실습 3에서 워크플로 파일을 처음 만들 때).

**이렇게 나오면 성공**

```
[main 76ca2d3] docs: 질문 방법
 1 file changed, 1 insertion(+)
To https://github.com/<아이디>/cicd-lab.git
   c98718f..76ca2d3  main -> main
```

## 4단계. 브랜치에서 고쳐 올리기

main을 바로 고치지 않고, **브랜치**(따로 고치는 갈래)에서 고친 뒤 **PR**로 합치자고 요청합니다. 04장부터 게이트를 "PR에서 먼저 돌려 보는" 데 이 흐름을 씁니다.

```bash
git switch -c readme-intro
echo "## 소개" >> README.md
git commit -am "docs: 소개 절 추가"
git push -u origin readme-intro
git branch -a
```

**이 명령은**: `git switch -c 이름` = 새 브랜치를 만들고 그리로 옮김. `git push -u origin 브랜치` = 새 브랜치를 GitHub에 처음 올릴 때 씀. `git branch -a` = 브랜치 목록(`*`가 지금 있는 곳).

**이렇게 나오면 성공**

```
remote: 
remote: Create a pull request for 'readme-intro' on GitHub by visiting:
remote:      https://github.com/<아이디>/cicd-lab/pull/new/readme-intro
remote: 
To https://github.com/<아이디>/cicd-lab.git
 * [new branch]      readme-intro -> readme-intro
branch 'readme-intro' set up to track 'origin/readme-intro'.

  main
* readme-intro
  remotes/origin/HEAD -> origin/main
  remotes/origin/main
  remotes/origin/readme-intro
```

`remote:`로 시작하는 줄은 GitHub가 보내는 안내입니다. 그 주소(`…/pull/new/readme-intro`)를 브라우저로 열면 바로 PR 만들기 화면이 나옵니다.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `! [remote rejected] readme-intro -> readme-intro (failed)` | GitHub 쪽 일시 오류 | 같은 `git push -u origin readme-intro`를 한 번 더 |
| `fatal: a branch named 'readme-intro' already exists` | 이미 만든 브랜치 | `git switch readme-intro`로 옮겨 감 |

</details>

## 5단계. PR 열고 합치기 (브라우저)

1. 위 `remote:` 줄의 주소를 열거나, 내 저장소 화면 위쪽의 노란 띠 **Compare & pull request** (안 보이면 **Pull requests** 탭 → **New pull request** → base `main` ← compare `readme-intro`)
2. 제목 확인(커밋이 하나면 커밋 메시지 `docs: 소개 절 추가`가 제목으로 들어가 있음) → **Create pull request**
3. **Files changed** 탭에서 바뀐 줄 확인 → **Conversation** 탭 아래쪽의 **Merge pull request → Confirm merge**
4. **Delete branch** (GitHub 쪽 브랜치 정리, 선택)

**이렇게 나오면 성공**: PR 화면 제목 아래에 보라색 **Merged** 표시가 보입니다.

- 팀 저장소에서는 main에 바로 push하지 못하게 막고(Settings → Rules), PR과 검사 통과를 거쳐야만 합치게 합니다. 이 과목은 혼자 쓰는 저장소라 켜지 않습니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 비교할 것이 없다는 화면 | 브랜치를 push하지 않았거나, base·compare가 같은 브랜치 | 4단계 출력의 `[new branch]` 확인, base `main` ← compare `readme-intro` |
| PR 번호가 `#1`이 아님 | 전에 PR을 연 적 있음 | 정상([시작하기 전에 4](./00-시작하기-전에.md#4-출력이-문서와-조금-달라도-되는-것)) |

</details>

## 6단계. 합친 결과 받기 — pull

GitHub에서 합친 것은 아직 VM에 없습니다. main으로 돌아와 받습니다.

```bash
git switch main
git pull
git log --oneline --graph -5
git branch -d readme-intro
```

**이 명령은**: `git pull` = GitHub의 새 커밋을 받기. `--graph` = 갈래를 선으로 그려 보여 줌. `git branch -d` = 다 쓴 VM 쪽 브랜치 지우기.

**이렇게 나오면 성공**

```
From https://github.com/<아이디>/cicd-lab
   76ca2d3..7d101d9  main       -> origin/main
Updating 76ca2d3..7d101d9
Fast-forward
 README.md | 1 +
 1 file changed, 1 insertion(+)

*   7d101d9 Merge pull request #1 from <아이디>/readme-intro
|\  
| * eea72b5 docs: 소개 절 추가
|/  
* 76ca2d3 docs: 질문 방법
* c98718f docs: README에 내 이름
* d501611 Initial commit

Deleted branch readme-intro (was eea72b5).
```

## 7단계. 배포 주소에 내 아이디 넣기

`deploy/overlays/dev`·`prod`의 매니페스트에는 앞으로 파이프라인이 올릴 이미지 주소가 `ghcr.io/<아이디>/cicd-lab/api`처럼 비워져 있습니다. 내 아이디로 바꿔 올립니다. 1~2단계와 같은 흐름입니다.

```bash
grep newName deploy/overlays/dev/kustomization.yaml
sed -i "s/<아이디>/$(gh api user --jq .login | tr 'A-Z' 'a-z')/" deploy/overlays/*/kustomization.yaml
git diff --stat
grep newName deploy/overlays/dev/kustomization.yaml
git commit -am "deploy: 이미지 주소에 내 아이디" && git push
```

**이 명령은**: `gh api user --jq .login` = 로그인한 내 GitHub 아이디. `tr 'A-Z' 'a-z'` = 소문자로(GHCR 이미지 주소는 소문자만 됨). `sed -i "s/A/B/"` = 파일 안의 A를 B로 바꿈. dev·prod 두 파일을 한 번에 바꿉니다.

**이렇게 나오면 성공**

```
  newName: ghcr.io/<아이디>/cicd-lab/api
  newName: ghcr.io/<아이디>/cicd-lab/web
 deploy/overlays/dev/kustomization.yaml  | 4 ++--
 deploy/overlays/prod/kustomization.yaml | 4 ++--
 2 files changed, 4 insertions(+), 4 deletions(-)
  newName: ghcr.io/hong-gildong/cicd-lab/api
  newName: ghcr.io/hong-gildong/cicd-lab/web
```

- 두 번째 `grep`에서 `<아이디>` 자리에 **내 아이디(소문자)** 가 보이면 됩니다(위 `hong-gildong`은 예). 마지막 push는 2단계처럼 `main -> main`

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `git diff --stat`이 아무것도 안 나옴 | 이미 바꿨거나, 파일의 `<아이디>`를 손으로 고침 | `grep newName deploy/overlays/*/kustomization.yaml`로 내 아이디가 들어 있으면 그대로 진행 |
| `newName: ghcr.io//cicd-lab/api`(아이디 자리가 빔) | `gh` 로그인이 안 된 상태 | `git checkout deploy` 로 되돌리고 실습 1 4단계 → 다시 |

</details>

## 끝났는지 확인
- ☐ GitHub의 README 맨 아래에 내가 더한 줄들이 보인다
- ☐ `git log --oneline --graph -5`에 `Merge pull request`
- ☐ `grep newName deploy/overlays/dev/kustomization.yaml`에 내 아이디(소문자)
- ☐ `git status`가 `nothing to commit, working tree clean`

## 정리
- 지울 것 없음. `readme-intro` 브랜치는 6단계에서 지웠습니다

## 확인 문제
1. README를 한 줄 더 고친 뒤 `git diff`를 실행하고, `git add README.md` 뒤에 다시 `git diff`를 실행하세요. 두 번의 결과가 어떻게 다른가요? add한 뒤의 변경을 보려면 어떤 명령을 쓰나요? (끝나면 `git restore --staged README.md && git restore README.md`로 되돌립니다)
2. GitHub 화면에서 README의 **맨 윗줄(제목)** 을 직접 고쳐 커밋(연필 아이콘 → Commit changes)한 뒤, VM에서는 `git pull` 없이 README **맨 아래**에 한 줄을 더해 커밋하고 `git push`하세요. 어떤 메시지가 나오나요? `git pull`만 하면 무엇이 나오고, 어떻게 해결하나요? (실습 5 · 미션 2에서 파이프라인이 내 저장소에 커밋을 남기면 똑같은 일이 생깁니다)
