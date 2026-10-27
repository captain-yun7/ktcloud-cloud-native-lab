#!/usr/bin/env bash
# 네트워킹 미션 1(옛 미션 2) — 고장 난 사내망이 다 고쳐졌는지 세 가지를 확인한다(원인은 알려 주지 않음)
# 사용: bash vpc-check.sh   (sudo 비밀번호를 물으면 VM 비밀번호)
VM=$(hostname -I | cut -d' ' -f1)
X(){ sudo ip netns exec "$@"; }
n=0
r=$(X db curl -s -m 6 -o /dev/null -w '%{http_code}' https://example.com); e=$?
[ "$r" = 200 ] && { echo "✔ ① db → https://example.com   $r"; n=$((n+1)); } || echo "✘ ① db → https://example.com   $r [$e]"
r=$(X web curl -s -m 3 10.0.2.10:5432); e=$?
[ "$r" = "db 10.0.2.10" ] && { echo "✔ ② web → db 5432             $r"; n=$((n+1)); } || echo "✘ ② web → db 5432             [$e]"
r=$(curl -s -m 3 "$VM:9080"); e=$?
[ "$r" = "web 10.0.1.10" ] && { echo "✔ ③ VM → $VM:9080 (web)   $r"; n=$((n+1)); } || echo "✘ ③ VM → $VM:9080 (web)   [$e]"
echo "$n/3"
[ $n = 3 ]
