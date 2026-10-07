[← 실습 8](./08-postgres-데이터를-PVC에.md) · [목차](../Kubernetes-실습.md) · [실습 10 →](./10-requests와-limits-얼마나-쓰나.md)

# 실습 9. Probe — 준비됐나, 살아 있나

**무엇을 하나요**: hello Deployment에 **readinessProbe**(요청을 받을 준비가 됐나)와 **livenessProbe**(살아 있나)를 넣습니다. 일부러 검사를 틀리게 해서, 준비 안 된 파드에는 요청이 가지 않는 것(readiness)과 살아 있지 않다고 판단된 컨테이너가 다시 시작되는 것(liveness)을 봅니다. 그 사이에 **멈춘 앱을 liveness가 없을 때와 있을 때** 나란히 띄워 왜 필요한지도 확인합니다. (교안 08장)

**필요한 것**: 실습 6의 Deployment `hello`·Service `hello`·파드 `client`.

> **바로 가기** · [1. Probe를 넣은 파일 쓰기](#1단계-probe를-넣은-파일-쓰기) · [2. readiness가 실패하면 — 요청을 안 보냄](#2단계-readiness가-실패하면--요청을-안-보냄) · [3. 멈춘 앱 — liveness가 없으면, 있으면](#3단계-멈춘-앱--liveness가-없으면-있으면) · [4. liveness가 실패하면 — 다시 시작](#4단계-liveness가-실패하면--다시-시작) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. Probe를 넣은 파일 쓰기

`deploy.yaml`에 검사 두 개를 더한 새 파일 `probe.yaml`을 씁니다. 같은 Deployment `hello`를 바꿉니다.

```bash
cd ~/ktcloud-cloud-native-lab/lab/k8s/hello
nano probe.yaml
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
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          periodSeconds: 5
          failureThreshold: 3
```

**이 파일은** — `deploy.yaml`에서 맨 아래 11줄이 더해졌습니다.

| 줄 | 뜻 |
|---|---|
| `readinessProbe:` | **준비됐나** 검사. 실패하면 Service가 이 파드에 요청을 보내지 않음(파드는 그대로 둠) |
| `livenessProbe:` | **살아 있나** 검사. 계속 실패하면 컨테이너를 다시 시작함 |
| `httpGet: path: / port: 3000` | 검사 방법: 파드의 3000번 `/`에 HTTP 요청. 응답이 200~399면 성공 |
| `periodSeconds: 5` | 5초마다 검사 |
| `failureThreshold: 3` | 3번 연달아 실패하면 "실패"로 판단(기본값도 3) |

```bash
kubectl apply -f probe.yaml
kubectl rollout status deployment/hello
kubectl describe deployment hello | grep -E "Liveness|Readiness"
```

**이렇게 나오면 성공**

```
deployment.apps/hello configured
…
deployment "hello" successfully rolled out
    Liveness:      http-get http://:3000/ delay=0s timeout=1s period=5s successThreshold=1 failureThreshold=3
    Readiness:     http-get http://:3000/ delay=0s timeout=1s period=5s successThreshold=1 failureThreshold=3
```

- 파일을 바꿨으니 롤링 업데이트로 파드 3개가 새로 만들어졌습니다(실습 5)
- 지금까지의 `READY 1/1`은 "컨테이너가 시작됨"만 뜻했습니다. 이제는 "검사를 통과함"입니다

## 2단계. readiness가 실패하면 — 요청을 안 보냄

`probe.yaml`의 **readinessProbe**의 `path: /`를 `path: /ready`로 고칩니다. hello 앱에는 `/ready` 주소가 없어 404가 납니다. **livenessProbe의 path는 그대로** 둡니다.

```bash
nano probe.yaml          # readinessProbe 아래 path: / → path: /ready  (위쪽 것 하나만)
grep -n "path" probe.yaml
kubectl apply -f probe.yaml
kubectl get pods -l app=hello
```

`grep` 결과가 아래처럼 위쪽만 `/ready`인지 확인합니다.

```
23:            path: /ready
28:            path: /
```

20초쯤 뒤 `kubectl get pods -l app=hello`를 다시 봅니다.

**이렇게 나오면 성공** — 새 파드 1개가 `0/1 Running`, 기존 파드 3개는 `1/1` 그대로

```
NAME                     READY   STATUS    RESTARTS   AGE
hello-558676b9c4-8kzgn   0/1     Running   0          25s
hello-78986cb6c5-gljzp   1/1     Running   0          29s
hello-78986cb6c5-p5b5w   1/1     Running   0          27s
hello-78986cb6c5-pgl9k   1/1     Running   0          28s
```

이유와 영향을 봅니다(파드 이름은 내 화면의 `0/1`인 것).

```bash
kubectl describe pod <0/1인 파드이름> | tail -3
kubectl exec client -- wget -qO- hello
```

```
  Warning  Unhealthy  5s (x5 over 25s)  kubelet  spec.containers{hello}: Readiness probe failed: HTTP probe failed with statuscode: 404
hello, docker
```

- `0/1 Running` = 컨테이너는 돌고 있지만 **준비 안 됨**. Service는 이 파드에 요청을 보내지 않으므로 `wget`은 기존 파드에서 정상 응답을 받습니다
- 새 파드가 준비되지 않으니 롤링 업데이트가 멈춰 있고, 기존 파드도 내리지 않습니다(실습 5의 `hello:v9`와 같은 원리)
- `kubectl rollout status deployment/hello`를 치면 끝나지 않습니다(Ctrl+C)

되돌립니다.

```bash
nano probe.yaml          # path: /ready → path: /
kubectl apply -f probe.yaml
kubectl rollout status deployment/hello
```

## 3단계. 멈춘 앱 — liveness가 없으면, 있으면

livenessProbe가 왜 필요한지 먼저 봅니다. 앱이 **꺼지지는 않았는데 멈춘** 경우가 있습니다(무한 대기, 데드락 등). 프로세스는 살아 있으니 쿠버네티스 눈에는 `Running`입니다. 30초 뒤 멈추는 앱을 흉내 낸 파드 두 개를 만듭니다. 하나는 livenessProbe가 없고(`stuck`), 하나는 있습니다(`stuck-live`).

```bash
nano stuck.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: stuck
spec:
  containers:
  - name: app
    image: busybox:1.37
    command: ["sh", "-c", "touch /tmp/healthy; sleep 30; rm /tmp/healthy; sleep infinity"]
```

- `/tmp/healthy` 파일이 있는 동안을 "정상", 30초 뒤 파일을 지우고 아무 일도 안 하는 상태를 "멈춤"으로 흉내 냄

`cp stuck.yaml stuck-live.yaml` 후 `stuck-live.yaml`에서 `name: stuck`을 `name: stuck-live`로 바꾸고, 맨 아래에 다섯 줄을 붙입니다(`command:`와 같은 들여쓰기, 스페이스 4칸).

```bash
cp stuck.yaml stuck-live.yaml
nano stuck-live.yaml
```

```yaml
    livenessProbe:
      exec:
        command: ["cat", "/tmp/healthy"]
      periodSeconds: 5
      failureThreshold: 3
```

- `exec` = 컨테이너 안에서 명령을 실행해 성공(종료 코드 0)이면 살아 있음. 파일이 없어지면 `cat`이 실패 → 5초마다 3번 연달아 실패하면 다시 시작

```bash
kubectl apply -f stuck.yaml -f stuck-live.yaml
kubectl get pods stuck stuck-live -w
```

2분쯤 지켜본 뒤 Ctrl+C.

**이렇게 나오면 성공**

```
NAME         READY   STATUS    RESTARTS      AGE
stuck        1/1     Running   0             2m
stuck-live   1/1     Running   1 (45s ago)   2m
```

```bash
kubectl describe pod stuck-live | grep -E "Unhealthy|Killing"
```

```
Warning  Unhealthy  … Liveness probe failed: cat: can't open '/tmp/healthy': No such file or directory
Normal   Killing    … Container app failed liveness probe, will be restarted
```

| | liveness 없음 (`stuck`) | liveness 있음 (`stuck-live`) |
|---|---|---|
| 30초 뒤 멈춘 다음 | 계속 `Running`, `RESTARTS 0` — **쿠버네티스는 멈춘 줄 모름** | 검사 3번 실패 → 컨테이너 다시 시작(`RESTARTS 1`) |
| 누가 고치나 | 사람이 알아채고 지워야 함(밤새 멈춰 있을 수 있음) | 쿠버네티스가 자동으로(약 75초 뒤) |

- 다시 시작하면 파일이 새로 생겨 30초 동안 정상 → 또 멈춤 → 또 다시 시작을 반복합니다. 진짜 앱이라면 다시 시작으로 풀리는 멈춤을 사람 없이 복구하는 것입니다
- 다음 단계에서는 반대로, **검사를 잘못 적으면** 멀쩡한 앱을 계속 죽이는 것을 봅니다

다 봤으면 지웁니다.

```bash
kubectl delete pod stuck stuck-live --now
```

## 4단계. liveness가 실패하면 — 다시 시작

이번에는 **livenessProbe**의 `port: 3000`을 `port: 3001`로 고칩니다(앱이 없는 포트라 검사가 계속 실패). readinessProbe는 그대로 둡니다.

```bash
nano probe.yaml          # livenessProbe 아래 port: 3000 → port: 3001  (아래쪽 것 하나만)
grep -n "port:" probe.yaml
kubectl apply -f probe.yaml
kubectl rollout status deployment/hello
kubectl get pods -l app=hello -w
```

`grep` 결과:

```
24:            port: 3000
29:            port: 3001
```

`kubectl get pods -w`(계속 보기)로 1~2분 지켜봅니다. 다 봤으면 **Ctrl+C**.

**이렇게 나오면 성공** — 롤아웃은 끝나지만(readiness는 통과), 약 45초마다 `RESTARTS`가 늘어남

```
NAME                     READY   STATUS    RESTARTS      AGE
hello-55f74bf76b-d8ds7   1/1     Running   1 (15s ago)   60s
hello-55f74bf76b-fn7ss   1/1     Running   1 (13s ago)   59s
hello-55f74bf76b-g8bng   1/1     Running   1 (12s ago)   58s
…
hello-55f74bf76b-d8ds7   1/1     Running   2 (30s ago)   2m
```

```bash
kubectl describe pod <파드이름> | grep -A3 "Last State"
kubectl describe pod <파드이름> | grep -E "Liveness probe failed|will be restarted" | tail -2
```

```
    Last State:     Terminated
      Reason:       Error
      Exit Code:    137
…  Liveness probe failed: Get "http://10.244.0.74:3001/": dial tcp 10.244.0.74:3001: connect: connection refused
…  Container hello failed liveness probe, will be restarted
```

- 5초마다 검사 × 3번 실패(15초) → 쿠버네티스가 컨테이너를 끄고 새로 시작. hello 앱은 끄라는 신호를 무시해 30초를 더 기다린 뒤 강제로 꺼지므로 한 바퀴가 약 45초입니다
- `Exit Code: 137` = 강제로 꺼짐(확인 문제 2)
- 앱은 멀쩡한데 **검사를 잘못 적으면 멀쩡한 앱을 계속 죽입니다**. liveness는 앱이 실제로 여는 포트·주소로 적어야 합니다(미션 2에 같은 고장이 있음)

되돌립니다.

```bash
nano probe.yaml          # port: 3001 → port: 3000
kubectl apply -f probe.yaml
kubectl rollout status deployment/hello
kubectl get pods -l app=hello
```

**이렇게 나오면 성공**: 새 파드 3개 `1/1 Running`, `RESTARTS 0`.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `0/1 Running`이 계속 | readiness 검사가 실패 중 | `kubectl describe pod`의 `Readiness probe failed` 줄에서 주소·포트·응답 코드 확인 |
| `RESTARTS`가 계속 늘어남 | liveness 검사가 실패 중 | `describe`의 `Liveness probe failed` 줄 확인. 앱이 실제로 쓰는 포트·경로로 |
| `grep -n "path"`에 두 줄 다 `/ready` | 두 곳을 다 고침 | 아래쪽(livenessProbe)을 `/`로 되돌림 |
| `deployment.apps/hello unchanged` | 파일을 저장하지 않음 | nano에서 Ctrl+O → Enter |

</details>

## 끝났는지 확인
- ☐ readiness를 틀렸을 때 새 파드가 `0/1 Running`이었고, `wget hello`는 계속 응답했다
- ☐ liveness가 없는 `stuck`은 계속 `RESTARTS 0`, 있는 `stuck-live`는 다시 시작됐다
- ☐ liveness를 틀렸을 때 `RESTARTS`가 늘어났고, `Liveness probe failed`를 Events에서 찾았다
- ☐ 마지막에 `probe.yaml`이 처음 모양(path `/`, port 3000 두 곳)이고 파드 3개 `1/1`

## 정리
- 이제 hello는 `probe.yaml`의 것입니다. 실습 10에서 이어서 씁니다

## 확인 문제
1. 실습 7·8에서 api를 다시 시작하면 잠깐 `502 Bad Gateway`가 났습니다. todo의 `api.yaml`에 readinessProbe(`httpGet` `path: /api/health`, `port: 3000`, `periodSeconds: 2`)를 넣어 적용한 뒤, port-forward(터미널 1, `svc/web 8088:80`)를 켜고 터미널 2에서 아래를 실행하세요. 502가 나오나요? 왜 그럴까요?
   ```bash
   kubectl rollout restart deployment/api
   for i in $(seq 1 30); do curl -s -o /dev/null -w "%{http_code} " localhost:8088/api/todos; sleep 0.5; done; echo
   ```
   (`for … done` = 안의 명령을 30번 반복. 0.5초마다 응답 코드만 찍음)
2. 4단계의 `Exit Code: 137`은 무슨 뜻일까요? 앱이 스스로 끝났을 때(정상 종료)의 종료 코드와 비교하세요.
