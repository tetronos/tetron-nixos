#!/bin/sh
# Spike 0 dev VM: start|stop|status|ssh [cmd...]|sync   (headless, serial in build/vm/serial.log)
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V="$ROOT/build/vm"; PORT="${VM_PORT:-2223}"
SSH="ssh -i $V/id_ed25519 -p $PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5 dev@127.0.0.1"
case "$1" in
start) [ ! -f "$V/qemu.pid" ] || ! kill -0 "$(cat $V/qemu.pid)" 2>/dev/null || { echo running; exit 0; }
  qemu-system-x86_64 -enable-kvm -cpu host -smp 8 -m 16G -display none -serial "file:$V/serial.log" \
   -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd -drive if=pflash,format=raw,file="$V/OVMF_VARS.fd" \
   -drive file="$V/disk.qcow2",if=virtio,format=qcow2 -nic user,hostfwd=tcp::$PORT-:22 -daemonize -pidfile "$V/qemu.pid" ;;
stop) $SSH sudo poweroff 2>/dev/null || true ;;
status) [ -f "$V/qemu.pid" ] && kill -0 "$(cat $V/qemu.pid)" 2>/dev/null && echo "up pid $(cat $V/qemu.pid)" || echo down ;;
ssh) shift; $SSH "$@" ;;
sync) rsync -a --delete -e "ssh -i $V/id_ed25519 -p $PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR" --exclude build --exclude DO-NOT-COMMIT --exclude .git --exclude logs --exclude "result*" "$ROOT/" dev@127.0.0.1:tetron-nixos/ ;;
*) echo "usage: vm.sh start|stop|status|ssh [cmd]|sync"; exit 2 ;;
esac
