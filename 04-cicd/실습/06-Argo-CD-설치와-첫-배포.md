[← 실습 5](./05-Jenkins로-같은-파이프라인.md) · [목차](../CICD-실습.md) · [실습 7 →](./07-태그만-바꿔-배포-되돌리기.md)

# 실습 6. Argo CD 설치와 첫 배포

**무엇을 하나요**: 클러스터 안에 Argo CD를 설치하고, 내 저장소의 `deploy/overlays/dev`를 `todo-dev` 네임스페이스에 배포하게 맡깁니다. 먼저 Argo CD **없이** 손으로 배포하고 손으로 바꾼 것이 그대로 남는 것을 보고, Argo CD에 맡긴 뒤에는 손으로 바꾼 것이 Git에 적힌 상태로 되돌아오는 것을 봅니다. (교안 06장)

**필요한 것**: 실습 5에서 Jenkins가 dev 매니페스트에 api 태그(`jenkins-2`)를 기록한 내 저장소 `cicd-lab`(Public), 미션 1에서 올린 `web` 이미지(`ghcr.io/<아이디>/cicd-lab/web:main`).

> **바로 가기** · [1. 새 클러스터와 Argo CD 설치](#1단계-새-클러스터와-argo-cd-설치) · [2. 브라우저로 로그인](#2단계-브라우저로-로그인) · [3. Argo CD 없이 — 손으로 배포하고 손으로 바꾸기](#3단계-argo-cd-없이--손으로-배포하고-손으로-바꾸기) · [4. Application 파일 쓰기](#4단계-application-파일-쓰기) · [5. 배포 맡기기](#5단계-배포-맡기기) · [6. 손으로 바꾸면 되돌아온다](#6단계-손으로-바꾸면-되돌아온다) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 새 클러스터와 Argo CD 설치

이전 과목 실습이 클러스터에 남아 CPU를 차지하면 새 파드가 `Pending`이 됩니다. **새 클러스터로 시작합니다.**

```bash
cd ~/ktcloud-cloud-native-lab/lab
make reset && make ingress        # 약 1분
make argocd                       # 약 30초, 마지막 줄에 admin 비밀번호
```

**이 명령은**: kind 클러스터를 지우고 새로 만든 뒤, 주소로 들어가는 입구(Ingress)와 Argo CD를 설치함.

**이렇게 나오면 성공**: `make argocd` 마지막 줄

```
Argo CD: http://argocd.localhost  계정 admin / 비밀번호 ...
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `make argocd`가 오래 걸리다 실패(최대 5분 대기) | 이미지 받기가 느리거나 CPU 부족 | `kubectl -n argocd get pods`로 멈춘 파드 확인 후 다시 `make argocd` |
| 비밀번호 줄을 놓침 | 화면이 지나감 | `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' \| base64 -d; echo` |

</details>

## 2단계. 브라우저로 로그인

VS Code PORTS에서 VM의 `80` 포워딩 → `http://argocd.localhost:<포워딩된 포트>` → `admin`과 1단계 비밀번호로 로그인.

**이렇게 나오면 성공**: 빈 Applications 화면(`No applications available to you just yet`류의 안내)과 **+ NEW APP** 버튼이 보임.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `argocd.localhost`가 안 열림 | `make ingress`를 빠뜨렸거나 PORTS에서 80이 아닌 포트를 포워딩 | `make ingress` 다시, PORTS에서 80 포워딩 |
| `404 page not found` | `http://localhost:<포트>`로 엶 | 주소 앞을 `argocd.localhost`로 |

</details>

## 3단계. Argo CD 없이 — 손으로 배포하고 손으로 바꾸기

Argo CD에 맡기기 **전에**, 지금까지처럼 `kubectl`로 직접 배포하고 손으로 바꿔 봅니다. 마지막 줄의 `<아이디>`를 바꿉니다.

```bash
cd ~/cicd-lab && git pull
kubectl create namespace todo-dev
kubectl apply -k deploy/overlays/dev
kubectl -n todo-dev wait --for=condition=Available deploy --all --timeout=180s
kubectl -n todo-dev get pods
kubectl -n todo-dev set image deploy/api api=ghcr.io/<아이디>/cicd-lab/api:main
```

**이 명령은**: 내 저장소의 dev 매니페스트로 todo(db · api · web)를 직접 배포하고(Kubernetes 과목의 `apply -k`), 준비될 때까지 기다린 뒤, 누군가 급하게 api를 `:main` 태그로 손으로 바꾼 상황을 만듦. `kustomization.yaml`에 `namespace: todo-dev`가 적혀 있어도 네임스페이스 자체는 만들지 않으므로 먼저 `create namespace`를 합니다.

**이렇게 나오면 성공** (`apply -k`부터)

```
configmap/todo-config created
secret/todo-secret created
service/api created
service/db created
service/web created
persistentvolumeclaim/db-data created
deployment.apps/api created
deployment.apps/db created
deployment.apps/web created
deployment.apps/api condition met
deployment.apps/db condition met
deployment.apps/web condition met
NAME                   READY   STATUS    RESTARTS   AGE
api-d88475b49-lqxbb    1/1     Running   0          21s
db-86878656ff-44ssm    1/1     Running   0          21s
web-7759d99979-lvzv6   1/1     Running   0          21s
deployment.apps/api image updated
```

**1분쯤 기다린 뒤** 확인합니다.

```bash
kubectl -n todo-dev get deploy api -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
kubectl diff -k deploy/overlays/dev | grep image:
```

**이 명령은**: 지금 클러스터의 api 이미지를 보고, `kubectl diff`로 Git(내 폴더의 매니페스트)과 클러스터가 어디서 다른지 봄.

**이렇게 나오면 성공** — 손으로 바꾼 이미지가 **그대로 남아 있고**, Git과 다릅니다

```
ghcr.io/<아이디>/cicd-lab/api:main
-        image: ghcr.io/<아이디>/cicd-lab/api:main
+        image: ghcr.io/<아이디>/cicd-lab/api:jenkins-2
```

- `-` 줄이 클러스터(지금), `+` 줄이 Git(적힌 것)입니다. 아무도 되돌리지 않고, `kubectl diff`를 일부러 쳐 보기 전에는 다르다는 것도 모릅니다

| | Argo CD 없이 (지금) | Argo CD에 맡기면 (5~6단계) |
|---|---|---|
| 손으로 바꾼 이미지 | 그대로 남음 | 몇 초 만에 Git에 적힌 태그로 되돌아옴 |
| Git과 다른 것 | `kubectl diff`를 쳐야 앎 | 앱 상태 `OutOfSync`로 바로 보임 |
| 지금 무엇이 배포됐나 | 클러스터를 봐야 앎 | Git을 보면 앎 |

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `Error from server (NotFound): error when creating "deploy/overlays/dev": namespaces "todo-dev" not found` (여러 줄) | `create namespace`를 빠뜨림 | `kubectl create namespace todo-dev` 후 `apply -k` 다시 |
| `namespaces "todo-dev" already exists` | 이미 만들었음 | 정상 — 다음 줄로 |
| web 파드 `ImagePullBackOff` | 미션 1을 안 해 `web:main` 이미지가 없음 | 미션 1 과제 1을 먼저 |
| `wait`가 시간 초과, 파드 `Pending` | 클러스터 CPU 부족 | 1단계 `make reset`부터 |
| `diff` 결과의 `+` 줄이 `…api:main` | 실습 5를 못 해 dev 매니페스트가 템플릿 그대로(`main`) | `kubectl -n todo-dev set image deploy/web nginx=nginx:1.28-alpine`으로 web을 바꿔 같은 것을 확인 |

</details>

## 4단계. Application 파일 쓰기

```bash
cd ~/cicd-lab && mkdir -p argocd && nano argocd/app-dev.yaml     # <아이디> 바꾸기
```

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: todo-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<아이디>/cicd-lab.git
    targetRevision: main
    path: deploy/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: todo-dev
  syncPolicy:
    automated:              # Git이 바뀌면 자동 배포
      prune: true           # Git에서 지운 리소스는 클러스터에서도 지운다
      selfHeal: true        # 누가 손으로 바꾸면 Git 상태로 되돌린다
    syncOptions:
    - CreateNamespace=true
```

**이 파일은**: "내 저장소 main의 `deploy/overlays/dev`를 이 클러스터의 `todo-dev`에 배포하고, 계속 맞춰 두라"는 Argo CD 주문서.

| 설정 | 뜻 |
|---|---|
| `source` | 어디서 — 저장소 주소, 브랜치(`main`), 폴더(`deploy/overlays/dev`) |
| `destination` | 어디로 — 이 클러스터, 네임스페이스 `todo-dev` |
| `automated` | Git이 바뀌면 자동으로 맞춤 (없으면 사람이 Sync) |
| `prune` | Git에서 지운 리소스는 클러스터에서도 지움 |
| `selfHeal` | 클러스터를 손으로 바꾸면 Git 상태로 되돌림 |
| 확인 주기 | 기본 약 3분마다 Git 확인 (UI의 **Refresh**로 바로 확인) |

## 5단계. 배포 맡기기

```bash
kubectl apply -f argocd/app-dev.yaml
kubectl -n argocd get app todo-dev -w       # Synced / Healthy 가 보이면 Ctrl+C
kubectl -n todo-dev get pods
kubectl -n todo-dev get deploy api -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
```

**이 명령은**: Application을 만들고, 동기화될 때까지 지켜본 뒤, 배포된 api 이미지를 확인함. 3단계에서 손으로 만든 리소스는 Argo CD가 그대로 넘겨받습니다(새로 만들지 않고 Git에 맞게 고침).

**이렇게 나오면 성공** — 앱이 `OutOfSync`(3단계의 손 변경 때문)에서 몇 초 만에 `Synced` / `Healthy`로, api 이미지는 3단계의 `:main`이 아니라 Jenkins가 기록한 태그

```
NAME       SYNC STATUS   HEALTH STATUS
todo-dev   OutOfSync     Healthy
todo-dev   Synced        Progressing
todo-dev   Synced        Healthy
...
ghcr.io/<아이디>/cicd-lab/api:jenkins-2
```

브라우저 Argo CD 화면에 `todo-dev` 카드가 생기고, 누르면 db · api · web과 그 아래 파드가 나무 모양으로 보입니다.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| 앱이 `Synced`가 되지 않고 UI에 `could not read Username` | 저장소가 Private, 또는 `repoURL`의 `<아이디>`를 안 바꿈 | 파일을 고쳐 다시 apply, 저장소 Public 확인 |
| `no matches for kind "Application"` | Argo CD 설치 전 | 1단계 `make argocd` |
| `kubectl -n argocd get app todo-dev`가 `NotFound` | `metadata.namespace`를 바꿈 | `argocd`로 고쳐 다시 apply |
| 파드 `Pending` | 클러스터 CPU 부족 | 1단계 `make reset`부터 다시 |

</details>

## 6단계. 손으로 바꾸면 되돌아온다

```bash
kubectl -n todo-dev set image deploy/web nginx=nginx:1.28-alpine
kubectl -n todo-dev get deploy web -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
sleep 3; kubectl -n todo-dev get deploy web -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
kubectl -n todo-dev delete svc api && sleep 3 && kubectl -n todo-dev get svc api
kubectl -n todo-dev scale deploy/api --replicas=3 && sleep 10 && kubectl -n todo-dev get deploy api
```

**이 명령은**: web 이미지를 손으로 바꾸고(바로 한 번, 3초 뒤 한 번 확인), Service 하나를 지우고, api를 3개로 늘려 봄.

**이렇게 나오면 성공**: web 이미지가 몇 초 만에 원래대로(`…/web:main`) 돌아오고(selfHeal), 지운 `api` Service도 다시 보이고(`AGE`가 몇 초), api는 다시 1개입니다(매니페스트에 `replicas: 1`이 적혀 있어서).

```
deployment.apps/web image updated
nginx:1.28-alpine
ghcr.io/<아이디>/cicd-lab/web:main
service "api" deleted from todo-dev namespace
NAME   TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)    AGE
api    ClusterIP   10.96.64.26   <none>        3000/TCP   2s
deployment.apps/api scaled
NAME   READY   UP-TO-DATE   AVAILABLE   AGE
api    1/1     1            1           …
```

- Argo CD는 "Git에 적힌 것"을 지킵니다. 매니페스트에 적힌 값(이미지, Service, `replicas: 1`)은 손으로 바꿔도 되돌아옵니다

## 끝났는지 확인
- ☐ 3단계에서 손으로 바꾼 api 이미지(`:main`)가 1분 뒤에도 그대로였음
- ☐ `kubectl -n argocd get app todo-dev`가 `Synced  Healthy`, api 이미지가 `ghcr.io/<아이디>/cicd-lab/api:jenkins-2`
- ☐ 손으로 바꾼 web 이미지, 지운 Service, 늘린 replicas가 원래대로 돌아옴

## 정리
- `todo-dev` 앱과 Argo CD는 실습 7·미션 2에서 계속 씁니다. 지우지 않습니다

## 확인 문제
1. `kubectl -n argocd patch app todo-dev --type merge -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":false}}}}'`로 selfHeal을 끈 뒤 web 이미지를 다시 `nginx:1.28-alpine`으로 바꾸고 1분 기다리세요. 이미지와 `kubectl -n argocd get app todo-dev`의 상태는 어떻게 되나요? selfHeal을 다시 켜면(`true`)? (끝나면 반드시 `true`로 되돌립니다)
2. `kubectl -n todo-dev create configmap memo --from-literal=a=b`로 Git에 없는 리소스를 만들고 1분 기다리세요. `prune: true`인데 memo는 지워지나요? 앱 상태는? 왜 그런가요? (끝나면 `kubectl -n todo-dev delete configmap memo`)
