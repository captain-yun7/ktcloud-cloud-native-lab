# kt cloud TECH UP 클라우드 네이티브 — 실습 자료

수업에서 쓰는 **실습 문서**와 **미션 문서**를 과목별로 올리는 저장소입니다. 새 과목 자료가 올라오면 수업에서 알려 드립니다.

## 처음 한 번
1. [실습 서버 접속 안내](./00-접속-안내.md)대로 본인 VM에 접속합니다
2. 로컬 환경도 준비합니다 — [로컬 환경 설치 안내](./00-로컬-환경-설치-안내.md)
3. VM에서 이 저장소를 받습니다
   ```bash
   git clone https://github.com/captain-yun7/ktcloud-cloud-native-lab.git
   ```
4. 새 자료가 올라오면
   ```bash
   cd ~/ktcloud-cloud-native-lab && git pull
   ```

## 수업 진행
| 구분 | 하는 일 | 자료 |
|---|---|---|
| 설명 | 강사가 교안으로 개념을 설명합니다 | 수업 화면 |
| 실습 | 실습 문서를 보고 각자 서버에서 직접 합니다. 실습마다 끝에 **확인 문제**가 있습니다 | `과목-실습.md` |
| 미션 | 몇 장을 배운 뒤 스스로 풉니다. 막히면 힌트를 1단계부터 하나씩 펼칩니다 | `과목-미션.md` |
| 리뷰 | 정답과 자주 막힌 곳을 정리합니다 | 수업 화면 |

- 명령은 문서에서 복사해 붙여 넣으세요
- 막히면 에러 첫 줄·로그를 먼저 확인하고, 그래도 안 되면 Discord에 질문합니다
- 미션 문서의 **결과 정리 표**를 채워 두면 리뷰 때 함께 봅니다

## 자료
| 과목 | 실습 | 미션 |
|---|---|---|
| Docker | [Docker-실습](./01-docker/Docker-실습.md) | [Docker-미션](./01-docker/Docker-미션.md) |

`lab/` 폴더에는 실습에 쓰는 설정 파일과 스크립트(`make tools`, `make up` 등)가 있습니다. 쿠버네티스 과목부터 씁니다.

## 샘플앱
과정 전체에서 [Online Boutique v0.10.7](https://github.com/GoogleCloudPlatform/microservices-demo) (Google, Apache-2.0)을 씁니다.
