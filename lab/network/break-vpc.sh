#!/usr/bin/env bash
# 네트워킹 미션 1 "고장 난 사내망 고치기"(옛 미션 2) — 실습 3이 끝난 사내망(+ 9080 포트 포워딩)을 만들고, 층마다 고장을 하나씩 섞어 넣는다
#   층: 이름(DNS) · 길(경로·NAT) · 포트(입구 규칙) · 방화벽(서버 방화벽) · 앱(서버). 어느 고장이 걸렸는지는 알려 주지 않는다
#   고장은 모두 실습 1~4에서 직접 넣어 본 줄이 빠지거나 틀린 것이다
# 사용: sudo bash break-vpc.sh        — 무작위로 섞기
#       sudo bash break-vpc.sh 7      — 번호를 주면 같은 번호는 늘 같은 고장(다시 풀어 보기)
# 다 고쳤는지: bash vpc-check.sh   ·   처음부터: sudo bash break-vpc.sh   ·   지우기: sudo bash vpc-down.sh
set -e
[ "$(id -u)" = 0 ] || { echo "sudo로 실행하세요"; exit 1; }
D=$(dirname "$0")
bash "$D/vpc-up.sh" --routed >/dev/null
VM=$(hostname -I | cut -d' ' -f1)
iptables -t nat -A PREROUTING -d "$VM" -p tcp --dport 9080 -j DNAT --to-destination 10.0.1.10:80
iptables -t nat -A OUTPUT     -d "$VM" -p tcp --dport 9080 -j DNAT --to-destination 10.0.1.10:80
sleep 1
SEED=${1:-$(( $(date +%s%N) % 100000 ))}
R=$SEED
pick(){ R=$(( (R * 1103515245 + 12345) % 2147483648 )); P=$(( (R / 65536) % $1 )); }
X(){ ip netns exec "$@"; }
NAT_RULE="POSTROUTING -s 10.0.0.0/16 ! -d 10.0.0.0/16 -j MASQUERADE"
# 이름
pick 2; case $P in
  0) echo "nameserver 10.0.2.53" > /etc/netns/db/resolv.conf ;;
  1) echo "nameserver 10.0.1.1"  > /etc/netns/db/resolv.conf ;;
esac
# 길
pick 4; case $P in
  0) ip -n db route del default ;;
  1) ip -n rt route del default ;;
  2) ip route del 10.0.0.0/16 ;;
  3) iptables -t nat -D $NAT_RULE ;;
esac
# 포트 (9080 입구 규칙 두 줄이 틀림)
OK80="-d $VM -p tcp --dport 9080 -j DNAT --to-destination 10.0.1.10:80"
pick 2; case $P in
  0) for c in PREROUTING OUTPUT; do iptables -t nat -D $c $OK80; iptables -t nat -A $c -d "$VM" -p tcp --dport 9080 -j DNAT --to-destination 10.0.1.10:8080; done ;;
  1) for c in PREROUTING OUTPUT; do iptables -t nat -D $c $OK80; iptables -t nat -A $c -d "$VM" -p tcp --dport 9008 -j DNAT --to-destination 10.0.1.10:80; done ;;
esac
# 방화벽
# 서버 방화벽 고장 둘. 0번 = ESTABLISHED 줄 없음(미션 문서 "문제 번호 2 풀이"와 맞춘 순서)
pick 2; case $P in
  0) X db iptables -A INPUT -p tcp --dport 5432 -s 10.0.1.0/24 -j ACCEPT
     X db iptables -P INPUT DROP ;;
  1) X db iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
     X db iptables -A INPUT -p tcp --dport 5432 -s 10.0.3.0/24 -j ACCEPT
     X db iptables -P INPUT DROP ;;
esac
# 앱
pick 2; case $P in
  0) ip netns pids web | xargs -r kill ;;
  1) ip netns pids db  | xargs -r kill ;;
esac
echo "고장 난 VPC 준비 완료 (문제 번호 $SEED — 같은 문제를 다시 풀려면 sudo bash break-vpc.sh $SEED)"
echo "층마다(이름 · 길 · 포트 · 방화벽 · 앱) 고장이 하나씩 있습니다. 확인: bash vpc-check.sh"
