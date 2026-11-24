#!/bin/sh
# Spike 0 (A5, last part): when tetron-wm ends (Quit or a crash), the console
# falls back to a login shell and tetron-wm is not started again (no loop).
# Boots the ISO, ends every tetron-wm process, checks the tty1 session.
#   vm/quit-fallback.sh ISO OUTDIR
# Port 2228.
set -eu
iso=${1:?iso}; out=${2:?outdir}; port=2228
mkdir -p "$out"
run=$(mktemp -d)
trap 'kill "$(cat "$run/pid" 2>/dev/null)" 2>/dev/null || true; rm -rf "$run"' EXIT
qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 2G -cdrom "$iso" -boot d -vga std -display none \
	-monitor "unix:$run/mon,server,nowait" -nic "user,hostfwd=tcp::$port-:22" -daemonize -pidfile "$run/pid"
mon() { python3 -c 'import socket,sys,time; s=socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); time.sleep(0.3); s.recv(4096); s.sendall((sys.argv[2]+"\n").encode()); time.sleep(1); s.close()' "$run/mon" "$1"; }
shot() { mon "screendump $run/s.ppm"; convert "$run/s.ppm" "$out/screen-$1.png"; }
on() { sshpass -p tetronos ssh -p "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=3 -o PreferredAuthentications=password tetronos@127.0.0.1 "$@"; }
t=$(date +%s); until on true 2>/dev/null; do [ $(( $(date +%s) - t )) -lt 180 ] || { echo "no ssh"; exit 1; }; sleep 2; done
sleep 8
tree='ps -eo pid,ppid,tty,args --forest | grep -E "kmscon|login|bash|tetron-wm|tetron-session" | grep -v grep | cut -c1-140'
on "$tree" > "$out/before.txt"; shot before
on 'pgrep -f "[t]etron-wm-wrapped" | xargs -r kill' || true
sleep 6
on "$tree" > "$out/after.txt"; shot after
cat "$out/before.txt"; echo ---; cat "$out/after.txt"
if on 'pgrep -f "[t]etron-wm-wrapped" >/dev/null'; then echo "A5 fallback: FAIL (tetron-wm running again)"; exit 1; fi
if on 'for p in $(pgrep -x bash); do t=$(ps -o tty= -p $p); case $t in pts/*) pp=$(ps -o ppid= -p $p | tr -d " "); while [ "${pp:-1}" -gt 1 ]; do [ "$(cat /proc/$pp/comm)" = kmscon ] && exit 0; pp=$(ps -o ppid= -p $pp | tr -d " "); done;; esac; done; exit 1'; then
	echo "A5 fallback: PASS (a shell under kmscon, no tetron-wm)"
else
	echo "A5 fallback: FAIL (no shell under kmscon)"; exit 1
fi
