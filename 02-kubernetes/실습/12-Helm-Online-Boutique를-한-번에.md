[← 실습 11](./11-Ingress-주소-하나로-나눠-보내기.md) · [목차](../Kubernetes-실습.md) · [자주 쓴 명령과 오류 →](./99-자주-쓴-명령과-오류.md)

# 실습 12. Helm — Online Boutique를 한 번에

**무엇을 하나요**: 서비스 11개짜리 Online Boutique를 **Helm 차트**로 한 번에 설치하고, 값을 바꿔 업그레이드한 뒤 되돌립니다. 미션 1에서 YAML 수십 개를 직접 쓰던 일을 명령 한 줄로 합니다. (교안 11장)

**필요한 것**: 실습 11의 Traefik(확인 문제 1). 메모리 여유 — 미션 1의 `mission1` 네임스페이스가 남아 있으면 먼저 지웁니다(`kubectl delete namespace mission1`).

**왜 필요한가요**: 미션 1에서 서비스 6개의 YAML을 손으로 쓰고 `kubectl apply`로 올렸습니다. Online Boutique 전체는 Deployment·Service·ServiceAccount가 **33개**입니다. 이것을 `kubectl`로만 관리하면 이렇게 됩니다.

| 할 일 | `kubectl apply -f` 파일들 (미션 1 방식) | Helm |
|---|---|---|
| 설치 | YAML 33개를 쓰고 하나씩(또는 폴더째) apply | `helm install` 한 줄 |
| 값 바꾸기(이미지 버전·옵션) | 여러 파일에서 찾아 고침 | 값 파일 하나(`my-values.yaml`)나 `--set` |
| 지금 무엇이 몇 번째로 설치됐나 | 기억·메모에 의존 | `helm list`·`helm history`(REVISION 번호) |
| 되돌리기 | Deployment마다 `rollout undo`, Service 등은 못 되돌림 | `helm rollback` 한 번에 전체 |
| 지우기 | 파일을 다 찾아 delete, 빠뜨리면 남음 | `helm uninstall` 한 번 |

실습 11의 `make ingress`(Traefik)도 안에서 `helm`으로 설치했습니다. 다음 과목의 Kyverno(보안)·Argo CD(CI/CD)·Prometheus와 Loki(모니터링)·Envoy Gateway(API Gateway)도 모두 `make`가 안에서 Helm 차트로 설치합니다(`lab/Makefile`).

> **바로 가기** · [1. 차트 받기](#1단계-차트-받기) · [2. 바꿀 값 적기](#2단계-바꿀-값-적기) · [3. 설치](#3단계-설치) · [4. 값을 바꿔 업그레이드, 그리고 되돌리기](#4단계-값을-바꿔-업그레이드-그리고-되돌리기) · [끝났는지 확인](#끝났는지-확인) · [정리](#정리) · [확인 문제](#확인-문제)

## 1단계. 차트 받기

Online Boutique 저장소에 Helm 차트가 들어 있습니다. Docker 미션 2 도전 B에서 이미 받았다면 `~/ob`가 있습니다.

```bash
ls ~/ob/helm-chart || git clone --depth 1 --branch v0.10.7 https://github.com/GoogleCloudPlatform/microservices-demo.git ~/ob
ls ~/ob/helm-chart
```

**이 명령은**: `A || B` = A가 실패하면(폴더가 없으면) B를 실행. 이미 있으면 받지 않습니다.

**이렇게 나오면 성공**: `Chart.yaml  README.md  templates  values.yaml`

| 파일 | 뜻 |
|---|---|
| `templates/` | 매니페스트 틀. 값이 들어갈 자리가 비어 있음 |
| `values.yaml` | 틀에 넣을 **기본값** |
| `Chart.yaml` | 차트 이름·버전 |

## 2단계. 바꿀 값 적기

```bash
mkdir -p ~/k8s/helm && cd ~/k8s/helm
helm show values ~/ob/helm-chart | grep -A3 "^frontend:"
nano my-values.yaml
```

```yaml
frontend:
  externalService: false
loadGenerator:
  create: false
```

| 값 | 뜻 |
|---|---|
| `frontend.externalService: false` | 클라우드용 외부 주소(LoadBalancer)를 만들지 않음. kind에는 없음(미션 1 도전 B의 `<pending>`) |
| `loadGenerator.create: false` | 가짜 손님을 만드는 부하 생성기를 만들지 않음(자원 아끼기) |

- `helm show values` = 차트의 기본값 전체. 나는 **바꿀 것만** 적습니다

## 3단계. 설치

```bash
helm template shop ~/ob/helm-chart -f my-values.yaml | grep -c "^kind:"
helm install shop ~/ob/helm-chart -n shop --create-namespace -f my-values.yaml
helm list -n shop
kubectl get deploy -n shop
```

**이 명령은**
- `helm template` = 설치하지 않고 **만들어질 YAML만** 출력(미리 보기). `grep -c "^kind:"` = 그 안의 리소스 개수
- `helm install 이름 차트 -n 네임스페이스 -f 값파일` = 설치. 이름 `shop`을 **릴리스**라고 부름. `--create-namespace` = 네임스페이스 `shop`이 없으면 만듦

**이렇게 나오면 성공**

```
33
NAME: shop
NAMESPACE: shop
STATUS: deployed
REVISION: 1
```
```
NAME	NAMESPACE	REVISION	UPDATED                                	STATUS  	CHART                	APP VERSION
shop	shop     	1       	2026-10-01 22:46:56 +0900 KST	deployed	onlineboutique-0.10.7	v0.10.7
```

30초쯤 뒤 `kubectl get deploy -n shop`이 11개 모두 `1/1`:

```
NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
adservice               1/1     1            1           33s
cartservice             1/1     1            1           33s
…
shippingservice         1/1     1            1           33s
```

- 리소스 33개 = Deployment 11 + Service 11 + ServiceAccount 11. 미션 1에서 손으로 6개 서비스를 쓰던 것을 한 번에 만들었습니다

## 4단계. 값을 바꿔 업그레이드, 그리고 되돌리기

```bash
helm upgrade shop ~/ob/helm-chart -n shop -f my-values.yaml --set frontend.cymbalBranding=true
helm history shop -n shop
helm rollback shop 1 -n shop
helm history shop -n shop
helm get values shop -n shop
```

**이 명령은**
- `helm upgrade … --set 키=값` = 값 하나를 더 바꿔 다시 적용(쇼핑몰 화면의 상표를 바꾸는 값)
- `helm history` = 릴리스 버전 목록, `helm rollback shop 1` = 1번 버전으로 되돌림
- `helm get values` = 내가 준 값

**이렇게 나오면 성공**

```
Release "shop" has been upgraded. Happy Helming!
REVISION	UPDATED                 	STATUS    	CHART                	APP VERSION	DESCRIPTION
1       	Thu Oct  1 22:46:56 2026	superseded	onlineboutique-0.10.7	v0.10.7    	Install complete
2       	Thu Oct  1 22:47:29 2026	deployed  	onlineboutique-0.10.7	v0.10.7    	Upgrade complete
Rollback was a success! Happy Helming!
…
3       	Thu Oct  1 22:47:30 2026	deployed  	onlineboutique-0.10.7	v0.10.7    	Rollback to 1
USER-SUPPLIED VALUES:
frontend:
  externalService: false
loadGenerator:
  create: false
```

- `kubectl rollout undo`(실습 5)는 Deployment **하나**를, `helm rollback`은 차트 **전체**(Deployment·Service … 33개)를 한 번에 되돌립니다
- 되돌리기도 새 번호(3)로 남습니다(실습 5 확인 문제 1과 같은 방식)

<details><summary><b>이렇게 나오면?</b> — 자주 나는 오류와 해결 (눌러서 펼치기)</summary>

| 화면 | 원인 | 해결 |
|---|---|---|
| `Error: INSTALLATION FAILED: … cannot reuse a name that is still in use` | 이미 `shop`을 설치함 | `helm list -n shop`으로 확인. 다시 하려면 `helm uninstall shop -n shop` 후 설치 |
| 일부 파드가 `Pending`, Events에 `Insufficient cpu`/`memory` | 미션 1 등 다른 것이 자리를 차지 | `kubectl delete namespace mission1` 등 안 쓰는 것 정리 |
| `Error: path "…/helm-chart" not found` | `~/ob`를 받지 않음 | 1단계 |

</details>

## 끝났는지 확인
- ☐ `kubectl get deploy -n shop`에 11개 모두 `1/1`
- ☐ `helm history shop -n shop`에 `Rollback to 1`

## 정리
확인 문제까지 끝났으면 지웁니다(클라우드 보안 미션 2에서 같은 값으로 다시 설치합니다).

```bash
helm uninstall shop -n shop
kubectl delete namespace shop
```

- hello·todo도 더 쓰지 않으면 지워도 됩니다: `kubectl delete deployment hello api web db`, `kubectl delete service hello api web db`, `kubectl delete pod client`, `kubectl delete pvc db-data`
- 클러스터 `lab`과 Traefik은 **다음 과목에서 그대로 씁니다**. `make down` 하지 마세요

## 확인 문제
1. 설치한 `shop`을 **Ingress로 열어** `curl shop.localhost`에서 쇼핑몰 홈이 보이게 하세요. frontend Service의 이름과 포트는 `kubectl get svc -n shop`에서 찾습니다. Ingress도 `namespace: shop`에 만들어야 합니다(Ingress는 같은 네임스페이스의 Service만 가리킴).
2. `helm template`에 `--set loadGenerator.create=true`를 더하면 만들어질 리소스 수는 몇 개로 바뀌나요? 어떤 종류가 늘었나요?
