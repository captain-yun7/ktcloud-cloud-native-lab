[← 미션 1](../미션/01-todo-web-파이프라인.md) · [목차](../CICD-실습.md) · [실습 6 →](./06-Argo-CD-설치와-첫-배포.md)

# 실습 5. Jenkins로 같은 파이프라인

**무엇을 하나요**: 실습 VM 안에 Jenkins를 컨테이너로 띄우고, 저장소의 `Jenkinsfile`로 실습 4와 같은 일(**테스트 → 빌드 → 스캔 → GHCR 올리기**)에 하나를 더해 **dev 매니페스트의 이미지 태그를 바꿔 커밋**까지 하게 만듭니다. 먼저 자격 증명 **없이** 돌려 막히는 것을 보고, 실습 1의 토큰을 Jenkins **자격 증명**에 넣은 뒤 다시 돌립니다. Jenkins는 GitHub Actions와 같은 일을 하는 CI 도구로, 회사 안 서버에 직접 설치해 씁니다. (교안 05장)

**필요한 것**: 실습 4까지 한 `~/cicd-lab`, 실습 1의 토큰(`repo`·`write:packages` 권한), [미션 1](../CICD-미션.md) 끝의 **실습 5 준비**(`make jenkins-image`). 안 했으면 1단계가 이미지를 먼저 만들어 3분쯤 더 걸립니다.

> **바로 가기** · [1. Jenkins 띄우기](#1단계-jenkins-띄우기) · [2. 브라우저로 로그인](#2단계-브라우저로-로그인) · [3. 파이프라인 작업 만들기 (브라우저)](#3단계-파이프라인-작업-만들기-브라우저) · [4. Jenkinsfile 쓰기](#4단계-jenkinsfile-쓰기) · [5. 자격 증명 없이 지금 빌드](#5단계-자격-증명-없이-지금-빌드) · [6. 토큰을 자격 증명에 넣기 (브라우저)](#6단계-토큰을-자격-증명에-넣기-브라우저) · [7. 다시 지금 빌드](#7단계-다시-지금-빌드) · [8. Jenkins가 만든 커밋 받기](#8단계-jenkins가-만든-커밋-받기) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. Jenkins 띄우기

```bash
cd ~/ktcloud-cloud-native-lab && git pull && cd lab
make jenkins
```

**이 명령은**: 수업용 도구를 최신으로 받고, Jenkins 컨테이너를 실행함.

**이렇게 나오면 성공** — 마지막 줄

```
Jenkins 시작 (1분쯤 걸림): http://localhost:8081  계정 admin / 비밀번호 ...
```

`make jenkins`가 미리 해 두는 일

| 하는 일 | 이유 |
|---|---|
| 플러그인·도구(docker, trivy, kustomize)를 넣은 이미지로 실행 | 설치 마법사·플러그인 고르기를 건너뜀 |
| VM의 도커 소켓을 연결 | Jenkins가 VM의 도커로 이미지를 빌드 |
| 작업 폴더 `~/jenkins_home`을 VM과 같은 경로로 연결 | 파이프라인 안의 `docker run -v "$WORKSPACE"`가 VM의 같은 폴더를 가리킴 |
| 메모리 2GB 제한 | VM 16GB에 kind와 함께 쓰기 위해 |

> ⚠️ 도커 소켓을 넘기면 Jenkins가 **VM의 root와 같은 권한**을 갖습니다. 실습에서만 이렇게 하고, 운영에서는 빌드를 별도 에이전트에 맡깁니다. 자세한 원리는 교안 부록 A.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `make: *** No rule to make target 'jenkins'.` | `lab` 폴더가 아니거나 `git pull` 전 | 1단계 명령을 처음부터 |
| 3분 가까이 걸림 | 미션 1 끝 "실습 5 준비"를 안 해 이미지를 지금 만듦 | 기다림 |
| `port is already allocated` | VM에서 다른 컨테이너가 8081을 씀 | `docker ps`로 확인 후 그 컨테이너 정리 |

</details>

## 2단계. 브라우저로 로그인

1. VS Code **PORTS** 탭에서 `8081` 포워딩
2. 브라우저 `http://localhost:<포워딩된 포트>`
3. 계정 `admin`, 비밀번호는 `make jenkins` 마지막 줄에 있습니다. 다시 보려면:

```bash
cat ~/.jenkins-admin-password
```

**이렇게 나오면 성공**: 로그인 뒤 Jenkins 첫 화면(대시보드)이 보임.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 로그인 화면이 안 뜸 | Jenkins가 아직 시작 중 | 1분쯤 기다렸다 새로고침 |

</details>

## 3단계. 파이프라인 작업 만들기 (브라우저)

1. 대시보드 왼쪽 **새로운 Item**(New Item)
2. 이름 `api` → **Pipeline** 선택 → **OK**
3. 설정 화면 맨 아래 **Pipeline** 칸
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/<아이디>/cicd-lab.git`
   - Branch Specifier: `*/master`를 **`*/main`** 으로 고침
   - Script Path: `Jenkinsfile`(기본값 그대로)
4. **저장**(Save)

**이 설정은**: 파이프라인 내용을 Jenkins 화면이 아니라 내 저장소의 `Jenkinsfile`에서 읽게 함. 공개 저장소라 Credentials 칸은 비워 둡니다.

## 4단계. Jenkinsfile 쓰기

저장소 맨 위에 `Jenkinsfile`을 만듭니다. `REPO`는 내 저장소 이름(`cicd-lab`) 그대로 둡니다.

```bash
cd ~/cicd-lab && git pull
nano Jenkinsfile                # 아래 내용 붙여 넣기
git add Jenkinsfile && git commit -m "ci: Jenkinsfile" && git push
```

```groovy
pipeline {
  agent any
  options { disableConcurrentBuilds() }
  triggers { pollSCM('H/2 * * * *') }          // 2분마다 GitHub를 확인 (VM은 GitHub가 들어올 수 없어 웹훅 대신)

  environment {
    GH = credentials('github')                  // GH_USR, GH_PSW 가 생긴다
    REPO = "cicd-lab"                            // 내 저장소 이름
    IMAGE = "ghcr.io/${env.GH_USR.toLowerCase()}/${env.REPO}/api"
    TAG = "jenkins-${env.BUILD_NUMBER}"
  }

  stages {
    stage('시작 조건') {
      // api가 바뀌지 않은 커밋(Jenkins 자신이 만든 매니페스트 커밋 포함)이면 아무것도 하지 않는다
      when { not { anyOf { changeset 'api/**'; triggeredBy 'UserIdCause' } } }
      steps {
        script { currentBuild.result = 'NOT_BUILT'; currentBuild.description = 'api 변경 없음' }
      }
    }
    stage('테스트') {
      when { anyOf { changeset 'api/**'; triggeredBy 'UserIdCause' } }
      steps {
        sh 'docker run --rm -v "$WORKSPACE/api":/src -w /src node:22-alpine npm test'
      }
    }
    stage('빌드') {
      when { anyOf { changeset 'api/**'; triggeredBy 'UserIdCause' } }
      steps { sh 'docker build -t $IMAGE:$TAG api' }
    }
    stage('스캔') {
      when { anyOf { changeset 'api/**'; triggeredBy 'UserIdCause' } }
      steps {
        sh 'trivy image --cache-dir "$JENKINS_HOME/.trivy" --exit-code 1 --severity CRITICAL --ignore-unfixed $IMAGE:$TAG'
      }
    }
    stage('올리기') {
      when { anyOf { changeset 'api/**'; triggeredBy 'UserIdCause' } }
      steps {
        sh 'echo "$GH_PSW" | docker login ghcr.io -u "$GH_USR" --password-stdin'
        sh 'docker push $IMAGE:$TAG'
      }
    }
    stage('매니페스트 갱신') {
      when { anyOf { changeset 'api/**'; triggeredBy 'UserIdCause' } }
      steps {
        sh '''
          git checkout -B main origin/main
          cd deploy/overlays/dev
          kustomize edit set image todo-api=$IMAGE:$TAG
          cd -
          git -c user.name="jenkins" -c user.email="jenkins@lab.local" commit -am "deploy(dev): api $TAG [skip ci]"
          git pull --rebase https://$GH_USR:$GH_PSW@github.com/$GH_USR/$REPO.git main
          git push https://$GH_USR:$GH_PSW@github.com/$GH_USR/$REPO.git main
        '''
      }
    }
  }
  post {
    always { sh 'docker logout ghcr.io || true' }
  }
}
```

**이 파일은**: 실습 4의 GitHub Actions 파이프라인과 같은 순서를 Jenkins 문법으로 적은 것. 마지막에 dev 매니페스트의 api 이미지 태그를 바꿔 커밋까지 함(06장 Argo CD가 이 커밋을 보고 배포).

| 줄 | 뜻 |
|---|---|
| `credentials('github')` | ID `github` 자격 증명을 꺼내 `GH_USR`(아이디)·`GH_PSW`(토큰) 두 변수로 |
| `TAG = "jenkins-${BUILD_NUMBER}"` | 빌드 번호로 태그 — 몇 번째 빌드의 이미지인지 알 수 있음 |
| `stage('테스트')` … `stage('올리기')` | 실습 4의 test · scan · push와 같은 일 |
| `stage('매니페스트 갱신')` | `deploy/overlays/dev`의 api 이미지를 방금 올린 태그로 바꿔 커밋·push |
| `triggers { pollSCM(...) }`, `when { … }` | 자동 실행과 건너뛰기 조건 (확인 문제 1) |
| `[skip ci]` | 이 커밋으로 GitHub Actions를 돌리지 말라는 표시 |

## 5단계. 자격 증명 없이 지금 빌드

Jenkinsfile은 `credentials('github')`로 토큰을 꺼내 씁니다. 그 자격 증명을 아직 넣지 않은 채로 돌려 봅니다. Jenkins의 `api` 작업에서 왼쪽 **지금 빌드**(Build Now)를 누르고, 빌드 `#1` → **Console Output**을 엽니다.

**이렇게 나오면 성공** — 몇 초 만에 실패하고, 단계(테스트 · 빌드 …)는 하나도 시작하지 않습니다(이 단계는 실패하는 것이 맞습니다)

```
Commit message: "ci: Jenkinsfile"
First time build. Skipping changelog.
...
ERROR: github
Finished: FAILURE
```

- `ERROR: github` = ID가 `github`인 자격 증명을 찾지 못했다는 뜻입니다. 저장소에서 Jenkinsfile은 받아 왔지만(`Commit message` 줄), 토큰이 없으니 이미지를 올리지도, 매니페스트를 고쳐 push하지도 못합니다
- 중간에 긴 오류 줄(`MissingContextVariableException` 등)이 섞여 보입니다. 맨 아래 `post` 정리 단계가 함께 실패한 것이라 무시해도 됩니다

| | 자격 증명 없음 (지금) | 자격 증명 `github` 있음 (6~7단계) |
|---|---|---|
| 빌드 | 몇 초 만에 `ERROR: github` → `FAILURE` | 다섯 단계 모두 초록 |
| 토큰을 둘 곳 | 없음 — Jenkinsfile에 적으면 공개 저장소에 그대로 노출 | Jenkins 자격 증명 — 암호화 저장, 로그에는 `****` |

## 6단계. 토큰을 자격 증명에 넣기 (브라우저)

Jenkins 관리(Manage Jenkins) → **Credentials** → **System** → **Global credentials (unrestricted)** → **Add Credentials**

| 항목 | 값 |
|---|---|
| Kind | Username with password |
| Username | GitHub 아이디 |
| Password | 실습 1에서 만든 토큰 |
| ID | `github` (Jenkinsfile이 이 이름으로 찾음) |

→ **Create**

> ⚠️ 토큰은 **Jenkins 자격 증명에만** 넣습니다. Jenkinsfile·저장소에는 절대 적지 않습니다.

## 7단계. 다시 지금 빌드

`api` 작업에서 **지금 빌드**를 다시 누릅니다. 이번 빌드는 `#2`입니다.

**이렇게 나오면 성공**: 작업 화면의 단계 상자 `테스트 → 빌드 → 스캔 → 올리기 → 매니페스트 갱신`이 모두 초록(`시작 조건`은 회색). Console Output 끝에는 이렇게 보입니다. 처음 빌드는 Trivy DB를 받느라 1분쯤 걸립니다.

```
# pass 3
# fail 0
...
Successfully tagged ghcr.io/<아이디>/cicd-lab/api:jenkins-2
...
+ git push https://****@github.com/<아이디>/cicd-lab.git main
To https://github.com/<아이디>/cicd-lab.git
   …  main -> main
...
Finished: SUCCESS
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 여전히 `ERROR: github` | 자격 증명 ID 오타·빈칸 | 자격 증명 목록에서 ID 확인 → `github`로 새로 만듦 |
| `올리기`에서 실패(`denied`) | 토큰에 `write:packages` 권한이 없음 | 권한을 넣어 토큰을 다시 만들고, 자격 증명 `github`의 Password를 바꿈 |
| `스캔`에서 실패 | 바탕 이미지에 고칠 수 있는 CRITICAL(실습 4 시험 PR을 실수로 합친 경우 등) | `grep ^FROM api/Dockerfile`이 `FROM node:22-alpine`인지 |
| `매니페스트 갱신`에서 `nothing to commit` | 같은 태그가 이미 적혀 있음 | 지금 빌드를 한 번 더(빌드 번호가 바뀌어 태그가 달라짐) |

</details>

## 8단계. Jenkins가 만든 커밋 받기

```bash
cd ~/cicd-lab
git pull
git log --oneline -2
grep -A2 "name: todo-api" deploy/overlays/dev/kustomization.yaml
```

**이 명령은**: Jenkins가 GitHub에 남긴 매니페스트 커밋을 VM으로 받아, 바뀐 이미지 태그를 확인함.

**이렇게 나오면 성공**

```
 deploy/overlays/dev/kustomization.yaml | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
40529fb deploy(dev): api jenkins-2 [skip ci]
abd4f09 ci: Jenkinsfile
- name: todo-api
  newName: ghcr.io/<아이디>/cicd-lab/api
  newTag: jenkins-2
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 다음 `git push`가 `rejected (fetch first)` | Jenkins가 저장소에 커밋을 남겨 내 VM보다 앞서 있음 | `git pull --rebase` 뒤 push ([실습 2 확인 문제 2](./02-Git으로-변경-올리기.md#확인-문제)) |

</details>

## 끝났는지 확인
- ☐ 브라우저에서 admin으로 로그인해 Jenkins 대시보드가 보임
- ☐ 자격 증명 없이 돌린 빌드 `#1`이 `ERROR: github`로 실패
- ☐ 빌드 `#2`의 다섯 단계가 모두 초록
- ☐ `git log --oneline -1`이 `deploy(dev): api jenkins-2 [skip ci]`, dev 매니페스트의 `newTag: jenkins-2`

## 정리
- Jenkins 컨테이너·자격 증명·`api` 작업은 실습 7과 미션 2에서 계속 씁니다. 지우지 않습니다

## 확인 문제
1. 7단계가 끝나고 2~3분 뒤 Jenkins `api` 작업의 빌드 목록을 보세요. 누르지 않은 빌드 `#3`이 생겼나요? 그 빌드의 결과와 Console Output 첫 줄·`Commit message` 줄은 무엇인가요? Jenkinsfile의 어느 줄 때문인가요?
2. 토큰에 `write:packages` 권한이 없으면 파이프라인은 어느 단계에서 멈추나요? 그 앞 단계들은 어떻게 되나요?
