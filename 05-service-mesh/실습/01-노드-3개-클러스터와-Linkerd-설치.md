[← 시작하기 전에](./00-시작하기-전에.md) · [목차](../서비스-메시-실습.md) · [실습 2 →](./02-todo에-주입하고-mTLS-성공률-보기.md)

# 실습 1. 노드 3개 클러스터와 Linkerd 설치

**무엇을 하나요**: 클러스터를 노드 3개(컨트롤 플레인 1 + 워커 2)로 다시 만들고, 첫 번째 메시 도구 **Linkerd**를 설치합니다. 제어 영역(프록시에게 인증서·주소를 나눠 주는 곳)과 관측 확장 viz(지표 보기)를 올립니다. 앱에는 아직 아무것도 하지 않습니다. (교안 02장)

**필요한 것**: 실습 저장소 `~/ktcloud-cloud-native-lab`.

> **바로 가기** · [1. 저장소와 메시 도구](#1단계-저장소와-메시-도구) · [2. 노드 3개로 다시 만들기](#2단계-노드-3개로-다시-만들기) · [3. Gateway API와 사전 점검](#3단계-gateway-api와-사전-점검) · [4. 제어 영역 설치](#4단계-제어-영역-설치) · [5. 관측 확장 viz 설치](#5단계-관측-확장-viz-설치) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 저장소와 메시 도구

```bash
cd ~/ktcloud-cloud-native-lab && git pull && cd lab
make tools                    # linkerd·istioctl 추가
source ~/.bashrc
linkerd version --client --short
istioctl version --remote=false
```

**이 명령은**: 실습 저장소를 최신으로 받고, `lab/.mise.toml`에 적힌 도구를 설치. 이번에 `linkerd`(edge-26.9.3)와 `istioctl`(1.31.1)이 들어옵니다. `source ~/.bashrc` = 새 도구를 지금 터미널이 찾게 함.

**이렇게 나오면 성공**

```
edge-26.9.3
client version: 1.31.1
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `make: *** No rule to make target 'tools'.` | `lab` 폴더 밖에서 실행 | `cd ~/ktcloud-cloud-native-lab/lab` 후 다시 |
| `linkerd: command not found` | 새 도구 경로가 아직 안 잡힘 | `source ~/.bashrc` 또는 터미널을 새로 열기 |

</details>

## 2단계. 노드 3개로 다시 만들기

```bash
make reset PROFILE=full       # 컨트롤 플레인 1 + 워커 2
make ingress
kubectl get nodes
```

**이 명령은**: `make reset` = 지금 클러스터를 지우고 새로 만듦. `PROFILE=full`이면 노드 3개. `make ingress` = Kubernetes 실습 11의 Traefik(VM 80번 입구)을 다시 설치.

**이렇게 나오면 성공**: 세 줄 모두 `Ready` (강사 VM에서 `make reset` 약 27초 + `make ingress` 약 25초)

```
NAME                STATUS   ROLES           AGE   VERSION
lab-control-plane   Ready    control-plane   38s   v1.37.0
lab-worker          Ready    <none>          28s   v1.37.0
lab-worker2         Ready    <none>          28s   v1.37.0
```

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `NotReady`가 섞임 | 막 만들어져 준비 중 | 20~30초 뒤 다시 |
| 노드가 1개(`lab-control-plane`만) | `PROFILE=full`을 빠뜨림 | `make reset PROFILE=full` 다시 |

</details>

## 3단계. Gateway API와 사전 점검

```bash
make gateway-api              # v1.5.1 설치됨
linkerd check --pre
```

**이 명령은**: `make gateway-api` = 쿠버네티스 표준 **Gateway API**의 리소스 종류(CRD)를 클러스터에 추가. Linkerd는 이것이 없으면 사전 점검에서 멈춥니다. `linkerd check --pre` = 설치하기 전에 클러스터가 준비됐는지 점검.

**이렇게 나오면 성공**: 맨 아래 `Status check results are √`. 위쪽의 `‼ … latest edge version is …`(더 새 버전이 있다는 안내)는 괜찮습니다.

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `× Gateway API CRDs are installed` | `make gateway-api`를 빠뜨림 | `cd ~/ktcloud-cloud-native-lab/lab && make gateway-api` |

</details>

## 4단계. 제어 영역 설치

```bash
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -
linkerd check                              # 약 1분
kubectl get pods -n linkerd
```

**이 명령은**: `linkerd install`은 설치할 YAML을 **출력만** 합니다. 그것을 `| kubectl apply -f -`(앞 명령의 출력을 그대로 적용)로 클러스터에 넣습니다. 첫 줄은 Linkerd 리소스 종류(CRD), 둘째 줄은 본체.

**이렇게 나오면 성공**: `linkerd check` 맨 아래 `Status check results are √`(강사 VM 약 60초), 파드 3개 `Running`.

```
NAME                                      READY   STATUS    RESTARTS   AGE
linkerd-destination-55cf854889-njh54      4/4     Running   0          104s
linkerd-identity-565d9dc5c4-2snz2         2/2     Running   0          104s
linkerd-proxy-injector-6cd54d9477-przp5   2/2     Running   0          104s
```

| 파드 | 하는 일 |
|---|---|
| linkerd-identity | 파드마다 인증서(신분증)를 발급 — mTLS에 씀 |
| linkerd-destination | 프록시에게 "이 서비스의 파드는 어디, 이 연결은 허용인가"를 알려 줌 |
| linkerd-proxy-injector | 파드가 만들어질 때 프록시를 끼워 넣음 |

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `linkerd check`가 오래 `×`·`‼`에서 멈춤 | 이미지를 받는 중 | 기다림. 1~2분 뒤에도 그대로면 `kubectl -n linkerd get pods`로 `ImagePullBackOff` 확인 |

</details>

## 5단계. 관측 확장 viz 설치

```bash
linkerd viz install | kubectl apply -f -   # 관측 확장 (Prometheus 포함)
linkerd viz check                          # 약 40초
```

**이 명령은**: viz = 프록시가 센 숫자(성공률·요청 수·지연)를 모아 보여 주는 확장. 숫자를 담아 둘 Prometheus도 같이 들어갑니다. 실습 2의 `linkerd viz stat`·`edges`·`tap`이 이것을 씁니다.

**이렇게 나오면 성공**: `Status check results are √` (강사 VM 약 46초)

## 끝났는지 확인
- ☐ `kubectl get nodes`에 노드 3개 `Ready`
- ☐ `linkerd check`의 결과가 `Status check results are √`
- ☐ `linkerd viz check`의 결과가 `Status check results are √`

## 정리
- 이 클러스터는 **모니터링 과목까지 계속 씁니다.** 지우지 마세요
- Linkerd는 실습 4에서 지웁니다. 그전까지 그대로 둡니다

## 확인 문제
1. `kubectl get pods -n linkerd`의 세 파드 중, 실습 2에서 파드에 프록시를 넣을 때 일하는 것은 무엇이고, 프록시가 뜰 때 인증서를 주는 것은 무엇인가요?
2. `kubectl get nodes`에 `ROLES`가 `<none>`인 노드는 몇 개이고, 무엇을 하나요?
