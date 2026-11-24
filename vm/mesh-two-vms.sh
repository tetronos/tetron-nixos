#!/bin/sh
# Spike 0 mesh test (A7), fallback with internet: the hermetic nixosTest
# (tests/mesh.nix) cannot join, because tetron join resolves the network
# record through iroh's pkarr DNS (dns.iroh.link). Two live ISO VMs with user
# networking: A creates a network, B joins by invite, both ping over 10.88.x.
#   vm/mesh-two-vms.sh ISO OUTDIR
# Ports 2226 (A) and 2227 (B).
set -eu
iso=${1:?iso}; out=${2:?outdir}
mkdir -p "$out"
pids=""
trap 'for p in $pids; do kill "$p" 2>/dev/null || true; done' EXIT
boot() { # name port
	qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 2G -cdrom "$iso" -boot d \
		-vga std -display none -nic "user,hostfwd=tcp::$2-:22" \
		-serial "file:$out/serial-$1.log" -daemonize -pidfile "$out/$1.pid"
	pids="$pids $(cat "$out/$1.pid")"
}
on() { # port command
	p=$1; shift
	sshpass -p tetronos ssh -p "$p" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=3 -o PreferredAuthentications=password tetronos@127.0.0.1 "$@"
}
until_ok() { # seconds port command
	t=$(date +%s); s=$1; shift
	while [ $(( $(date +%s) - t )) -lt "$s" ]; do on "$@" >/dev/null 2>&1 && return 0; sleep 3; done
	return 1
}
boot a 2226; boot b 2227
daemon_up() { on "$1" 'tetron status --json' 2>/dev/null | jq -e .daemon_version >/dev/null 2>&1; }
for p in 2226 2227; do
	t=$(date +%s); until daemon_up $p; do [ $(( $(date +%s) - t )) -lt 240 ] || { echo "no daemon on port $p"; exit 1; }; sleep 3; done
done
echo "both daemons up"
start=$(date +%s)
on 2226 'sudo tetron create --network-name spike --hostname a' > "$out/create.txt" 2>&1
invite=$(on 2226 'sudo tetron invite spike create --json' | jq -r .invite_key)
[ -n "$invite" ] && [ "$invite" != null ] || { echo "no invite key"; cat "$out/create.txt"; exit 1; }
if ! printf '%s\n' "$invite" | on 2227 'sudo tetron join - --hostname b' > "$out/join.txt" 2>&1; then echo "join failed"; cat "$out/join.txt"; exit 1; fi
echo "joined after $(( $(date +%s) - start ))s"
ip='ip -4 -o addr show | awk "/ 10\\.88\\./{print \$4}" | cut -d/ -f1'
a_ip=""; b_ip=""
t=$(date +%s)
while [ $(( $(date +%s) - t )) -lt 120 ] && { [ -z "$a_ip" ] || [ -z "$b_ip" ]; }; do
	a_ip=$(on 2226 "$ip" 2>/dev/null || true); b_ip=$(on 2227 "$ip" 2>/dev/null || true); sleep 3
done
echo "mesh IPs: a=$a_ip b=$b_ip"
[ -n "$a_ip" ] && [ -n "$b_ip" ] || exit 1
until_ok 180 2226 "ping -c1 -W2 $b_ip" && echo "a -> b ping ok" || { echo "a -> b ping FAILED"; exit 1; }
until_ok 180 2227 "ping -c1 -W2 $a_ip" && echo "b -> a ping ok" || { echo "b -> a ping FAILED"; exit 1; }
on 2226 'ping -c5 -q '"$b_ip" | tail -1
on 2226 'tetron status' > "$out/status-a.txt" 2>&1 || true
on 2227 'tetron status' > "$out/status-b.txt" 2>&1 || true
cat "$out/status-a.txt"
echo "A7 mesh: PASS"
