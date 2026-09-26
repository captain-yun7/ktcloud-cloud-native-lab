#!/usr/bin/env bash
# 10-28·10-29 네트워킹 실습 정리 — 네임스페이스, VM 쪽 선, 이 실습이 넣은 iptables 규칙을 지운다
[ "$(id -u)" = 0 ] || { echo "sudo로 실행하세요"; exit 1; }
docker rm -f lab-lb >/dev/null 2>&1
for n in rt web db cache web-b; do ip netns pids $n 2>/dev/null | xargs -r kill 2>/dev/null; ip netns del $n 2>/dev/null; done
ip link del igw 2>/dev/null
for t in "DOCKER-USER -s 10.0.0.0/16 -j ACCEPT" "DOCKER-USER -d 10.0.0.0/16 -j ACCEPT"; do while iptables -D $t 2>/dev/null; do :; done; done
iptables -t nat -S | grep -E "(^| )10\.0\.[0-9]+\.[0-9]+" | sed 's/^-A/-D/' | while read -r r; do iptables -t nat $r; done
ip route del 10.0.0.0/16 2>/dev/null
rm -rf /etc/netns/web /etc/netns/db /etc/netns/cache /etc/netns/web-b /tmp/vpc-*
echo "정리 완료"
