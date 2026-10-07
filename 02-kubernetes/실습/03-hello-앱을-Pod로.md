[← 실습 2](./02-kubectl로-둘러보기.md) · [목차](../Kubernetes-실습.md) · [실습 4 →](./04-Deployment-지워도-다시-생긴다.md)

# 실습 3. hello 앱을 Pod로

**무엇을 하나요**: Docker 과목에서 만든 `hello:v1` 이미지를 클러스터에서 **Pod**로 실행합니다. 먼저 이미지를 클러스터에 넣지 않고 실행해 왜 안 되는지 보고, `kind load`로 넣은 뒤 다시 실행합니다. Pod를 지우면 다시 생기지 않는다는 것도 확인하고, 마지막으로 컨테이너가 두 개인 파드를 만들어 봅니다. (교안 03장)

**필요한 것**: 실습 1의 클러스터, Docker 과목의 이미지 `hello:v1`·`hello:v2`.

> **바로 가기** · [1. 이미지 확인](#1단계-이미지-확인) · [2. Pod YAML 쓰기](#2단계-pod-yaml-쓰기) · [3. 그대로 실행해 보기 → 실패](#3단계-그대로-실행해-보기--실패) · [4. 이미지를 클러스터에 넣기 — kind load](#4단계-이미지를-클러스터에-넣기--kind-load) · [5. 다시 실행](#5단계-다시-실행) · [6. 로그 보기, 안에서 명령 실행](#6단계-로그-보기-안에서-명령-실행) · [7. Pod를 지우면](#7단계-pod를-지우면) · [8. 컨테이너가 두 개인 파드](#8단계-컨테이너가-두-개인-파드) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 이미지 확인

```bash
docker image ls hello
```

**이렇게 나오면 성공**: `hello:v1`, `hello:v2` 두 줄. 없으면 [시작하기 전에 9](./00-시작하기-전에.md#9-docker-과목에서-만든-것이-없을-때)로 다시 만듭니다.

```
IMAGE      ID             DISK USAGE   CONTENT SIZE   EXTRA
hello:v1   c07075fb840c        249MB         62.7MB
hello:v2   93d74b60dd63        249MB         62.7MB
```

## 2단계. Pod YAML 쓰기

이 과목에서 직접 쓰는 hello용 YAML은 모두 `lab/k8s/hello` 폴더에 둡니다.

```bash
mkdir -p ~/ktcloud-cloud-native-lab/lab/k8s/hello
cd ~/ktcloud-cloud-native-lab/lab/k8s/hello
nano pod.yaml
```

아래를 붙여 넣고 **Ctrl+O → Enter → Ctrl+X**. 들여쓰기는 스페이스 2칸입니다.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hello
  labels:
    app: hello
spec:
  containers:
  - name: hello
    image: hello:v1
    ports:
    - containerPort: 3000
```

**이 파일은** — `docker run -d --name hello hello:v1`을 파일로 적은 것입니다.

| 줄 | 뜻 | Docker에서 |
|---|---|---|
| `apiVersion: v1` | 이 종류를 정의한 규칙의 버전. 종류마다 정해져 있음(Pod는 `v1`) | — |
| `kind: Pod` | 만들 것의 종류 | — |
| `metadata:` 아래 `name: hello` | 이름 | `--name hello` |
| `labels:` 아래 `app: hello` | 이름표. 나중에 "이 이름표를 단 파드"를 고를 때 씀(04·05장) | — |
| `spec:` | 원하는 모양(명세) | — |
| `containers:` 아래 `- name: hello` | 파드 안의 컨테이너 목록, 첫 번째 컨테이너의 이름 | — |
| `image: hello:v1` | 쓸 이미지 | `hello:v1` |
| `ports:` 아래 `containerPort: 3000` | 앱이 3000번을 쓴다는 **표시** (Dockerfile의 `EXPOSE`와 같음) | `EXPOSE 3000` |

## 3단계. 그대로 실행해 보기 → 실패

```bash
kubectl apply -f pod.yaml
kubectl get pods
```

**이 명령은**: `kubectl apply -f 파일` = 파일에 적힌 대로 만들어 달라고 클러스터에 보냄(apply = 적용). 이미 있으면 바뀐 것만 고침.

몇 초 뒤 `kubectl get pods`를 다시 봅니다. **이 단계는 실패하는 것이 맞습니다.**

```
NAME    READY   STATUS         RESTARTS   AGE
hello   0/1     ErrImagePull   0          16s
```

이유를 봅니다. 파드 이름 뒤 `| tail -8` = 마지막 8줄만(Events 부분).

```bash
kubectl describe pod hello | tail -8
```

```
Events:
  Type     Reason     Age   From               Message
  ----     ------     ----  ----               -------
  Normal   Scheduled  16s   default-scheduler  Successfully assigned default/hello to lab-control-plane
  Normal   Pulling    15s   kubelet            spec.containers{hello}: Pulling image "hello:v1"
  Warning  Failed     13s   kubelet            spec.containers{hello}: Failed to pull image "hello:v1": … docker.io/library/hello:v1: not found
  Warning  Failed     13s   kubelet            spec.containers{hello}: Error: ErrImagePull
  Normal   BackOff    13s   kubelet            spec.containers{hello}: Back-off pulling image "hello:v1"
  Warning  Failed     13s   kubelet            spec.containers{hello}: Error: ImagePullBackOff
```

**왜 실패했나**: `hello:v1`은 **내 VM의 Docker** 안에만 있습니다. 클러스터의 노드(`lab-control-plane` 컨테이너)는 VM의 Docker 이미지를 모르므로, Docker Hub(`docker.io/library/hello:v1`)에서 받으려다 `not found`가 났습니다.

- `ErrImagePull` = 이미지를 받다가 실패. 조금 뒤 `ImagePullBackOff`(잠시 쉬었다가 다시 시도하는 중)로 바뀌며 계속 다시 해 봅니다
- Events는 위에서 아래로 시간 순서입니다. `Scheduled`(노드 배정) → `Pulling`(이미지 받기) → `Failed`(실패)

실패한 파드를 지웁니다.

```bash
kubectl delete pod hello
```

## 4단계. 이미지를 클러스터에 넣기 — kind load

```bash
kind load docker-image hello:v1 hello:v2 --name lab
```

**이 명령은**: VM의 Docker에 있는 이미지 `hello:v1`, `hello:v2`를 kind 클러스터 `lab`의 노드 안으로 복사. 실습 5에서 쓸 `v2`도 같이 넣습니다.

**이렇게 나오면 성공**

```
Image: "hello:v1" with ID "sha256:c07075fb…" not yet present on node "lab-control-plane", loading...
Image: "hello:v2" with ID "sha256:93d74b60…" not yet present on node "lab-control-plane", loading...
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `ERROR: image: "hello:v1" not present locally` | VM의 Docker에 그 이미지가 없음 | `docker image ls hello`로 확인, 없으면 [시작하기 전에 9](./00-시작하기-전에.md#9-docker-과목에서-만든-것이-없을-때) |
| `ERROR: no nodes found for cluster "kind"` | `--name lab`을 빠뜨림(이름을 안 주면 `kind`라는 클러스터를 찾음) | `--name lab`을 붙여 다시 |

</details>

- 회사에서는 이미지를 레지스트리(Docker Hub 등)에 올리고 노드가 받아 갑니다. Docker 실습 9에서 Docker Hub에 올린 이미지라면 YAML의 `image:`를 `<아이디>/hello:v2`로 쓰면 `kind load` 없이 받아 옵니다. 이 과목에서는 계정 없이 하도록 `kind load`를 씁니다

## 5단계. 다시 실행

```bash
kubectl apply -f pod.yaml
kubectl get pods -o wide
```

**이렇게 나오면 성공** — `1/1 Running`

```
NAME    READY   STATUS    RESTARTS   AGE   IP           NODE                NOMINATED NODE   READINESS GATES
hello   1/1     Running   0          5s    10.244.0.7   lab-control-plane   <none>           <none>
```

- `IP` = 파드가 받은 주소(클러스터 안에서만 쓰는 주소). 사람마다 다름
- `NODE` = 이 파드가 도는 노드

무슨 일이 있었는지 Events로 봅니다.

```bash
kubectl describe pod hello | tail -6
```

```
  Normal  Scheduled  5s    default-scheduler  Successfully assigned default/hello to lab-control-plane
  Normal  Pulled     5s    kubelet            spec.containers{hello}: Container image "hello:v1" already present on machine and can be accessed by the pod
  Normal  Created    5s    kubelet            spec.containers{hello}: Container created
  Normal  Started    5s    kubelet            spec.containers{hello}: Container started
```

`already present on machine` = 노드에 이미 있는 이미지(4단계에서 넣은 것)를 썼다는 뜻입니다.

## 6단계. 로그 보기, 안에서 명령 실행

```bash
kubectl logs hello
kubectl exec hello -- wget -qO- localhost:3000
kubectl exec hello -- node -v
```

**이 명령은**
- `kubectl logs hello` = 파드의 로그(`docker logs`와 같음)
- `kubectl exec hello -- 명령` = 파드 안에서 명령 실행(`docker exec`와 같음). `--` 뒤가 파드 안에서 실행할 명령
- `wget -qO- localhost:3000` = 파드 **안에서** 앱(3000번)에 요청. `wget`은 이미지 안에 있는 내려받기 도구(`curl`과 비슷), `-qO-` = 받은 내용을 화면에 바로 출력

**이렇게 나오면 성공**

```
hello app listening on port 3000
hello, docker
v22.23.3
```

- 아직 VM에서 `curl localhost:3000`으로는 접속되지 않습니다. 밖에서 들어오는 길은 05장(실습 6)에서 엽니다

## 7단계. Pod를 지우면

```bash
kubectl delete pod hello
kubectl get pods
```

**이렇게 나오면 성공**

```
pod "hello" deleted from default namespace
No resources found in default namespace.
```

- `kubectl delete pod hello`는 **30초쯤** 걸립니다. 앱이 "끝내라"는 신호에 반응하지 않아 쿠버네티스가 30초 기다린 뒤 강제로 끄기 때문입니다([시작하기 전에 5](./00-시작하기-전에.md#5-멈춘-것처럼-보일-때))
- Pod만 만들면 지웠을 때 **아무도 다시 만들어 주지 않습니다**. `docker rm` 한 컨테이너와 같습니다. 다시 만들어 주는 것은 다음 실습의 Deployment입니다

<details><summary><b>이렇게 나오면? (이 실습 전체)</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `ErrImagePull` / `ImagePullBackOff` | 이미지를 노드에 안 넣음(`kind load` 전), 또는 YAML의 `image:` 오타(`hello:v3`처럼 없는 태그) | `kubectl describe pod hello`의 Events에서 이미지 이름 확인 → 4단계 또는 YAML 고치기 |
| `pod/hello unchanged` | 파일이 그대로라 바꿀 것이 없음 | 정상 |
| `Error from server (NotFound): pods "helo" not found` | 파드 이름 오타 | `kubectl get pods`로 이름 확인 |
| `two`가 `Init:0/1`에서 오래 멈춤, Events에 `busybox` 받기 실패 | 인터넷에서 busybox를 받는 중이거나 실패 | 1분쯤 기다린 뒤 `kubectl describe pod two`의 Events 확인 |
| `Defaulted container "hello" …` 줄과 함께 hello 로그만 나옴 | 컨테이너가 여러 개인 파드에서 `-c`를 빼면 첫 컨테이너를 고름 | `kubectl logs two -c checker`처럼 `-c` |
| `yaml: line …` 오류 | 들여쓰기·탭 | [시작하기 전에 7](./00-시작하기-전에.md#7-yaml-파일-쓰기--들여쓰기와-nano) |

</details>

## 8단계. 컨테이너가 두 개인 파드

쿠버네티스가 컨테이너를 바로 다루지 않고 Pod로 감싸는 이유가 여기 있습니다. 앱과 앱을 돕는 컨테이너(로그 수집기, 프록시 등)는 **같은 노드에서, 같은 IP로, 같은 폴더를 보며** 함께 살아야 합니다. Docker로 컨테이너를 따로 띄우면 IP도 다르고 여러 서버에 흩어질 수 있지만, Pod로 묶으면 쿠버네티스가 이 묶음을 한 단위로 함께 두고, 함께 지우고, 함께 다시 시작합니다. 파드 하나에 컨테이너를 여러 개 넣을 수 있습니다. 앱 옆에서 돕는 컨테이너를 **사이드카**, 앱보다 먼저 한 번 실행하고 끝나는 컨테이너를 **init 컨테이너**라고 부릅니다. 둘 다 넣은 파드 `two`를 만들어 봅니다.

```bash
nano two.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: two
spec:
  initContainers:
  - name: setup
    image: busybox:1.37
    command: ["sh", "-c", "echo setup이 만든 파일 > /work/ready.txt"]
    volumeMounts:
    - name: work
      mountPath: /work
  containers:
  - name: hello
    image: hello:v1
  - name: checker
    image: busybox:1.37
    command: ["sh", "-c", "cat /work/ready.txt; while true; do sleep 5; wget -qO- localhost:3000; done"]
    volumeMounts:
    - name: work
      mountPath: /work
  volumes:
  - name: work
    emptyDir: {}
```

**이 파일은**

| 줄 | 뜻 |
|---|---|
| `initContainers:` 아래 `setup` | **init 컨테이너**. 앱 컨테이너보다 먼저 한 번 실행하고 끝남. 여기서는 `/work/ready.txt` 파일을 만듦 |
| `containers:` 아래 `hello` | 우리 앱(실습 3의 것과 같음) |
| `containers:` 아래 `checker` | **사이드카**. 파일을 한 번 읽고, 5초마다 `localhost:3000`(옆의 hello 앱)을 부름 |
| `volumes:` `emptyDir: {}` | 파드 안의 **빈 폴더** `work`. `volumeMounts`를 적은 컨테이너(setup·checker)가 `/work`로 같이 씀 |
| `busybox:1.37` | `sh`·`wget` 같은 기본 도구만 든 작은 이미지. 처음 쓰면 인터넷에서 받음(몇 초) |

```bash
kubectl apply -f two.yaml
kubectl get pod two
```

몇 초 뒤 한 번 더 `kubectl get pod two`를 칩니다.

**이렇게 나오면 성공**

```
NAME   READY   STATUS     RESTARTS   AGE
two    0/2     Init:0/1   0          2s
```
```
NAME   READY   STATUS    RESTARTS   AGE
two    2/2     Running   0          16s
```

- `Init:0/1` = init 컨테이너 1개 중 0개 끝남(실행 중). 끝나야 앱 컨테이너가 시작됩니다
- `READY 2/2` = 컨테이너 **2개** 중 2개 준비됨. 지금까지는 컨테이너가 하나라 `1/1`이었습니다. init 컨테이너는 끝나고 없어지므로 세지 않습니다

이제 사이드카의 로그를 봅니다. 컨테이너가 여러 개면 `-c 컨테이너 이름`으로 고릅니다.

```bash
kubectl logs two -c checker
```

**이렇게 나오면 성공**: 첫 줄은 setup이 만든 파일 내용, 그 뒤로 5초마다 `hello, docker`가 한 줄씩 늘어납니다.

```
setup이 만든 파일
hello, docker
hello, docker
```

- checker는 `localhost:3000`으로 hello 앱을 불렀습니다. **같은 파드의 컨테이너는 IP가 같아서** 서로 `localhost`로 부릅니다
- setup이 만든 파일을 checker가 읽었습니다. `emptyDir` 폴더를 같이 쓰기 때문입니다. 이 폴더는 **파드를 지우면 함께 사라집니다**(남길 데이터는 07장 PVC)
- `kubectl logs two`처럼 `-c`를 빼면 `Defaulted container "hello" out of: hello, checker, setup (init)` 줄과 함께 첫 컨테이너(hello)의 로그가 나옵니다

다 봤으면 지웁니다. 이번에도 30초쯤 걸립니다.

```bash
kubectl delete pod two
```

- 서비스 메시 과목의 Istio는 앱 파드마다 프록시 사이드카를 붙여 `READY 2/2`가 됩니다. 이 단계와 같은 모양입니다

## 끝났는지 확인
- ☐ 3단계에서 `ErrImagePull`을 보고, 이유(노드에 이미지가 없음)를 Events에서 찾았다
- ☐ `kind load` 뒤 `kubectl get pods`에 `hello   1/1   Running`
- ☐ `kubectl exec hello -- wget -qO- localhost:3000`에 `hello, docker`
- ☐ 지운 뒤 `kubectl get pods`가 `No resources found`
- ☐ 파드 `two`가 `2/2 Running`이고 `kubectl logs two -c checker`에 `hello, docker`

## 정리
- 파드는 7·8단계에서 지웠습니다. `pod.yaml`·`two.yaml`은 두어도 됩니다

## 확인 문제
1. `pod.yaml`을 복사해 `pod2.yaml`을 만들고(`cp pod.yaml pod2.yaml`), 이름을 `hello2`, 이미지를 `hello:v2`로 바꿔 실행하세요. 파드 안에서 `wget -qO- localhost:3000`을 하면 무엇이 나오나요? 확인한 뒤 `kubectl delete -f pod2.yaml`로 지웁니다.
2. `kubectl apply -f pod.yaml`로 다시 만든 뒤 `kubectl get pod hello -o yaml | grep imagePullPolicy`를 보세요. 값이 무엇이고, 이 값 때문에 `kind load`로 넣은 이미지가 쓰이는 이유는 무엇일까요? 확인한 뒤 파드는 지웁니다.
