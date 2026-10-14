[← 미션 1](./01-todo-web-파이프라인.md) · [목차](../CICD-미션.md)

# 미션 2. push 한 번으로 dev 배포, prod는 승인

**무엇을 하나요**: api는 실습 7에서 push 한 번으로 dev까지 갔습니다(Jenkins). 이번에는 **web**도 그렇게 만듭니다 — GitHub Actions가 올린 이미지의 태그를 dev 매니페스트에 커밋하면 Argo CD가 `todo-dev`에 배포합니다. 운영(`todo-prod`)은 자동으로 바뀌지 않게 하고, dev에서 확인한 태그만 **PR(승인)** 으로 prod 매니페스트에 옮긴 뒤 **Sync**를 눌러 올립니다. 문제가 생기면 **Git으로 되돌립니다.**

```
web 코드 push ─▶ Actions(test·scan·push) ─▶ deploy-dev job이 dev 매니페스트에 태그 커밋 ─▶ Argo CD ─▶ todo-dev (자동)
                                          PR로 prod 매니페스트에 같은 태그 ─▶ 병합(승인) ─▶ Argo CD Sync(사람) ─▶ todo-prod
```

| 과제 | 한 줄 요약 | 확인 방법 |
|---|---|---|
| 과제 1 | `web.yml`에 `deploy-dev` job — 올린 이미지의 태그를 `deploy/overlays/dev`에 커밋 | 저장소에 봇 커밋 `deploy(dev): web <커밋 7자리>` |
| 과제 2 | `todo-prod` 앱 — **자동 동기화 없음**. prod 매니페스트에 dev와 같은 태그를 적고 첫 배포 | prod 앱 `Synced  Healthy`, prod 화면 제목 `할 일` |
| 과제 3 | web 화면 제목을 바꿔 push → 사람 손 없이 **dev만** 바뀜 | dev 제목에 내 이름, prod는 그대로 |
| 과제 4 | dev에서 확인한 태그를 **PR**로 prod에 → 병합 → Argo CD에서 **Sync** | PR 링크, prod 제목에 내 이름 |
| 과제 5 | prod에 문제가 생겼다고 치고 **Git으로 되돌려** 원래 제목으로 | revert 커밋, prod 제목 `할 일` |

> **바로 가기** · [과제 1. deploy-dev job](#과제-1-deploy-dev-job--web-태그를-dev-매니페스트에-커밋) · [과제 2. todo-prod](#과제-2-todo-prod--자동-동기화-없이-첫-배포) · [과제 3. 제목 바꿔 dev에 자동 반영](#과제-3-제목-바꿔-dev에-자동-반영) · [과제 4. PR로 prod에 올리기](#과제-4-pr로-prod에-올리기) · [과제 5. Git으로 되돌리기](#과제-5-git으로-되돌리기) · [도전 (선택)](#도전-선택) · [미션 2 결과 정리 표 (리뷰 때 함께 봄)](#미션-2-결과-정리-표-리뷰-때-함께-봄)

## 공통 정보
- web 제목: `web/index.html`의 `<h1>할 일</h1>`
- 화면 제목 확인 명령(dev): `kubectl -n todo-dev exec deploy/web -- wget -qO- http://127.0.0.1/ | grep "<h1>"` — prod는 `-n todo-prod`
- prod 앱 파일은 실습 6의 `argocd/app-dev.yaml`을 복사해서 만듭니다
- 실습 6 확인 문제에서 selfHeal을 껐다면 `true`로 되돌려 둡니다
- 파이프라인이 저장소에 커밋을 남기므로, 내 push가 `rejected (fetch first)`면 `git pull --rebase` 뒤 push

## 과제 1. deploy-dev job — web 태그를 dev 매니페스트에 커밋

**무엇을 하나요**: 이미지를 올린 뒤, 그 이미지 태그를 `deploy/overlays/dev`에 기록하고 커밋·push하는 job을 `web.yml`에 더합니다. 실습 5에서 Jenkins가 한 "매니페스트 갱신"을 Actions로 하는 것입니다.

<details><summary>힌트 1 — deploy-dev job의 모양</summary>

`needs: push`로 올리기가 끝난 뒤에 돌게 하고, 이 job에만 `permissions: contents: write`를 줍니다. 할 일은 네 가지: 체크아웃 → `deploy/overlays/dev`에서 `kustomize edit set image todo-web=<새 이미지>` → 커밋 → push. 새 이미지 주소는 push job과 같은 `ghcr.io/${GITHUB_REPOSITORY,,}/web`, 태그는 커밋 번호 `${GITHUB_SHA}`. 커밋하려면 `git config user.name/user.email`이 필요합니다(Jenkinsfile의 매니페스트 갱신과 비교).
</details>

<details><summary>힌트 2 — 봇 커밋이 또 워크플로를 부르지 않을까</summary>

`GITHUB_TOKEN`으로 만든 커밋은 워크플로를 새로 실행하지 않습니다. 게다가 `web.yml`은 `web/**`만 봅니다. Jenkins는 `when`으로 건너뜁니다(실습 5 확인 문제 1).
</details>

**이렇게 나오면 성공**: `web` 실행에 상자가 네 개(`test → scan → push → deploy-dev`) 모두 초록. `git pull` 뒤 `git log --oneline -1`이 `deploy(dev): web <커밋 7자리>`(작성자 `github-actions[bot]`). 그 커밋으로 워크플로가 다시 돌지 않음. 1~2분 뒤 todo-dev의 web 이미지가 `…/web:<40자리 커밋 번호>`.

**이렇게 나오면?**

| 화면 | 원인 | 해결 |
|---|---|---|
| deploy-dev의 `git push`에서 권한 오류 | 이 job에 `permissions: contents: write`가 없음 | job 아래에 `permissions:` 추가 |
| deploy-dev에서 `nothing to commit` | `kustomize edit`의 이름이 틀림(`todo-web`이 아님) | `deploy/base/web.yaml`의 `image: todo-web` |
| 이후 내 `git push`가 `rejected (fetch first)` | 봇이 저장소에 커밋을 남김 | `git pull --rebase` 뒤 push |

## 과제 2. todo-prod — 자동 동기화 없이 첫 배포

**무엇을 하나요**: prod 매니페스트의 태그를 지금 dev와 같게 적어 커밋한 뒤, `todo-prod` 앱을 **자동 동기화 없이** 만들고 Sync를 눌러 첫 배포를 합니다.

<details><summary>힌트 3 — prod 매니페스트의 태그</summary>

`deploy/overlays/prod/kustomization.yaml`의 `newTag: main` 두 줄을 dev 파일(`deploy/overlays/dev/kustomization.yaml`)의 `newTag` 값(api `jenkins-N`, web 40자리 커밋 번호)으로 nano에서 바꿉니다. 바꾼 뒤 `diff deploy/overlays/dev/kustomization.yaml deploy/overlays/prod/kustomization.yaml`에는 첫 줄 주석과 `namespace`만 달라야 합니다. commit → push.
</details>

<details><summary>힌트 4 — prod 앱 파일과 Sync</summary>

`cp argocd/app-dev.yaml argocd/app-prod.yaml` → `name`·`path`·`namespace` 세 곳을 prod로 → `automated:` 블록(아래 `prune`, `selfHeal` 줄 포함) 삭제 → `kubectl apply -f argocd/app-prod.yaml`. 만든 직후 앱은 `OutOfSync` / `Missing`(아직 아무것도 없음). `kubectl create namespace todo-prod`로 네임스페이스를 먼저 만들고, Argo CD 화면에서 `todo-prod` → **SYNC** → **SYNCHRONIZE**.
</details>

**이렇게 나오면 성공**: `kubectl -n argocd get app`에 `todo-dev  Synced  Healthy`, `todo-prod  Synced  Healthy`. prod 제목 확인 명령이 `<h1>할 일</h1>`.

**이렇게 나오면?**

| 화면 | 원인 | 해결 |
|---|---|---|
| prod가 Sync 없이 바로 `Synced`로 바뀜 | `automated:`가 남아 있음 | `kubectl -n argocd get app todo-prod -o jsonpath='{.spec.syncPolicy}'; echo`로 확인 → 지우고 다시 apply |
| Sync 결과에 `namespaces "todo-prod" not found` | 네임스페이스가 없음 | `kubectl create namespace todo-prod` 후 다시 Sync |
| prod web 파드 `ImagePullBackOff` | 태그를 7자리로 적음(GHCR에는 40자리 태그만) | dev의 `newTag`를 그대로 복사 |

## 과제 3. 제목 바꿔 dev에 자동 반영

**무엇을 하나요**: `web/index.html`의 `<h1>할 일</h1>`을 `<h1>할 일 — <이름></h1>`으로 바꿔 push하고, 사람 손 없이 todo-dev 화면에 나타나는지 봅니다. todo-prod는 그대로인지도 봅니다. push부터 dev에 보일 때까지 걸린 시간을 결과 정리 표에 적습니다.

<details><summary>힌트 5 — push했는데 dev가 안 바뀐다</summary>

순서대로 보세요: ① Actions `web` 실행 네 상자가 모두 초록인가 ② 저장소에 봇 커밋이 생겼나 ③ Argo CD는 약 3분마다 확인합니다 — 화면에서 **REFRESH** ④ `kubectl -n todo-dev get deploy web -o jsonpath='{..image}'`
</details>

**이렇게 나오면 성공**: dev 제목 확인 명령이 `<h1>할 일 — <이름></h1>`, prod는 `<h1>할 일</h1>` 그대로. `kubectl -n argocd get app`은 둘 다 `Synced` — prod는 Git(prod 매니페스트)이 안 바뀌었으니 맞는 상태입니다.

## 과제 4. PR로 prod에 올리기

**무엇을 하나요**: dev에서 확인한 web 태그를 브랜치에서 `deploy/overlays/prod`에 적고, PR로 main에 합친 뒤 Argo CD에서 **Sync**를 눌러 todo-prod에 반영합니다.

<details><summary>힌트 6 — 흐름</summary>

`git pull` → `git switch -c promote-web` → prod 파일의 todo-web `newTag`를 dev 파일의 값으로(nano) → commit → `git push -u origin promote-web` → `gh pr create` → PR 화면의 **Files changed**에서 한 줄만 바뀐 것 확인 → **Merge pull request** → `git switch main && git pull` → Argo CD 화면 `todo-prod`가 `OutOfSync`(안 보이면 REFRESH) → **SYNC → SYNCHRONIZE**
</details>

**이렇게 나오면 성공**: 병합 직후 todo-prod는 `OutOfSync`로 기다리고(자동이 아니므로), Sync 뒤 prod 제목에 내 이름.

## 과제 5. Git으로 되돌리기

**무엇을 하나요**: prod에 문제가 생겼다고 치고, 과제 4의 병합 커밋을 `git revert`로 되돌려 원래 제목으로 복구합니다.

<details><summary>힌트 7 — 병합 커밋이 revert가 안 된다</summary>

PR 병합 커밋은 부모가 둘이라 `git revert -m 1 <커밋>`처럼 어느 쪽으로 돌아갈지 알려 줘야 합니다(`1` = main 쪽). 병합 커밋 번호는 `git log --oneline --merges -1`. 되돌린 뒤 prod는 자동이 아니므로 **Sync**를 다시 누릅니다.
</details>

**이렇게 나오면 성공**: revert 커밋을 push하고 Sync하면 prod 제목이 `<h1>할 일</h1>`. dev는 내 이름 그대로.

**이렇게 나오면?**

| 화면 | 원인 | 해결 |
|---|---|---|
| `error: commit … is a merge but no -m option was given.` | 병합 커밋은 부모가 둘 | `git revert -m 1 --no-edit <커밋>` |
| revert를 push했는데 prod가 그대로 | prod는 자동 동기화가 없음 | Argo CD에서 REFRESH → **SYNC** |

## 도전 (선택)
1. api도 prod로 — Jenkins가 dev에 적은 api 태그(`jenkins-N`)를 과제 4처럼 PR로 prod에 올리고 Sync하세요. 확인: `kubectl -n todo-prod get deploy api -o jsonpath='{..image}'`
2. Argo CD 화면의 **HISTORY AND ROLLBACK**으로 todo-dev를 이전 배포로 돌려 보세요. 무엇이 나오나요? todo-prod에서는 어떤가요? Git revert와 무엇이 다른지 적으세요

## 미션 2 결과 정리 표 (리뷰 때 함께 봄)

| # | 확인 | 증거 | 걸린 시간 |
|---|---|---|---|
| 1 | 봇 커밋 `deploy(dev): web …` | 커밋 링크 | Actions 실행 시간 |
| 2 | todo-prod 첫 배포(자동 동기화 없음) | `kubectl -n argocd get app` 출력 | |
| 3 | dev 제목에 내 이름, prod 그대로 | 제목 확인 명령 두 줄 | push부터 dev 반영까지 |
| 4 | prod 승격 PR·Sync | PR 링크, prod 제목 | 병합부터 prod 반영까지 |
| 5 | revert로 prod 복구 | revert 커밋 링크, prod 제목 | |
