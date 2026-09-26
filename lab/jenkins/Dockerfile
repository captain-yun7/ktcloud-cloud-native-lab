# 수업용 Jenkins: 설정 마법사 없이 바로 쓰도록 플러그인·도구·관리자 계정을 미리 넣은 이미지 (make jenkins)
FROM jenkins/jenkins:2.568.3-lts-jdk21

USER root
ARG DOCKER_VERSION=29.8.1
ARG TRIVY_VERSION=0.74.0
ARG KUSTOMIZE_VERSION=5.8.1
RUN curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz \
      | tar xz --strip-components=1 -C /usr/local/bin docker/docker \
 && curl -fsSL https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz \
      | tar xz -C /usr/local/bin trivy \
 && curl -fsSL https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz \
      | tar xz -C /usr/local/bin kustomize

USER jenkins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
COPY casc.yaml /usr/share/jenkins/ref/casc.yaml
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false" \
    CASC_JENKINS_CONFIG=/usr/share/jenkins/ref/casc.yaml
