[목차](../클라우드-보안-미션.md) · [미션 2 →](./02-shop-네임스페이스-격리.md)

# 미션 1. 취약한 memo-api 고치기

**무엇을 하나요**: 메모 API `memo-api`가 보안 점검에서 **반려**되었습니다. 이유를 도구로 찾고, 이미지(Dockerfile)와 매니페스트(YAML)를 고쳐 기준을 모두 통과시킵니다. 실습 2~5(이미지 스캔, root 아닌 이미지, SecurityContext, Secret)를 한 앱에 모아 적용하는 미션입니다. 앱 코드(`app.py`, 파이썬)는 고치지 않습니다.

| 과제 | 한 줄 요약 |
|---|---|
| 과제 1 | 반려 사유를 도구로 찾기 — 증거 모으기 |
| 과제 2 | 이미지 고치기 — CRITICAL 0, 설정 경고 0, 이력에 키 없음 |
| 과제 3 | 매니페스트 고치기 — restricted에서 Running, 키는 Secret, 비루트·읽기 전용·토큰 없음 |
| 도전 (선택) | distroless로 만들어 비교, trivy k8s로 남은 항목 판단 |

> **바로 가기** · [준비](#준비) · [과제 1. 반려 사유를 도구로 찾기](#과제-1-반려-사유를-도구로-찾기) · [과제 2. 이미지 고치기](#과제-2-이미지-고치기) · [과제 3. 매니페스트 고치기](#과제-3-매니페스트-고치기) · [도전 (선택)](#도전-선택) · [미션 1 결과 정리 표](#미션-1-결과-정리-표) · [실습 9 준비 — Kyverno 이미지 미리 받기](#실습-9-준비--kyverno-이미지-미리-받기)

## 준비

```bash
cd ~/ktcloud-cloud-native-lab && git pull
cp -r 03-클라우드-보안/memo-api ~/sec/memo && cd ~/sec/memo
ls                     # app.py  Dockerfile  memo-api.yaml
docker build -t memo-api:bad .
kind load docker-image memo-api:bad --name lab
kubectl create namespace memo
kubectl apply -f memo-api.yaml
kubectl -n memo rollout status deployment/memo-api
kubectl -n memo exec deploy/memo-api -- python -c "import urllib.request;print(urllib.request.urlopen('http://127.0.0.1:8000').read().decode())"
```

**이 명령은**: 미션 자료를 `~/sec/memo`로 복사하고, 고치기 전 이미지 `memo-api:bad`를 만들어 클러스터에 넣은 뒤 `memo` 네임스페이스에 띄웁니다. 마지막 줄은 파드 안에서 API를 한 번 불러 응답을 봅니다(이 이미지에는 `wget`이 없어 파이썬으로 부름). 처음 빌드는 큰 바탕 이미지(`python:3.9`)를 받느라 1~2분 걸립니다.

**이렇게 나오면 성공**: 마지막 줄

```
memo api ok (key set: True, uid: 0)
```

- `key set: True` = API 키를 받았다는 뜻, `uid: 0` = root로 돈다는 뜻입니다

**통과 기준** (과제 2·3에서 하나씩 맞춥니다)

| # | 기준 | 확인 방법 |
|---|---|---|
| 1 | 이미지에 **CRITICAL 취약점 0** | `trivy image --severity CRITICAL --exit-code 1 memo-api:fixed; echo $?` → `0` (실습 2 확인 문제 2) |
| 2 | Dockerfile 설정 경고 **0** | `trivy config Dockerfile` |
| 3 | 이미지 **이력에 API 키가 없음** | `docker history --no-trunc memo-api:fixed \| grep memo-live` → 아무것도 안 나옴 |
| 4 | `memo` 네임스페이스에 **restricted** 라벨을 붙인 뒤에도 파드 Running | `kubectl label ns memo pod-security.kubernetes.io/enforce=restricted` (실습 8) |
| 5 | API 키는 **Secret**에서 받음, 응답에 `key set: True` | 위 exec 명령 |
| 6 | uid가 0이 아님, 파일시스템 읽기 전용, 서비스 계정 토큰 없음 | 응답의 `uid:` 값, `ls /var/run/secrets/kubernetes.io` |

## 과제 1. 반려 사유를 도구로 찾기

**무엇을 하나요**: 고치기 전에 **증거**를 모읍니다. 실습 2(이미지 스캔), 실습 3(Dockerfile 점검)에서 쓴 명령으로 `memo-api:bad`와 `Dockerfile`을 검사하고, 찾은 문제를 아래 결과 정리 표의 "반려 사유"·"찾은 방법" 칸에 적습니다.

<details><summary>힌트 1 — 어떤 명령으로</summary>

세 가지면 반려 사유가 거의 다 나옵니다: `trivy image`(실습 2), `trivy config .`(실습 3), `docker history --no-trunc memo-api:bad`(이미지를 만든 명령 기록).
</details>
<details><summary>힌트 2 — 매니페스트 쪽 문제</summary>

`memo-api.yaml`을 `cat`으로 읽고, 실습 4의 `api-secure.yaml`과 비교해 보세요. 실습 1에서 본 서비스 계정 토큰은 `kubectl -n memo exec deploy/memo-api -- ls /var/run/secrets/kubernetes.io/serviceaccount`로 확인합니다.
</details>

## 과제 2. 이미지 고치기

**무엇을 하나요**: `Dockerfile`을 고쳐 `memo-api:fixed`로 빌드하고 기준 1~3을 통과시킵니다. 고친 뒤 `kind load docker-image memo-api:fixed --name lab`으로 클러스터에 넣습니다.

<details><summary>힌트 1 — 바탕 이미지</summary>

실습 2에서 바탕 이미지에 따라 취약점 수가 크게 달랐습니다. 같은 파이썬의 **새 버전 + 작은 바탕**(예: `python:3.13-slim`)을 `trivy image --severity HIGH,CRITICAL --table-mode detailed 이미지 | grep Total`로 스캔해 비교한 뒤 고르세요.
</details>
<details><summary>힌트 2 — 설정 경고</summary>

실습 3의 `Dockerfile.safe`처럼 `USER`(숫자 UID, 예: 10001)와 `HEALTHCHECK`를 넣습니다. 이 앱은 8000번에서 듣고, 파이썬 이미지에는 `wget`이 없으니 `HEALTHCHECK CMD python -c "…"`처럼 파이썬으로 부릅니다.
</details>
<details><summary>힌트 3 — API 키</summary>

`ENV`로 넣은 값은 이미지 이력에 그대로 남습니다. Dockerfile에서 지우고, 키는 과제 3에서 Secret으로 넣습니다.
</details>

## 과제 3. 매니페스트 고치기

**무엇을 하나요**: `memo-api.yaml`을 고쳐 기준 4~6을 통과시킵니다. API 키는 Secret `memo-key`로 넣고, `memo` 네임스페이스에 restricted 라벨을 붙입니다. restricted 라벨이 붙은 네임스페이스에서는 `runAsNonRoot` 같은 설정이 빠진 파드가 `FailedCreate`로 거부됩니다. 09장(실습 8)에서 자세히 배우고, 여기서는 라벨 한 줄로 붙여 봅니다. restricted가 요구하는 설정은 실습 4의 `api-secure.yaml`에 모두 들어 있습니다.

<details><summary>힌트 1 — 키를 Secret으로</summary>

`kubectl -n memo create secret generic memo-key --from-literal=API_KEY=…`로 만들고(키 이름 `API_KEY`, 값은 지금 매니페스트의 값), Deployment에서 `envFrom`의 `secretRef` 또는 `env`의 `secretKeyRef`(실습 4 파일의 `DB_PASSWORD`와 같은 모양)로 받습니다. 이미지는 `memo-api:fixed`로 바꿉니다.
</details>
<details><summary>힌트 2 — 라벨을 붙였는데 파드가 그대로 떠 있다</summary>

Pod Security는 **새로 만드는 파드**를 검사합니다. `kubectl -n memo rollout restart deploy/memo-api` 후 `kubectl -n memo get events --field-selector reason=FailedCreate`를 보세요. Deployment는 적용되지만 파드 생성이 `FailedCreate`로 거부되고, 이전 파드는 계속 돕니다.
</details>
<details><summary>힌트 3 — readOnlyRootFilesystem을 켜면 앱이 죽지 않을까</summary>

이 앱은 파일을 쓰지 않습니다. 켜 보고 실제로 확인하세요. 실습 4의 `api-secure.yaml`에서 파드·컨테이너 `securityContext` 묶음을 그대로 가져오면 됩니다.
</details>
<details><summary>힌트 4 — 서비스 계정 토큰</summary>

실습 5의 4단계에서 api에 넣은 한 줄(`automountServiceAccountToken`)을 찾아보세요.
</details>

## 도전 (선택)

1. **distroless** 파이썬 이미지(`gcr.io/distroless/python3-debian13:nonroot`)로 만들어 크기·취약점을 slim과 비교하세요. 무엇을 잃나요?
2. 교안 부록 A2에서 본 `trivy k8s`로 memo 네임스페이스의 설정을 점검하세요(`trivy k8s --include-namespaces memo --scanners misconfig --report summary`). 고친 Deployment에 남은 항목을 읽고, 고칠지 말지 이유와 함께 적으세요

## 미션 1 결과 정리 표

| # | 반려 사유 | 찾은 방법 (명령) | 고친 내용 | 확인 결과 |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |
| 6 | | | | |
| 전후 | 크기 / HIGH·CRITICAL 수 | | | |

## 실습 9 준비 — Kyverno 이미지 미리 받기

미션 1을 마쳤으면 09장(실습 9)에서 쓰는 정책 엔진 Kyverno의 이미지를 **미리 받아 둡니다.** 여러 명이 실습 9에서 한꺼번에 받으면 느려서 설치가 실패할 수 있습니다.

```bash
cd ~/ktcloud-cloud-native-lab && git pull && cd lab
make kyverno-images        # "Kyverno 이미지 준비 완료"가 나오면 끝 (VM에 남으므로 클러스터를 다시 만들어도 괜찮습니다)
```
