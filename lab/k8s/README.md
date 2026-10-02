# Kubernetes 실습 파일

Kubernetes 과목 실습에서 쓰는 YAML을 두는 폴더입니다. 실습 순서와 명령은 `02-kubernetes/Kubernetes-실습.md`를 봅니다.

| 폴더 | 무엇 | 쓰는 곳 |
|---|---|---|
| `hello/` | 실습에서 직접 쓰는 hello 앱 YAML(`pod.yaml`, `deploy.yaml`, `service.yaml` …). 처음에는 없음 — 실습 3에서 만듦 | 실습 3~6, 9, 10 |
| `todo/` | todo 앱의 `db.yaml`(PostgreSQL)·`web.yaml`(nginx 화면)은 들어 있음. `todo-config.yaml`·`api.yaml`·`db-pvc.yaml`은 직접 씀 | 실습 7, 8 |
| `ingress/` | `ing.yaml` — 실습 11에서 만듦 | 실습 11 |

이미지는 Docker 과목에서 만든 것(`hello:v1`·`hello:v2`, `lab/docker/todo`로 만드는 `todo-api:v1`·`todo-web:v1`)을 `kind load docker-image … --name lab`으로 클러스터에 넣어 씁니다.
