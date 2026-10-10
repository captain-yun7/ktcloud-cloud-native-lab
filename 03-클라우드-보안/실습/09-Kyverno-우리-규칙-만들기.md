[← 실습 8](./08-Pod-Security-Admission-라벨-하나로-거부되게.md) · [목차](../클라우드-보안-실습.md) · [실습 10 →](./10-SBOM과-서명-무엇이-들었나-바뀌지-않았나.md)

# 실습 9. Kyverno — 우리 규칙 만들기

**무엇을 하나요**: PSA는 정해진 세 수준뿐입니다. "latest 태그 금지"처럼 **우리가 정한 규칙**은 정책 엔진(Kyverno)으로 만듭니다. 규칙이 있으면 `todo-web:latest`로 바꾸는 명령을 친 그 자리에서 `denied the request`가 나옵니다. 먼저 정책이 **없을 때** web을 latest 이미지로 바꾸면 그대로 받아들여지는 것을 본 뒤, 정책 엔진 Kyverno를 설치하고, 태그가 없거나 latest인 이미지를 거부하는 정책을 만들어 todo에서 시험합니다. (교안 09장)

**필요한 것**: 실습 저장소 `~/ktcloud-cloud-native-lab`. 미션 1 끝의 [실습 9 준비](../미션/01-취약한-memo-api-고치기.md#실습-9-준비--kyverno-이미지-미리-받기)에서 Kyverno 이미지를 받아 두었으면 더 빠릅니다(안 받았어도 됩니다).

> **바로 가기** · [1. 정책 없이 latest로 바꿔 보기](#1단계-정책-없이-latest로-바꿔-보기) · [2. Kyverno 설치](#2단계-kyverno-설치) · [3. 정책 파일 쓰고 적용하기](#3단계-정책-파일-쓰고-적용하기) · [4. todo에서 시험하기](#4단계-todo에서-시험하기) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 정책 없이 latest로 바꿔 보기

아직 정책이 없습니다. 누군가 web의 이미지를 태그 `latest`로 바꿨다고 해 봅니다.

```bash
kubectl -n todo set image deployment/web nginx=todo-web:latest
kubectl -n todo get pods -l app=web          # 15초쯤 뒤
```

**이 명령은**: `set image deployment/이름 컨테이너=이미지` = Deployment web의 컨테이너 `nginx`의 이미지를 바꿈(새 파드로 롤링 업데이트). `-l app=web` = web 파드만.

**이렇게 나오면 성공** — 바뀌는 것이 받아들여지고, 새 파드는 이미지를 못 받습니다.

```
deployment.apps/web image updated
NAME                   READY   STATUS             RESTARTS   AGE
web-5ffd588f4b-htrg4   0/1     ImagePullBackOff   0          16s
web-b59db6d76-dfnrz    1/1     Running            0          10m
```

- 아무도 막지 않았습니다. `todo-web:latest`라는 이미지는 없어서 새 파드는 `ImagePullBackOff`(받기 실패, 잠시 뒤 다시 시도)입니다. 처음 몇 초는 `ErrImagePull`로 보입니다
- 옛 web 파드가 `Running`으로 남아 있어 화면은 아직 됩니다(새 파드가 준비되지 않으면 옛 파드를 지우지 않음 — 실습 4 2단계와 같음). 이미지가 실제로 있는 latest였다면 **언제 받았느냐에 따라 다른 내용**이 돌았을 것입니다

원래 이미지로 되돌립니다.

```bash
kubectl -n todo set image deployment/web nginx=todo-web:v1
kubectl -n todo rollout status deployment/web
```

```
deployment.apps/web image updated
deployment "web" successfully rolled out
```

- 실패하던 새 파드는 `Terminating`으로 사라지고 옛 파드가 그대로 남습니다. 4단계에서 정책을 건 뒤 **같은 명령**을 다시 칩니다

## 2단계. Kyverno 설치

```bash
cd ~/ktcloud-cloud-native-lab && git pull && cd lab
make kyverno
```

**이 명령은**: Kyverno 이미지 6개를 VM 도커에 받고(받아 두었으면 건너뜀) kind에 넣은 뒤, 아래 명령으로 설치하고 정책을 받을 준비가 될 때까지 기다립니다.

```bash
helm upgrade --install kyverno kyverno --repo https://kyverno.github.io/kyverno/ --version 3.9.1 \
  -n kyverno --create-namespace --wait
```

이미지를 먼저 넣는 이유: 설치 중에 외부 저장소가 느리면 `--wait`가 5분을 넘겨 실패합니다(s30에서 한 번 303초). 미리 넣으면 약 20초에 끝납니다.

**이렇게 나오면 성공**: 약 20초 뒤 컨트롤러 4개가 `Running`

```
Kyverno 이미지 준비 완료
NAME                                             READY   STATUS    RESTARTS   AGE
kyverno-admission-controller-769b8f7647-nh5sw    1/1     Running   0          13s
kyverno-background-controller-86d8df7447-knxs8   1/1     Running   0          13s
kyverno-cleanup-controller-86c886ffff-52pmv      1/1     Running   0          13s
kyverno-reports-controller-57c7978d69-xhhx2      1/1     Running   0          13s
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `make: *** No rule to make target 'kyverno'.` | `lab` 폴더 밖이거나 `git pull`을 안 함 | `cd ~/ktcloud-cloud-native-lab && git pull && cd lab` 후 다시 |

</details>

## 3단계. 정책 파일 쓰고 적용하기

```bash
cd ~/sec
nano disallow-latest.yaml
```

```yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: disallow-latest-tag
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: [v1]
      operations: [CREATE, UPDATE]
      resources: [pods]
  validations:
  - expression: "object.spec.containers.all(c, c.image.contains(':') && !c.image.endsWith(':latest'))"
    message: "이미지 태그를 명시하고 latest는 쓰지 마세요"
```

**이 파일은**

| 줄 | 뜻 |
|---|---|
| `kind: ValidatingPolicy` | Kyverno의 "검사해서 통과·거부하는" 정책. 네임스페이스가 없으니 **클러스터 전체**에 걸림 |
| `validationActions: [Deny]` | 규칙에 어긋나면 **거부** |
| `matchConstraints` … `operations: [CREATE, UPDATE]`, `resources: [pods]` | 파드를 만들거나(CREATE) 바꿀 때(UPDATE) 검사 |
| `expression: "…"` | 모든 컨테이너(`containers.all`)의 이미지에 `:`(태그)가 있고 `:latest`로 끝나지 않아야 통과 |
| `message` | 거부할 때 보여 줄 문장 |

```bash
kubectl apply -f disallow-latest.yaml
kubectl get validatingpolicy
```

**이렇게 나오면 성공**: `READY`가 `true`

```
validatingpolicy.policies.kyverno.io/disallow-latest-tag created
NAME                  AGE   READY
disallow-latest-tag   5s    true
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `failed calling webhook "validate-policy.kyverno.svc" … connection refused` | Kyverno가 아직 준비 중 | 몇 초 뒤 **같은 apply를 다시** |
| `error: resource mapping not found … no matches for kind "ValidatingPolicy"` | Kyverno 설치가 안 끝남 | 2단계 다시 |
| `READY`가 비었거나 `false` | 정책을 읽는 중 | 5초 뒤 다시 `get` |

</details>

인터넷 예제 대부분은 예전 형식(`kind: ClusterPolicy`)입니다. 1.19에서도 동작하지만 **폐기 예정 경고**가 나옵니다. 이 과정은 새 형식(`ValidatingPolicy`)을 씁니다(부록 A5).

## 4단계. todo에서 시험하기

```bash
kubectl -n todo run test --image=nginx:latest
kubectl -n todo run test --image=nginx
kubectl -n todo run test --image=busybox:1.37 -- sleep infinity
kubectl -n todo set image deployment/web nginx=todo-web:latest
kubectl -n todo get deployment web -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
```

**이 명령은**: 위에서부터 ① 태그가 latest인 파드 ② 태그가 없는 파드 ③ 태그가 있는 파드 ④ **Deployment** web의 이미지를 `todo-web:latest`로 바꾸기(`set image deployment/이름 컨테이너=이미지`) ⑤ web의 지금 이미지 확인.

**이렇게 나오면 성공**

```
Error from server: admission webhook "vpol.validate.kyverno.svc-fail" denied the request: Policy disallow-latest-tag failed: 이미지 태그를 명시하고 latest는 쓰지 마세요
Error from server: admission webhook "vpol.validate.kyverno.svc-fail" denied the request: Policy disallow-latest-tag failed: 이미지 태그를 명시하고 latest는 쓰지 마세요
pod/test created
error: failed to patch image update to pod template: admission webhook "vpol.validate.kyverno.svc-fail" denied the request: Policy disallow-latest-tag failed: 이미지 태그를 명시하고 latest는 쓰지 마세요
todo-web:v1
```

| 명령 | 결과 |
|---|---|
| `nginx:latest` | `denied the request` |
| `nginx` (태그 없음 = latest) | `denied` |
| `busybox:1.37` | `created` |
| Deployment web → `todo-web:latest` | `denied`, web은 `todo-web:v1` 그대로 (1단계 정책 없을 때는 `image updated` → `ImagePullBackOff`) |

**왜 그런가**
- 태그를 안 쓰면 쿠버네티스는 `latest`로 받습니다. latest는 **올릴 때마다 내용이 바뀌는 이름**이라 어제 받은 것과 지금 받는 것이 같은 이미지인지 이름만 보고는 알 수 없습니다. 그래서 막습니다(실습 10의 서명과도 이어짐)
| 같은 명령 `set image deployment/web nginx=todo-web:latest` | 정책 없음 (1단계) | 정책 있음 (4단계) |
|---|---|---|
| 명령 결과 | `deployment.apps/web image updated` | `denied the request: … latest는 쓰지 마세요` |
| web 파드 | 새 파드 `ImagePullBackOff`, 되돌릴 때까지 남음 | 바뀌지 않음, `todo-web:v1` 그대로 |
| 알아차리는 때 | 파드가 깨진 뒤 | 명령을 친 그 자리 |

- 정책은 **파드** 규칙인데 Deployment 변경도 거부됩니다. Kyverno가 파드를 만드는 리소스(Deployment, StatefulSet, Job…)에도 **같은 규칙을 자동으로 적용**하기 때문입니다. 덕분에 web은 고장 난 이미지로 바뀌지 않고 그대로 돕니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `nginx:latest`가 `pod/test created` | 정책이 아직 준비 전 | `kubectl -n todo delete pod test` → `kubectl get validatingpolicy`의 READY가 `true`인 뒤 다시 |
| `Error from server (AlreadyExists): pods "test" already exists` | 앞에서 만든 `test`가 남음 | `kubectl -n todo delete pod test` 후 다시 |
| `Warning: would violate PodSecurity …`이 섞여 나옴 | 실습 8의 warn 라벨을 안 뗌 | `kubectl label namespace todo pod-security.kubernetes.io/warn-` |

</details>

## 끝났는지 확인

- ☐ 정책 없을 때 web의 latest 변경이 `image updated` → 새 파드 `ImagePullBackOff`, `todo-web:v1`로 되돌림
- ☐ `nginx:latest`와 `nginx`는 `denied the request`
- ☐ `busybox:1.37`은 `created`
- ☐ Deployment web의 latest 변경도 `denied`, 이미지는 `todo-web:v1` 그대로

## 정리

확인 문제를 푼 뒤 시험 파드와 정책을 지웁니다. **정책은 클러스터 전체에 걸리므로 꼭 지웁니다.** Kyverno 자체는 미션 2 도전 1에서 쓰니 남깁니다.

```bash
kubectl -n todo delete pod test init-latest --ignore-not-found
kubectl delete validatingpolicy disallow-latest-tag
```

여기까지 마쳤으면 [미션 2](../미션/02-shop-네임스페이스-격리.md#미션-2-shop-네임스페이스-격리)를 합니다.

## 확인 문제

1. `disallow-latest.yaml`의 `validationActions: [Deny]`를 `[Audit]`로 바꿔 다시 `apply` 하고, `kubectl -n todo run l2 --image=nginx:latest`를 실행해 보세요. 어떻게 되나요? 확인했으면 `kubectl -n todo delete pod l2`, `[Deny]`로 되돌려 `apply` 합니다.
2. 이 정책은 `containers`만 검사합니다. `initContainers`(앱보다 먼저 한 번 실행되는 컨테이너)에 `busybox:latest`를 쓴 파드(아래)는 어떻게 되나요? 정책을 쓸 때 무엇을 조심해야 할까요?
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: init-latest
     namespace: todo
   spec:
     initContainers:
     - name: init
       image: busybox:latest
       command: ["true"]
     containers:
     - name: c
       image: busybox:1.37
       command: ["sleep", "infinity"]
   ```
3. 이 정책은 이미지 이름에 `:`가 있으면 "태그를 적었다"고 봅니다. `kubectl -n todo run portonly --image=localhost:5001/todo-api --dry-run=server`는 어떻게 되나요? 이 이미지 이름에 태그가 있나요? 왜 이런 결과가 나올까요? (`--dry-run=server`는 API 서버까지 보내 검사만 받고 실제로 만들지는 않는 옵션입니다)
