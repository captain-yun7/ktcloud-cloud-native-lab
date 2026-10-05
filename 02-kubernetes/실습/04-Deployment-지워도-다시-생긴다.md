[← 실습 3](./03-hello-앱을-Pod로.md) · [목차](../Kubernetes-실습.md) · [실습 5 →](./05-업데이트와-롤백.md)

# 실습 4. Deployment — 지워도 다시 생긴다

**무엇을 하나요**: "hello 파드 3개를 유지해 줘"라고 **Deployment**에 적습니다. 파드를 지워도 다시 생기고, 숫자만 바꾸면 늘었다 줄었다 하는 것을 봅니다. 앞으로는 파드를 직접 만들지 않고 Deployment로 만듭니다. (교안 04장)

**필요한 것**: 실습 3에서 `kind load`로 넣은 `hello:v1`.

> **바로 가기** · [1. Deployment YAML 쓰기](#1단계-deployment-yaml-쓰기) · [2. 적용하고 보기](#2단계-적용하고-보기) · [3. 파드 하나를 지우면](#3단계-파드-하나를-지우면) · [4. 파일의 숫자를 바꾸면](#4단계-파일의-숫자를-바꾸면) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. Deployment YAML 쓰기

```bash
cd ~/ktcloud-cloud-native-lab/lab/k8s/hello
nano deploy.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hello
  template:
    metadata:
      labels:
        app: hello
    spec:
      containers:
      - name: hello
        image: hello:v1
        ports:
        - containerPort: 3000
```

**이 파일은** — 아래 절반(`template:` 아래)이 실습 3의 Pod와 거의 같습니다. Deployment는 "이 모양의 파드를 몇 개"라고 적은 것입니다.

| 줄 | 뜻 |
|---|---|
| `apiVersion: apps/v1` · `kind: Deployment` | 종류는 Deployment(규칙 버전은 `apps/v1`) |
| `metadata.name: hello` | Deployment 이름. 파드 이름이 이것으로 시작함 |
| `replicas: 3` | 파드를 **3개** 유지 |
| `selector.matchLabels: app: hello` | "이름표 `app: hello`를 단 파드가 내 것"이라는 조건 |
| `template:` | 만들 파드의 모양(틀). 실습 3의 `pod.yaml`에서 `apiVersion`·`kind`·`name`을 뺀 것 |
| `template.metadata.labels: app: hello` | 만든 파드에 붙일 이름표. **위 `selector`와 같아야** 함 |
| `template.spec.containers` | 컨테이너(이미지 `hello:v1`, 포트 3000) — 실습 3과 같음 |

## 2단계. 적용하고 보기

```bash
kubectl apply -f deploy.yaml
kubectl get deployment
kubectl get replicaset
kubectl get pods
```

**이 명령은**: Deployment를 만들면 Deployment → **ReplicaSet**(개수를 세어 맞추는 것) → **파드 3개**가 차례로 생깁니다. 세 가지를 각각 봅니다.

**이렇게 나오면 성공** — 몇 초 뒤 `3/3`

```
NAME    READY   UP-TO-DATE   AVAILABLE   AGE
hello   3/3     3            3           6s
```
```
NAME              DESIRED   CURRENT   READY   AGE
hello-d6646dd5c   3         3         3       6s
```
```
NAME                    READY   STATUS    RESTARTS   AGE
hello-d6646dd5c-qkcbf   1/1     Running   0          6s
hello-d6646dd5c-tj96n   1/1     Running   0          6s
hello-d6646dd5c-zqrhr   1/1     Running   0          6s
```

- 파드 이름 = `Deployment 이름` - `ReplicaSet 표시` - `무작위 5글자`. 이름만 봐도 어느 Deployment의 파드인지 압니다
- 바로 보면 `0/3`일 수 있습니다. 몇 초 뒤 다시 칩니다

이름표도 봅니다.

```bash
kubectl get pods --show-labels
```

```
NAME                    READY   STATUS    RESTARTS   AGE   LABELS
hello-d6646dd5c-qkcbf   1/1     Running   0          6s    app=hello,pod-template-hash=d6646dd5c
…
```

`app=hello` = YAML에 적은 이름표. Deployment는 이 이름표로 "내 파드"를 셉니다.

## 3단계. 파드 하나를 지우면

파드 이름 하나를 복사해 지웁니다(이름은 내 화면의 것으로).

```bash
kubectl delete pod <파드이름>
kubectl get pods
```

**이렇게 나오면 성공** — 다시 3개. 지운 파드 대신 **끝 5글자가 새로운** 파드가 있음

```
NAME                    READY   STATUS    RESTARTS   AGE
hello-d6646dd5c-4psw4   1/1     Running   0          31s
hello-d6646dd5c-tj96n   1/1     Running   0          37s
hello-d6646dd5c-zqrhr   1/1     Running   0          37s
```

- `delete`가 30초쯤 걸리는 동안 이미 새 파드가 만들어집니다. 그래서 `AGE`가 짧은(새) 파드가 하나 보입니다
- 3개라고 적어 두었으니(replicas: 3), 하나가 사라지자 쿠버네티스가 하나를 새로 만들었습니다. Docker에서는 컨테이너가 죽으면 내가 다시 띄웠습니다

## 4단계. 파일의 숫자를 바꾸면

`deploy.yaml`의 `replicas: 3`을 `replicas: 5`로 고칩니다.

```bash
nano deploy.yaml          # replicas: 3 → replicas: 5 로 고쳐 저장
kubectl apply -f deploy.yaml
kubectl get pods
```

**이렇게 나오면 성공**: `deployment.apps/hello configured`, 파드 5개(새 2개는 `AGE`가 짧음).

다시 `replicas: 3`으로 고쳐 적용합니다.

```bash
nano deploy.yaml          # replicas: 5 → replicas: 3
kubectl apply -f deploy.yaml
kubectl get pods
```

**이렇게 나오면 성공**: 파드 2개가 `Terminating`(지워지는 중)으로 보이다가 30초쯤 뒤 3개만 남습니다.

```
NAME                    READY   STATUS        RESTARTS   AGE
hello-d6646dd5c-4psw4   1/1     Running       0          46s
hello-d6646dd5c-4trnt   1/1     Terminating   0          10s
hello-d6646dd5c-tj96n   1/1     Running       0          52s
hello-d6646dd5c-z976z   1/1     Terminating   0          10s
hello-d6646dd5c-zqrhr   1/1     Running       0          52s
```

- 명령으로 "하나 더 띄워"가 아니라 **원하는 상태(개수)를 파일에 적고 적용**합니다. 쿠버네티스가 지금 상태를 그 숫자에 맞춥니다. 이것이 이 과목 전체의 방식입니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `deployment.apps/hello unchanged` | 파일을 저장하지 않았거나 같은 숫자 | `cat deploy.yaml`로 `replicas` 확인 |
| `The Deployment "hello" is invalid: … selector does not match template labels` | `selector`의 `app:`과 `template`의 `app:` 값이 다름 | 두 곳을 같게(`app: hello`) |
| 파드가 `ErrImagePull` | 실습 3의 `kind load`를 안 함 | 실습 3의 4단계 |

</details>

## 끝났는지 확인
- ☐ `kubectl get deployment`에 `hello   3/3`
- ☐ 파드를 지웠을 때 새 이름의 파드가 생겨 다시 3개가 됐다
- ☐ `replicas`를 5로 바꾸면 5개, 3으로 되돌리면 3개가 됐다

## 정리
- Deployment `hello`(파드 3개)는 **실습 5·6에서 계속 씁니다**. 지우지 마세요
- `deploy.yaml`은 `replicas: 3`인지 확인해 둡니다

## 확인 문제
1. `kubectl delete pod -l app=hello`로 이름표 `app=hello`가 붙은 파드를 한꺼번에 지워 보세요. 다시 생긴 파드들의 이름에서 바뀐 부분과 그대로인 부분은 어디인가요? `kubectl get replicaset`의 이름과 비교하세요.
2. `kubectl scale deployment hello --replicas=2`로 명령을 써서 개수를 바꾼 뒤 `kubectl get deployment`를 보세요. 그다음 `kubectl apply -f deploy.yaml`을 다시 하면 몇 개가 되나요? 왜 그럴까요?
