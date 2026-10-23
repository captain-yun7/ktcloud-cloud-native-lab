#!/usr/bin/env bash
# 모니터링 미션 2 "장애 찾기" — 내 쇼핑몰(shop)에 장애를 하나 넣는다. 무엇을 넣었는지는 출력하지 않는다
# 사용: bash monitoring/break-shop.sh   (lab 폴더에서)
# 되돌리기는 미션 과제 4에서 원인을 찾은 뒤 직접 한다
set -euo pipefail
kubectl -n shop set env deploy/productcatalogservice EXTRA_LATENCY=1s >/dev/null
kubectl -n shop rollout status deploy/productcatalogservice --timeout=180s >/dev/null
echo "장애를 하나 넣었습니다 — $(date +%H:%M:%S)"
