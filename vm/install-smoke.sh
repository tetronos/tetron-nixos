#!/bin/sh
# Spike 0 install smoke test (A9): boot the ISO (UEFI) with an empty disk,
# install from tests/install/smoke.json with tetron-nixos-install, power off,
# boot the installed disk alone, check login, daemon and console.
#   vm/install-smoke.sh ISO OUTDIR
# Port 2225. OUTDIR keeps the disk, the UEFI vars and every log.
set -eu
iso=${1:?iso}; out=${2:?outdir}
port=${SMOKE_PORT:-2225}
[ ! -e "$out/disk.qcow2" ] || { echo "$out/disk.qcow2 exists; use a new OUTDIR"; exit 1; }
mkdir -p "$out"
qemu-img create -q -f qcow2 "$out/disk.qcow2" 20G
cp /usr/share/OVMF/OVMF_VARS_4M.fd "$out/vars.fd"
pid="$out/qemu.pid"
trap 'kill "$(cat "$pid" 2>/dev/null)" 2>/dev/null || true' EXIT
run() { # extra qemu args
	# shellcheck disable=SC2068
	qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 6G \
		-drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
		-drive if=pflash,format=raw,file="$out/vars.fd" \
		-drive file="$out/disk.qcow2",if=none,id=d0 -device virtio-blk-pci,drive=d0,serial=tetron-smoke \
		-vga std -display none -nic "user,hostfwd=tcp::$port-:22" \
		-serial "file:$out/serial-$1.log" -daemonize -pidfile "$pid" $2
}
ssh_() { sshpass -p tetronos ssh -p "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=3 -o PreferredAuthentications=password tetronos@127.0.0.1 "$@"; }
wait_ssh() {
	t=$(date +%s)
	while [ $(( $(date +%s) - t )) -lt 240 ]; do ssh_ true 2>/dev/null && { echo "$1: ssh after $(( $(date +%s) - t ))s"; return 0; }; sleep 3; done
	echo "$1: no ssh within 240 s"; return 1
}
stop() { ssh_ 'sudo systemctl poweroff' 2>/dev/null || true; t=0; while kill -0 "$(cat "$pid")" 2>/dev/null && [ $t -lt 60 ]; do sleep 2; t=$((t+2)); done; kill "$(cat "$pid")" 2>/dev/null || true; }

run live "-cdrom $iso -boot d"
wait_ssh live
sshpass -p tetronos scp -P "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR tests/install/smoke.json tetronos@127.0.0.1:smoke.json
start=$(date +%s)
if ssh_ 'sudo tetron-nixos-install smoke.json' > "$out/install.log" 2>&1; then echo "install: ok in $(( $(date +%s) - start ))s"; else echo "install: FAILED, see $out/install.log"; tail -30 "$out/install.log"; exit 1; fi
stop

run installed ""
wait_ssh installed
ssh_ 'set -x
hostname; id
systemctl is-active tetron kmsconvt@tty1 2>&1
tetron --version; tetron-wm --version 2>&1 | head -1; tetron-tui --version
ls ~
bootctl status 2>/dev/null | grep -E "Product|Current Boot|Default Boot" | head -4
findmnt -no SOURCE,FSTYPE / /boot
ls /etc/tetronos-config; git -C /etc/tetronos-config log --oneline
nixos-rebuild list-generations 2>/dev/null | head -3
systemd-analyze 2>/dev/null | head -1
df -h / | tail -1' > "$out/checks.txt" 2>&1 || true
cat "$out/checks.txt"
stop
