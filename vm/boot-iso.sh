#!/bin/sh
# Spike 0 boot test (A4, A5): boot an ISO under QEMU/KVM in BIOS or UEFI mode,
# headless, time until ssh answers, take screen captures of the VT, run the
# console and daemon checks over ssh, stop the VM.
#   vm/boot-iso.sh ISO bios|uefi OUTDIR
# Live login: tetronos / tetronos (hosts/iso.nix). Port 2224, never 2222/2223.
set -eu
iso=${1:?iso}; mode=${2:?bios|uefi}; out=${3:?outdir}
port=${BOOT_PORT:-2224}
mkdir -p "$out"
run=$(mktemp -d)
trap 'kill "$(cat "$run/pid" 2>/dev/null)" 2>/dev/null || true; rm -rf "$run"' EXIT
fw=""
if [ "$mode" = uefi ]; then
	cp /usr/share/OVMF/OVMF_VARS_4M.fd "$run/vars.fd"
	fw="-drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd -drive if=pflash,format=raw,file=$run/vars.fd"
fi
# shellcheck disable=SC2086
qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 2G $fw \
	-cdrom "$iso" -boot d -vga std -display none \
	-monitor "unix:$run/mon,server,nowait" -serial "file:$out/serial-$mode.log" \
	-nic "user,hostfwd=tcp::$port-:22" -daemonize -pidfile "$run/pid"
start=$(date +%s)
mon() { python3 -c 'import socket,sys,time; s=socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); time.sleep(0.3); s.recv(4096); s.sendall((sys.argv[2]+"\n").encode()); time.sleep(1); s.close()' "$run/mon" "$1"; }
shot() { mon "screendump $run/s.ppm"; convert "$run/s.ppm" "$out/screen-$mode-$1.png"; }
ssh_() { sshpass -p tetronos ssh -p "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=3 -o PreferredAuthentications=password tetronos@127.0.0.1 "$@"; }
up=""
while [ $(( $(date +%s) - start )) -lt 180 ]; do
	if ssh_ true 2>/dev/null; then up=$(( $(date +%s) - start )); break; fi
	sleep 2
done
[ -n "$up" ] || { shot timeout; echo "$mode: no ssh within 180 s"; exit 1; }
echo "$mode: ssh answered after ${up}s"
sleep 5
shot booted
ssh_ 'set -x
systemd-analyze 2>/dev/null | head -2
systemctl is-active kmsconvt@tty1 getty@tty1 tetron 2>&1
ps -eo comm,args | grep -E "^(kmscon|tetron-wm|agetty)" | cut -c1-120
tetron --version; tetron status 2>&1 | head -5
id; getent group tetron
ls -l /run/current-system/sw/bin/tetron-wm /run/current-system/sw/bin/kmscon
free -m | sed -n 2p; df -h / /nix/store 2>/dev/null | tail -2' > "$out/checks-$mode.txt" 2>&1 || true
cat "$out/checks-$mode.txt"
