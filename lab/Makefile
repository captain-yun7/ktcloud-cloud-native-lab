# 실습 클러스터 관리. 사용: make up [PROFILE=lite|full] / make down / make reset / make status
PROFILE ?= lite
CLUSTER := lab
TRAEFIK_CHART := 41.6.0
KYVERNO_CHART := 3.9.1
ARGOCD_CHART := 10.9.2
GATEWAY_API := v1.5.1
KPS_CHART := 91.6.0
LOKI_CHART := 7.3.0
ALLOY_CHART := 1.13.0
EG_VERSION := 1.9.1
KYVERNO_IMAGES := $(foreach i,kyverno kyvernopre background-controller cleanup-controller reports-controller,reg.kyverno.io/kyverno/$(i):v1.19.1) ghcr.io/kyverno/readiness-checker:v1.19.1
METRICS_URL := https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.9.0/components.yaml

.PHONY: up down reset status doctor tools ingress kyverno kyverno-images jenkins jenkins-image jenkins-down argocd gateway-api monitoring logging

tools:            ## 고정 버전 도구 설치 (.mise.toml)
	@./scripts/install-tools.sh

doctor:           ## 환경 점검 → doctor-report.txt
	@./scripts/doctor.sh

up:               ## 클러스터 생성 + metrics-server
	@kind get clusters 2>/dev/null | grep -qx $(CLUSTER) && echo "클러스터 '$(CLUSTER)' 이미 있음 (make reset 으로 재생성)" || kind create cluster --config kind/$(PROFILE).yaml
	@kubectl apply -f $(METRICS_URL) >/dev/null
	@kubectl -n kube-system patch deploy metrics-server --type=json -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' >/dev/null 2>&1 || true
	@echo "준비 완료. 확인: make status"

ingress:          ## Ingress 컨트롤러(Traefik) 설치 — Kubernetes 과목 Ingress 실습부터. http://<이름>.localhost 로 접속
	@helm upgrade --install traefik traefik --repo https://traefik.github.io/charts --version $(TRAEFIK_CHART) \
	  -n traefik --create-namespace -f ingress/traefik-values.yaml --wait >/dev/null
	@kubectl get ingressclass

kyverno-images:   ## Kyverno 이미지를 VM 도커에 미리 받기 (클러스터를 다시 만들어도 남는다)
	@for i in $(KYVERNO_IMAGES); do docker image inspect $$i >/dev/null 2>&1 || docker pull -q $$i >/dev/null; done
	@echo "Kyverno 이미지 준비 완료"

kyverno: kyverno-images  ## 정책 엔진 Kyverno 설치 — 보안 과목. 이미지를 kind에 넣은 뒤 설치해 외부 저장소가 느려도 영향 없음
	@# 여러 아키텍처 이미지는 kind load docker-image가 실패한다 → amd64만 묶어서 넣는다 (2026-09-26 s30 확인)
	@docker save --platform linux/amd64 -o /tmp/kyverno-images.tar $(KYVERNO_IMAGES)
	@kind load image-archive /tmp/kyverno-images.tar --name $(CLUSTER) && rm -f /tmp/kyverno-images.tar
	@helm upgrade --install kyverno kyverno --repo https://kyverno.github.io/kyverno/ --version $(KYVERNO_CHART) \
	  -n kyverno --create-namespace --wait --timeout 5m >/dev/null
	@# 파드가 Ready여도 웹훅이 몇 초 늦게 열려 첫 정책 apply가 connection refused로 실패할 수 있다 → 받을 준비가 될 때까지 기다린다 (2026-09-28)
	@for i in $$(seq 1 60); do kubectl apply --dry-run=server -f security/kyverno-ready-check.yaml >/dev/null 2>&1 && break; sleep 2; done
	@kubectl -n kyverno get pods

monitoring:       ## kube-prometheus-stack (모니터링 과목) — grafana.localhost(admin/lab-grafana), prometheus.localhost, alertmanager.localhost
	@helm upgrade --install kps kube-prometheus-stack --repo https://prometheus-community.github.io/helm-charts --version $(KPS_CHART) \
	  -n monitoring --create-namespace -f monitoring/kps-values.yaml --wait --timeout 10m >/dev/null
	@kubectl -n monitoring get pods

logging:          ## Loki + Alloy (모니터링 과목 로그 실습) — Grafana의 Loki 데이터 소스로 조회
	@helm upgrade --install loki loki --repo https://grafana.github.io/helm-charts --version $(LOKI_CHART) \
	  -n monitoring -f monitoring/loki-values.yaml --wait --timeout 6m >/dev/null
	@helm upgrade --install alloy alloy --repo https://grafana.github.io/helm-charts --version $(ALLOY_CHART) \
	  -n monitoring -f monitoring/alloy-values.yaml --wait --timeout 5m >/dev/null
	@kubectl -n monitoring get pods | grep -E "loki|alloy"

gateway-api:      ## Gateway API CRD (Service Mesh 과목 Linkerd 설치 전 필수) — Linkerd edge-26.9.3이 요구하는 버전. API Gateway 과목의 make envoy-gateway가 v1.6.1로 올린다
	@kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/$(GATEWAY_API)/standard-install.yaml >/dev/null
	@kubectl get crd gateways.gateway.networking.k8s.io -o jsonpath='{.metadata.annotations.gateway\.networking\.k8s\.io/bundle-version}' && echo " 설치됨"

envoy-gateway:    ## Envoy Gateway (API Gateway 과목) — CRD(Gateway API v1.6.1 포함) → 컨트롤러 → GatewayClass eg. 입구는 http://<이름>.localhost:8080
	@helm template eg-crds oci://docker.io/envoyproxy/gateway-crds-helm --version $(EG_VERSION) \
	  --set crds.gatewayAPI.enabled=true --set crds.gatewayAPI.channel=standard --set crds.envoyGateway.enabled=true \
	  | kubectl apply --server-side --force-conflicts -f - >/dev/null
	@helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm --version $(EG_VERSION) --skip-crds \
	  -n envoy-gateway-system --create-namespace --wait --timeout 5m >/dev/null
	@kubectl apply -f api-gateway/gatewayclass.yaml >/dev/null
	@kubectl -n envoy-gateway-system get pods && kubectl get gatewayclass eg

argocd:           ## Argo CD (CI/CD 과목) — http://argocd.localhost, 계정 admin (make ingress 먼저)
	@helm upgrade --install argocd argo-cd --repo https://argoproj.github.io/argo-helm --version $(ARGOCD_CHART) \
	  -n argocd --create-namespace -f argocd/values.yaml --wait --timeout 5m >/dev/null
	@echo "Argo CD: http://argocd.localhost  계정 admin / 비밀번호 $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"

# Jenkins 작업 폴더를 VM과 컨테이너에서 같은 경로로 연결한다 → 파이프라인 안의 docker run -v "$$WORKSPACE" 가 VM의 같은 폴더를 가리킴
JENKINS_DIR := $(HOME)/jenkins_home
jenkins-image:    ## Jenkins 이미지만 미리 빌드 (CI/CD 과목 Jenkins 실습 전에 미리)
	@docker build -q -t lab-jenkins jenkins >/dev/null && echo "Jenkins 이미지 준비 완료"

jenkins: jenkins-image  ## Jenkins (CI/CD 과목) — http://localhost:8081, 계정 admin, 비밀번호는 ~/.jenkins-admin-password
	@test -s $(HOME)/.jenkins-admin-password || openssl rand -hex 8 > $(HOME)/.jenkins-admin-password
	@chmod 600 $(HOME)/.jenkins-admin-password && mkdir -p $(JENKINS_DIR)
	@docker rm -f jenkins >/dev/null 2>&1 || true
	@docker run -d --name jenkins --restart unless-stopped --memory 2g -p 8081:8080 \
	  -e JENKINS_HOME=$(JENKINS_DIR) -e JENKINS_ADMIN_PASSWORD="$$(cat $(HOME)/.jenkins-admin-password)" \
	  -v $(JENKINS_DIR):$(JENKINS_DIR) -v /var/run/docker.sock:/var/run/docker.sock \
	  --group-add $$(stat -c %g /var/run/docker.sock) lab-jenkins >/dev/null
	@echo "Jenkins 시작 (1분쯤 걸림): http://localhost:8081  계정 admin / 비밀번호 $$(cat $(HOME)/.jenkins-admin-password)"

jenkins-down:     ## Jenkins 중지 (작업 기록은 ~/jenkins_home에 남음)
	@docker rm -f jenkins

down:             ## 클러스터 삭제
	@kind delete cluster --name $(CLUSTER)

reset: down up    ## 삭제 후 재생성

status:           ## 노드·파드 상태
	@kubectl get nodes -o wide
	@kubectl get pods -A
