[← 실습 5](./05-업데이트와-롤백.md) · [목차](../Kubernetes-실습.md) · [실습 7 →](./07-todo를-쿠버네티스에-ConfigMap과-Secret.md)

# 실습 6. Service와 port-forward

**무엇을 하나요**: 파드는 지워지고 새로 생길 때마다 IP가 바뀝니다. 바뀌지 않는 이름 `hello`(Service)를 만들어, 클러스터 안의 다른 파드가 이름으로 부르게 합니다. 그다음 `port-forward`로 VM의 8000번을 Service에 이어 `curl`과 브라우저로 봅니다. Docker의 `-p 8000:3000`이 하던 일입니다. (교안 05장)

**필요한 것**: 실습 5의 Deployment `hello`(v1, 파드 3개). 터미널 두 개([시작하기 전에 8](./00-시작하기-전에.md#8-터미널-두-개와-브라우저-ports-탭)).

> **바로 가기** · [1. 파드 IP는 바뀐다](#1단계-파드-ip는-바뀐다) · [2. Service YAML 쓰기](#2단계-service-yaml-쓰기) · [3. 적용하고 보기](#3단계-적용하고-보기) · [4. 다른 파드에서 이름으로 부르기](#4단계-다른-파드에서-이름으로-부르기) · [5. 파드를 다 바꿔도 이름은 그대로](#5단계-파드를-다-바꿔도-이름은-그대로) · [6. VM에서 보기 — port-forward](#6단계-vm에서-보기--port-forward) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 파드 IP는 바뀐다

```bash
cd ~/ktcloud-cloud-native-lab/lab/k8s/hello
kubectl get pods -o wide
kubectl delete pod -l app=hello
kubectl get pods -o wide
```

**이렇게 나오면 성공**: 지우기 전과 뒤의 `IP` 열이 모두 다릅니다(예: `10.244.0.27~29` → `10.244.0.33~35`). 파드가 새로 만들어지면 새 IP를 받습니다. 그래서 다른 앱이 파드 IP를 적어 두고 부를 수는 없습니다.

## 2단계. Service YAML 쓰기

```bash
nano service.yaml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: hello
spec:
  selector:
    app: hello
  ports:
  - port: 80
    targetPort: 3000
```

**이 파일은**

| 줄 | 뜻 |
|---|---|
| `kind: Service` · `name: hello` | Service의 이름. **이 이름이 곧 클러스터 안의 주소** |
| `selector: app: hello` | 이름표 `app: hello`를 단 파드에게 요청을 넘김(실습 4의 이름표) |
| `port: 80` | Service가 받는 포트. `hello`라고만 부르면 80번(웹 기본 포트) |
| `targetPort: 3000` | 넘겨줄 **파드(컨테이너)의 포트**. hello 앱은 3000번에서 기다림 |

Docker의 `-p 8000:3000`과 비교하면, 왼쪽(밖에서 받는 번호)이 `port`, 오른쪽(컨테이너 번호)이 `targetPort`입니다.

## 3단계. 적용하고 보기

```bash
kubectl apply -f service.yaml
kubectl get service
kubectl get endpointslices
```

**이렇게 나오면 성공**

```
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
hello        ClusterIP   10.96.116.181   <none>        80/TCP    0s
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP   3m56s
```
```
NAME          ADDRESSTYPE   PORTS   ENDPOINTS                             AGE
hello-96rvp   IPv4          3000    10.244.0.33,10.244.0.34,10.244.0.35   48s
kubernetes    IPv4          6443    172.18.0.2                            4m44s
```

- `CLUSTER-IP` = Service의 고정 IP(클러스터 안에서만 쓰는 주소). 파드가 바뀌어도 그대로
- `endpointslices`의 `ENDPOINTS` = 지금 요청을 넘겨 줄 **파드 IP 목록**. 1단계의 새 파드 IP 3개와 같음. 포트는 `targetPort`인 3000
- `kubernetes` Service는 클러스터가 처음부터 가진 것(API 서버). 신경 쓰지 않아도 됩니다

## 4단계. 다른 파드에서 이름으로 부르기

클러스터 안에서 요청을 보내 볼 작은 파드 `client`를 하나 띄웁니다. `busybox`는 `wget` 같은 기본 도구만 든 아주 작은 이미지이고, `sleep infinity` = 아무것도 안 하고 계속 켜져 있으라는 명령입니다.

```bash
kubectl run client --image=busybox:1.37 -- sleep infinity
kubectl get pod client
kubectl exec client -- wget -qO- hello
```

**이 명령은**
- `kubectl run 이름 --image=이미지 -- 명령` = YAML 없이 파드 하나를 바로 만듦(`docker run`과 비슷)
- `kubectl exec client -- wget -qO- hello` = client 파드 안에서 **이름 `hello`** 로 요청

**이렇게 나오면 성공**: `client   1/1   Running`(처음이면 이미지를 받느라 몇 초), 그리고

```
hello, docker
```

이름 `hello` → Service → 파드 3개 중 하나의 3000번으로 넘어갔습니다. Docker 실습 12에서 같은 네트워크의 컨테이너를 이름(`db`)으로 부르던 것과 같습니다.

## 5단계. 파드를 다 바꿔도 이름은 그대로

```bash
kubectl delete pod -l app=hello
kubectl get endpointslices
kubectl get service hello
kubectl exec client -- wget -qO- hello
```

**이렇게 나오면 성공**: 엔드포인트의 IP는 새 파드 IP로 바뀌고, Service의 `CLUSTER-IP`는 3단계와 같으며, `wget`은 여전히 `hello, docker`.

- Service가 이름표로 파드를 계속 찾아 엔드포인트 목록을 새로 고칩니다. 부르는 쪽은 파드가 바뀐 줄 모릅니다

## 6단계. VM에서 보기 — port-forward

**터미널 1**에서:

```bash
kubectl port-forward svc/hello 8000:80
```

```
Forwarding from 127.0.0.1:8000 -> 3000
Forwarding from [::1]:8000 -> 3000
```

명령이 끝나지 않고 멈춰 있는 것이 정상입니다(이어 주는 중). **터미널 2**에서:

```bash
curl localhost:8000
```

**이렇게 나오면 성공**: `hello, docker`. 터미널 1에는 요청마다 `Handling connection for 8000` 줄이 늘어납니다.

**이 명령은**: `kubectl port-forward svc/hello 8000:80` = **VM의 8000** → Service `hello`의 **80** → 파드의 3000. 화면의 `-> 3000`은 결국 파드 하나의 3000번에 붙었다는 뜻입니다.

브라우저로 보기: VS Code **PORTS** 탭에서 `8000`을 전달 → `http://localhost:8000` → `hello, docker`.

다 봤으면 **터미널 1에서 Ctrl+C**. 그 뒤에는 `curl localhost:8000`이 `Failed to connect`입니다.

- port-forward는 내 VM에서 잠깐 확인할 때 쓰는 방법입니다. 여러 사람이 쓰는 입구는 10장 Ingress에서 만듭니다

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `wget: bad address 'helo'` | Service 이름 오타(없는 이름) | `kubectl get service`로 이름 확인 |
| `wget: can't connect to remote host (10.96.…): Connection refused` | ① 엔드포인트가 비어 있음 — `selector`가 파드 이름표와 다름, 또는 ② `targetPort`가 앱 포트(3000)와 다름 | `kubectl get endpointslices`를 봄: `ENDPOINTS`가 `<unset>`이면 ① → `selector: app: hello`로. IP는 있는데 `PORTS`가 3000이 아니면 ② → `targetPort: 3000`으로 고쳐 다시 apply |
| `wget`이 오래 멈춤 | Service를 막 만들었거나 고친 직후(몇 초 걸림), 또는 위 ② | Ctrl+C 후 다시. `wget -T 3 …`이면 3초 뒤 끝남 |
| `Unable to listen on port 8000: … address already in use` | VM의 8000을 다른 것이 씀(Docker 과목의 컨테이너 등) | `docker ps`로 8000을 쓰는 컨테이너를 지우거나, `8001:80`처럼 다른 번호 |
| `Error from server (NotFound): services "helo" not found` | port-forward의 Service 이름 오타 | `kubectl get service`로 확인 |
| `curl: (7) Failed to connect to localhost port 8000` | 터미널 1의 port-forward가 꺼짐 | 터미널 1에서 다시 실행 |

</details>

## 끝났는지 확인
- ☐ `kubectl get endpointslices`에 hello 파드 IP 3개
- ☐ `kubectl exec client -- wget -qO- hello`에 `hello, docker` (파드를 모두 지운 뒤에도)
- ☐ port-forward 중 `curl localhost:8000`에 `hello, docker`

## 정리
- Service `hello`와 파드 `client`는 **실습 9·11에서 다시 씁니다**. 지우지 마세요
- port-forward는 Ctrl+C로 끕니다

## 확인 문제
1. `deploy.yaml`의 `replicas`를 5로 바꿔 적용한 뒤 `kubectl get endpointslices`를 보세요. 엔드포인트는 몇 개인가요? 확인한 뒤 3으로 되돌립니다.
2. 6단계 port-forward 화면의 `Forwarding from 127.0.0.1:8000 -> 3000`에서 8000, 3000은 각각 무엇의 포트인가요? `service.yaml`의 `port: 80`은 이 경로에서 어디에 쓰였을까요?
