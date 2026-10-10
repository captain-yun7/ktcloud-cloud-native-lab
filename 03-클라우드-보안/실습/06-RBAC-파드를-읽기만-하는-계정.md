[← 실습 5](./05-Secret을-파일로-넣고-쓰지-않는-토큰-끄기.md) · [목차](../클라우드-보안-실습.md) · [실습 7 →](./07-NetworkPolicy-db는-api만.md)

# 실습 6. RBAC — 파드를 읽기만 하는 계정

**무엇을 하나요**: 먼저 계정에 권한을 **넓게** 주면(기본 ClusterRole `edit`을 클러스터 전체에) 무엇까지 되는지 봅니다. 그다음 todo 네임스페이스의 **파드를 읽기만** 하는 서비스 계정 `reader`를 만듭니다. 그 계정이 무엇을 할 수 있는지 `kubectl auth can-i`로 묻고, 그 계정의 토큰으로 직접 접속해 허용과 거부를 눈으로 확인합니다. 실습 5에서 본 "Secret을 읽을 수 있으면 비밀번호가 보인다"를 막는 방법입니다. (교안 07장)

**필요한 것**: todo(실습 1). 실습 1의 4단계에서 쓴 `kubectl auth can-i … --as=…`.

> **바로 가기** · [1. 권한을 넓게 주면](#1단계-권한을-넓게-주면) · [2. 필요한 권한만 만들기](#2단계-필요한-권한만-만들기) · [3. 권한을 물어보기](#3단계-권한을-물어보기) · [4. 토큰으로 직접 접속하기](#4단계-토큰으로-직접-접속하기) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 권한을 넓게 주면

계정 `reader`를 만들고, "편하게" 쿠버네티스에 기본으로 있는 ClusterRole `edit`(대부분의 리소스를 만들고·고치고·지우기)을 **클러스터 전체**에 묶어 봅니다.

```bash
kubectl -n todo create serviceaccount reader
kubectl create clusterrolebinding reader-wide --clusterrole=edit --serviceaccount=todo:reader
A=system:serviceaccount:todo:reader
kubectl auth can-i get secrets    -n todo        --as=$A
kubectl auth can-i delete pods    -n todo        --as=$A
kubectl auth can-i list pods      -n kube-system --as=$A
kubectl -n todo get secret todo-secret --as=$A -o jsonpath='{.data.DB_PASSWORD}' | base64 -d; echo
```

**이 명령은**

| 명령 | 하는 일 |
|---|---|
| `create serviceaccount reader` | 파드(프로그램)가 쓰는 계정 `reader`를 만듦 |
| `create clusterrolebinding reader-wide --clusterrole=edit …` | 기본 권한 목록 `edit`을 reader에게 **모든 네임스페이스에서** 줌 |
| `A=…` | 긴 계정 이름을 변수 `A`에 담음(`$A`로 꺼내 씀) |
| `auth can-i 동사 리소스 -n 네임스페이스 --as=$A` | "그 계정이 그 일을 할 수 있나?"를 물음(실습 1 4단계) |
| `get secret … --as=$A … \| base64 -d` | reader인 척 todo의 Secret을 꺼내 비밀번호를 풂(실습 5 1단계) |

**이렇게 나오면 성공** — 다 되는 것이 이 단계에서 보려는 것입니다.

```
serviceaccount/reader created
clusterrolebinding.rbac.authorization.k8s.io/reader-wide created
yes
yes
yes
todo-pass
```

- 파드를 보기만 하면 되는 계정인데 **DB 비밀번호가 보이고**, 파드를 지울 수 있고, 다른 네임스페이스(`kube-system`)까지 들어갑니다. 이 계정의 토큰이 새면 이 모든 일을 남이 할 수 있습니다

넓은 권한을 지웁니다(계정 `reader`는 남김).

```bash
kubectl delete clusterrolebinding reader-wide
```

```
clusterrolebinding.rbac.authorization.k8s.io "reader-wide" deleted
```

## 2단계. 필요한 권한만 만들기

이번에는 "todo의 파드 보기"만 적은 권한을 만들어 reader에 연결합니다.

```bash
kubectl -n todo create role pod-reader --verb=get,list,watch --resource=pods
kubectl -n todo create rolebinding reader-bind --role=pod-reader --serviceaccount=todo:reader
kubectl -n todo get role pod-reader -o yaml | tail -8
```

**이 명령은**: 세 줄이 각각 이런 일을 합니다.

| 명령 | 하는 일 |
|---|---|
| `create role pod-reader --verb=get,list,watch --resource=pods` | "파드를 보기(get·list·watch)만 할 수 있다"는 **권한 목록**(Role)을 만듦 |
| `create rolebinding reader-bind --role=pod-reader --serviceaccount=todo:reader` | 그 권한 목록을 `reader` 계정에 **연결**(RoleBinding). `todo:reader` = todo 네임스페이스의 reader |
| `get role … -o yaml \| tail -8` | 만들어진 규칙의 마지막 8줄을 봄 |

**이렇게 나오면 성공**

```
role.rbac.authorization.k8s.io/pod-reader created
rolebinding.rbac.authorization.k8s.io/reader-bind created
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
  - list
  - watch
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `… already exists` | 이미 만듦 | 그대로 진행 |
| `error: serviceaccount must be <namespace>:<name>` | `--serviceaccount=reader`처럼 네임스페이스를 빠뜨림 | `--serviceaccount=todo:reader` |

</details>

## 3단계. 권한을 물어보기

```bash
A=system:serviceaccount:todo:reader
kubectl auth can-i list pods   -n todo        --as=$A
kubectl auth can-i delete pods -n todo        --as=$A
kubectl auth can-i list pods   -n kube-system --as=$A
kubectl auth can-i get secrets -n todo        --as=$A
```

**이 명령은**: `A=…` = 1단계와 같은 변수(새 터미널이면 다시 담음). `can-i 동사 리소스 -n 네임스페이스 --as=계정` = "그 계정이 그 일을 할 수 있나?"를 클러스터에 물음. 내 관리자 권한으로 **그 계정인 척** 묻는 것이라 토큰이 필요 없습니다.

**이렇게 나오면 성공**: 위에서부터 `yes` · `no` · `no` · `no`

```
yes
no
no
no
```

| 시험 | 넓게 준 경우 (1단계, `edit` 클러스터 전체) | 필요한 것만 (`pod-reader`) |
|---|---|---|
| todo 파드 보기 (`list pods`) | yes | yes |
| todo Secret 보기 (`get secrets`) | yes — 비밀번호 `todo-pass`가 보임 | no |
| todo 파드 지우기 (`delete pods`) | yes | no |
| 다른 네임스페이스 (`list pods -n kube-system`) | yes | no |

**왜 그런가**: Role에 적은 것은 "todo의 파드 보기"뿐입니다. 지우기(`delete`), 다른 네임스페이스(`kube-system`), 다른 리소스(`secrets`)는 적지 않았으니 모두 `no`입니다. RBAC은 **적은 것만 허용**합니다. 그리고 Role은 **자기 네임스페이스 안에서만** 효력이 있습니다.

## 4단계. 토큰으로 직접 접속하기

```bash
TOKEN=$(kubectl -n todo create token reader --duration=10m)
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
K="kubectl --kubeconfig=/dev/null --server=$SERVER --token=$TOKEN --insecure-skip-tls-verify"
$K get pods -n todo
$K get secret todo-secret -n todo
$K get pods -n kube-system
```

**이 명령은**
- `create token reader --duration=10m` = `reader` 계정의 **10분짜리 토큰**을 받아 변수 `TOKEN`에 담음
- `SERVER=…` = 내 설정 파일에서 API 서버 주소만 꺼냄
- `K="kubectl --kubeconfig=/dev/null …"` = 긴 앞부분을 변수에 담음. `--kubeconfig=/dev/null` = 내 **관리자 설정 파일을 쓰지 않고**, `--token`으로 받은 토큰만으로 접속. `--insecure-skip-tls-verify` = 연습용이라 서버 인증서 확인을 건너뜀
- `$K get …` = reader 계정으로 접속해 조회

**이렇게 나오면 성공**: todo의 파드는 보이고, Secret과 다른 네임스페이스는 거부됩니다.

```
NAME                   READY   STATUS    RESTARTS   AGE
api-7bb896f478-tz44k   1/1     Running   0          10m
db-86878656ff-nkmlv    1/1     Running   0          40m
web-5bdd6887b7-llw4z   1/1     Running   0          40m
Error from server (Forbidden): secrets "todo-secret" is forbidden: User "system:serviceaccount:todo:reader" cannot get resource "secrets" in API group "" in the namespace "todo"
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:todo:reader" cannot list resource "pods" in API group "" in the namespace "kube-system"
```

- `Forbidden`(금지) 메시지에 **누가**(`system:serviceaccount:todo:reader`) **무엇을**(`get` `secrets`) **어디서**(`todo`) 하려다 막혔는지 그대로 나옵니다. 권한 문제를 찾을 때 이 줄을 읽습니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| Secret·kube-system이 그대로 조회됨 | `--kubeconfig=/dev/null`을 빠뜨려 내 관리자 인증서가 같이 전송됨 → 관리자로 접속 | `K=…` 줄을 그대로 다시 |
| `error: You must be logged in to the server (Unauthorized)` | 토큰 10분이 지남 | `TOKEN=…` 줄부터 다시 |
| 50초쯤 멈춘 뒤 `error: Get "http://localhost:8080/api?timeout=32s": … connection reset by peer` | `SERVER`·`TOKEN` 변수가 비었음(새 터미널) | Ctrl+C, `TOKEN=…` 줄부터 다시 |

</details>

권한을 정리하면 이렇습니다.

| 리소스 | 범위 | 뜻 |
|---|---|---|
| Role | 네임스페이스 하나 | 무엇을(resources) 어떻게(verbs) 할 수 있나. 예) `pod-reader` = todo의 `pods`를 `get`·`list`·`watch` |
| RoleBinding | 네임스페이스 하나 | 누구에게(subjects) Role을 주나. 예) `reader-bind` = `reader`에게 `pod-reader` |
| ClusterRole / ClusterRoleBinding | 클러스터 전체 | 노드처럼 네임스페이스가 없는 것, 또는 전체 권한. 예) 1단계의 `edit` + `reader-wide` → `kube-system`까지 `yes` |

## 끝났는지 확인

- ☐ 넓게 준 경우(1단계) `can-i` 세 줄이 모두 `yes`, 비밀번호가 보였다
- ☐ `reader-wide`를 지운 뒤 `can-i` 네 줄이 `yes` · `no` · `no` · `no`
- ☐ 토큰 접속에서 todo 파드 목록이 보임
- ☐ 토큰 접속에서 Secret과 kube-system은 `Forbidden`

## 정리

`reader` 계정은 확인 문제에서 쓰고, 끝나면 지웁니다.

```bash
kubectl -n todo delete rolebinding reader-bind reader-view
kubectl -n todo delete role pod-reader
kubectl -n todo delete serviceaccount reader
```

(`reader-view`는 확인 문제 1에서 만듭니다. 안 만들었으면 `not found`가 나와도 괜찮습니다.)

## 확인 문제

1. 쿠버네티스에 기본으로 있는 ClusterRole `view`(읽기 전용)를 **todo 네임스페이스에서만** reader에게 주세요. `kubectl -n todo create rolebinding reader-view --clusterrole=view --serviceaccount=todo:reader` 뒤에 `can-i`로 todo의 services·deployments 조회와 kube-system의 pods 조회를 물어보세요. ClusterRole을 썼는데 kube-system은 왜 여전히 안 되나요?
2. `view`를 준 뒤에도 todo의 **Secret 조회**(`get secrets`)와 파드 삭제는 되나요?
