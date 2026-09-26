#!/usr/bin/env bash
# 10-28 오후: VM 안에 "빈 VPC"(10.0.0.0/16)를 만든다 — 네임스페이스·선·주소까지만. 라우팅·NAT·보안그룹은 수업에서 직접 넣는다
#   rt  = VPC 라우터            web = 퍼블릭 서브넷 10.0.1.0/24의 서버 (10.0.1.10)
#   db  = 프라이빗 서브넷 10.0.2.0/24의 서버 (10.0.2.10)
#   VM 자신 = 인터넷 게이트웨이 (rt와 10.0.255.0/30으로 연결)
# 사용: sudo bash vpc-up.sh            — 10-28 오후 시작 (빈 VPC)
#       sudo bash vpc-up.sh --routed   — 10-29 오전 시작 (10-28 실습 1·2까지 끝난 상태: 라우팅·NAT·web/db 서버)
# 지우기: sudo bash vpc-down.sh
set -e
[ "$(id -u)" = 0 ] || { echo "sudo로 실행하세요"; exit 1; }
bash "$(dirname "$0")/vpc-down.sh" >/dev/null 2>&1 || true
for n in rt web db; do ip netns add $n; ip -n $n link set lo up; done
link(){ ip link add $1 type veth peer name $3; ip link set $1 netns $2; [ "$4" = host ] || ip link set $3 netns $4; }
link rt-web rt web0 web
link rt-db  rt db0  db
link rt-igw rt igw  host
ip -n rt  addr add 10.0.1.1/24   dev rt-web;  ip -n rt link set rt-web up
ip -n rt  addr add 10.0.2.1/24   dev rt-db;   ip -n rt link set rt-db up
ip -n rt  addr add 10.0.255.2/30 dev rt-igw;  ip -n rt link set rt-igw up
ip -n web addr add 10.0.1.10/24  dev web0;    ip -n web link set web0 up
ip -n db  addr add 10.0.2.10/24  dev db0;     ip -n db link set db0 up
ip addr add 10.0.255.1/30 dev igw; ip link set igw up
ip netns exec rt sysctl -qw net.ipv4.ip_forward=1
# netns 안의 이름 풀이 (VM의 127.0.0.53은 네임스페이스 안에서 안 보인다)
for n in web db; do mkdir -p /etc/netns/$n; echo "nameserver 8.8.8.8" > /etc/netns/$n/resolv.conf; done
# Docker가 VM의 FORWARD를 기본 차단(DROP)해 둔다 → VPC 대역만 통과 허용 (Docker 권장 위치 DOCKER-USER)
iptables -C DOCKER-USER -s 10.0.0.0/16 -j ACCEPT 2>/dev/null || iptables -I DOCKER-USER -s 10.0.0.0/16 -j ACCEPT
iptables -C DOCKER-USER -d 10.0.0.0/16 -j ACCEPT 2>/dev/null || iptables -I DOCKER-USER -d 10.0.0.0/16 -j ACCEPT
if [ "$1" = "--routed" ]; then
  ip -n web route add default via 10.0.1.1
  ip -n db route add default via 10.0.2.1
  ip -n rt route add default via 10.0.255.1
  ip route add 10.0.0.0/16 via 10.0.255.2
  iptables -t nat -A POSTROUTING -s 10.0.0.0/16 ! -d 10.0.0.0/16 -j MASQUERADE
  serve(){ mkdir -p /tmp/vpc-$1 && echo "$1 $2" > /tmp/vpc-$1/index.html
    ip netns exec $1 sh -c "cd /tmp/vpc-$1 && nohup python3 -m http.server $3 >/dev/null 2>&1 &"; }
  serve web 10.0.1.10 80; serve db 10.0.2.10 5432
  echo "라우팅·NAT·서버까지 준비 완료:"
else
  echo "빈 VPC 준비 완료:"
fi
ip netns list
