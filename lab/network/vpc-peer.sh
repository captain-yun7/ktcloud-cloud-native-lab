#!/usr/bin/env bash
# 네트워킹 과목 부록 B1(피어링) 도구 — VPC를 더 만들고, 두 VPC 사이에 피어링 연결(선)을 놓는다. 라우팅 표의 줄은 수업에서 직접 넣는다
#   VPC A = vpc-up.sh가 만든 사내망(라우터 rt, 10.0.0.0/16). 더 만드는 VPC는 네임스페이스 하나 = 라우터 + 서버 한 대
# 사용: sudo bash vpc-peer.sh new  <이름> <서버 주소>   예) new vpc-b 10.1.1.10  → 서버 http://10.1.1.10 이 "vpc-b 10.1.1.10"을 돌려줌
#       sudo bash vpc-peer.sh link <쪽1> <쪽2> <N>       예) link rt vpc-b 12    → 선 pcx-ab ↔ pcx-ba, 주소 192.168.12.1(쪽1) · 192.168.12.2(쪽2)
#   더 만든 VPC는 다른 VPC의 패킷을 넘겨 주지 않는다(ip_forward 0) — 클라우드 피어링이 전이되지 않는 것과 같게
# 지우기: sudo bash vpc-down.sh
set -e
[ "$(id -u)" = 0 ] || { echo "sudo로 실행하세요"; exit 1; }
letter(){ case $1 in rt) echo a;; vpc-*) echo "${1#vpc-}";; *) echo "$1";; esac; }
case "$1" in
  new)
    n=$2; ipa=$3; [ -n "$n" ] && [ -n "$ipa" ] || { echo "사용: sudo bash vpc-peer.sh new <이름> <서버 주소>"; exit 1; }
    ip netns add "$n"; ip -n "$n" link set lo up
    ip -n "$n" addr add "$ipa/32" dev lo
    ip netns exec "$n" sysctl -qw net.ipv4.ip_forward=0
    mkdir -p "/tmp/vpc-$n" && echo "$n $ipa" > "/tmp/vpc-$n/index.html"
    ip netns exec "$n" sh -c "cd /tmp/vpc-$n && nohup python3 -m http.server 80 >/dev/null 2>&1 &"
    echo "VPC $n 준비 완료: 서버 $ipa:80";;
  link)
    a=$2; b=$3; x=$4; [ -n "$a" ] && [ -n "$b" ] && [ -n "$x" ] || { echo "사용: sudo bash vpc-peer.sh link <쪽1> <쪽2> <N>"; exit 1; }
    la=$(letter "$a"); lb=$(letter "$b")
    ip link add "pcx-$la$lb" type veth peer name "pcx-$lb$la"
    ip link set "pcx-$la$lb" netns "$a"; ip link set "pcx-$lb$la" netns "$b"
    ip -n "$a" addr add "192.168.$x.1/30" dev "pcx-$la$lb"; ip -n "$a" link set "pcx-$la$lb" up
    ip -n "$b" addr add "192.168.$x.2/30" dev "pcx-$lb$la"; ip -n "$b" link set "pcx-$lb$la" up
    echo "피어링 연결: $a(pcx-$la$lb 192.168.$x.1) ↔ $b(pcx-$lb$la 192.168.$x.2) — 라우팅 표의 줄은 아직 없음";;
  *) sed -n '2,7p' "$0"; exit 1;;
esac
