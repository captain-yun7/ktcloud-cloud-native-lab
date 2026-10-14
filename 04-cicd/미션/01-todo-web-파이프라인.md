[목차](../CICD-미션.md) · [미션 2 →](./02-push-한-번으로-dev-배포-prod는-승인.md)

# 미션 1. todo-web 파이프라인 완성

**무엇을 하나요**: 실습 3·4에서 **api**에 만든 파이프라인(테스트 → 빌드·Trivy 게이트 → main일 때만 GHCR에 올리기)을 **web**(nginx 화면)에도 만듭니다. web에는 Node 코드가 없어서 `npm test` 대신 **nginx 설정 검사**(`nginx -t`)를 테스트로 씁니다. 이 미션에서 올린 `web` 이미지는 06장 Argo CD 실습에서 그대로 배포됩니다.

| 과제 | 한 줄 요약 | 확인 방법 |
|---|---|---|
| 과제 1 | `.github/workflows/web.yml` — `test`(nginx 설정 검사) → `scan`(Trivy 게이트) → `push`(main일 때만) | Actions 화면의 job 그래프 세 상자 초록, Packages에 `cicd-lab/web` |
| 과제 2 | 설정을 일부러 깨뜨린 PR은 `test`에서 막히고 아무것도 올라가지 않음 | PR 실행의 `test` 빨간 X, `scan`·`push` 회색 |
| 과제 3 | VM에서 `web:main` 이미지를 받아 확인 | `docker pull` 성공 |

> **바로 가기** · [과제 1. web.yml — test · scan · push](#과제-1-webyml--test--scan--push) · [과제 2. 깨진 설정은 PR에서 막기](#과제-2-깨진-설정은-pr에서-막기) · [과제 3. VM에서 web 이미지 받기](#과제-3-vm에서-web-이미지-받기) · [도전 (선택)](#도전-선택) · [미션 1 결과 정리 표 (리뷰 때 함께 봄)](#미션-1-결과-정리-표-리뷰-때-함께-봄) · [실습 5 준비 — Jenkins 이미지 미리 만들기](#실습-5-준비--jenkins-이미지-미리-만들기)

## 공통 정보
- 시작 파일: 실습 4에서 완성한 `.github/workflows/api.yml`을 복사합니다 — `cp .github/workflows/api.yml .github/workflows/web.yml`
- web 폴더: `web/Dockerfile`(nginx:1.29-alpine), `web/default.conf`(nginx 설정 — `/api/` 요청을 `http://api:3000`으로 넘김), `index.html`, `app.js`
- 이미지 주소: `ghcr.io/<아이디>/cicd-lab/web` (실습 2 7단계에서 매니페스트에 넣은 주소)
- 실행 보기: `gh run watch` 또는 브라우저 **Actions** 탭

## 과제 1. web.yml — test · scan · push

**무엇을 하나요**: `web.yml`이 web 폴더가 바뀔 때 돌고, `test` → `scan` → `push` 세 job으로 web 이미지를 검사해 올리게 만듭니다. `test` job은 nginx 설정 검사입니다.

<details><summary>힌트 1 — 어디를 바꾸나</summary>

복사한 파일에서 바꿀 곳은 세 군데입니다. ① `name:` ② `on:`의 경로 세 줄(`api` → `web`) ③ `env:`의 `APP`. 나머지 scan·push job은 `${{ env.APP }}`를 쓰므로 그대로 둡니다. 마지막으로 `test` job의 단계(setup-node, `npm ci`·`npm test`)를 nginx 설정 검사로 바꿉니다.
</details>

<details><summary>힌트 2 — nginx 설정 검사 명령</summary>

nginx 이미지를 잠깐 띄워 내 설정 파일을 넣고 `nginx -t`(설정 검사)만 실행합니다.

```bash
docker run --rm --add-host api:127.0.0.1 \
  -v "$PWD/web/default.conf:/etc/nginx/conf.d/default.conf:ro" \
  nginx:1.29-alpine nginx -t
```

`--add-host`를 빼면 `host not found in upstream "api"`로 실패합니다. 설정에 적힌 `api`라는 이름을 nginx가 시작할 때 찾는데, 러너에는 그런 이름이 없기 때문입니다.
</details>

**이렇게 나오면 성공**: `git add .github/workflows/web.yml` → commit → push 뒤 Actions에 `web` 실행이 생기고 `test → scan → push` 세 상자가 초록. `test` 로그에 다음 두 줄. 저장소 오른쪽 **Packages**에 `cicd-lab/web`이 생김.

```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

**이렇게 나오면?**

| 화면 | 원인 | 해결 |
|---|---|---|
| push했는데 web 실행이 없음 | 새 파일이라 `commit -am`으로 안 들어감 | `git add .github/workflows/web.yml` 후 커밋 |
| api 실행이 생기고 web은 없음 | `on:`의 경로를 안 바꿈 | `web/**`, `.github/workflows/web.yml` |
| test에서 `host not found in upstream "api"` | `--add-host api:127.0.0.1` 빠짐 | 힌트 2 |
| test에서 `npm ci` 오류 | test job을 안 바꿈(web 폴더에 `package.json`이 없음) | 힌트 1 마지막 문장 |

## 과제 2. 깨진 설정은 PR에서 막기

**무엇을 하나요**: 브랜치에서 `web/default.conf`의 `listen 80;` 줄 끝 `;`를 빼고 PR을 엽니다. test가 실패하고 scan·push는 돌지 않는지 봅니다. 확인했으면 PR을 닫습니다(합치지 않음).

<details><summary>힌트 3 — 실습 4의 흐름 그대로</summary>

`git switch -c web-broken` → `sed -i 's/listen 80;/listen 80/' web/default.conf` → commit → `git push -u origin web-broken` → `gh pr create -t "web 설정 시험" -b "test에서 막히는지"` → `gh run watch` → `gh pr close -d web-broken`
</details>

**이렇게 나오면 성공**: PR 실행에서 `test` 빨간 X, `scan`·`push` 회색. test 로그:

```
nginx: [emerg] directive "listen" is not terminated by ";" in /etc/nginx/conf.d/default.conf:4
nginx: configuration file /etc/nginx/nginx.conf test failed
```

## 과제 3. VM에서 web 이미지 받기

**무엇을 하나요**: 과제 1이 올린 이미지를 VM에서 받습니다. 06장에서 Argo CD가 같은 주소로 받습니다.

**이렇게 나오면 성공**: `docker pull ghcr.io/<아이디>/cicd-lab/web:main` → `Status: Downloaded newer image for ghcr.io/<아이디>/cicd-lab/web:main`

## 도전 (선택)
1. **멀티아치** — push job이 amd64(보통 서버)와 arm64(M 시리즈 Mac 등) 두 가지를 같은 이름으로 올리게 하세요. 교안 부록 A를 참고합니다. 확인: `docker buildx imagetools inspect ghcr.io/<아이디>/cicd-lab/web:main`에 `linux/amd64`, `linux/arm64`
2. **HIGH까지 막으면?** — web.yml의 게이트를 `--severity HIGH,CRITICAL`로 바꿔 main에 push하면 어떻게 되나요? 이미지를 고치지 않고 통과시키려면 `web/Dockerfile`에 무엇을 더하면 될까요? (실습 4 5단계)

## 미션 1 결과 정리 표 (리뷰 때 함께 봄)

| # | 확인 | 증거 | 걸린 시간 |
|---|---|---|---|
| 1 | web 실행 세 상자 초록 | Actions 실행 링크 | |
| 2 | 깨진 설정 PR의 test 빨간 X | PR 링크, test 로그 첫 오류 줄 | |
| 3 | VM에서 web:main pull | `Status:` 줄 | |
| 도전 | 멀티아치 / HIGH 게이트 | imagetools 출력 / scan 로그 `Total:` 줄 | |

## 실습 5 준비 — Jenkins 이미지 미리 만들기

다음 장(Jenkins)에서 쓸 이미지를 미리 만들어 둡니다. 처음 만들 때 몇 분 걸리므로 미션을 마친 뒤 실행해 두면 실습 5가 빨라집니다.

```bash
cd ~/ktcloud-cloud-native-lab && git pull && cd lab
make jenkins-image
```

**이렇게 나오면 성공**: `Jenkins 이미지 준비 완료`

---

[목차](../CICD-미션.md) · [미션 2 →](./02-push-한-번으로-dev-배포-prod는-승인.md)
