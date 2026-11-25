#!/bin/sh
# Drive mounting on the live ISO (modules/storage.nix): the live user, no sudo,
# lists, mounts, writes, unmounts and ejects an exFAT USB stick with
# `tetron-wm drives` (the Files app's code) over ssh, which is not an active
# seat session. Nothing must be mounted before it asks.
#   vm/drives-iso.sh ISO OUTDIR      (port 2225)
set -u   # no -e: failing checks are counted, not fatal
iso=${1:?iso}; out=${2:?outdir}
port=${DRIVES_PORT:-2225}
mkdir -p "$out"
run=$(mktemp -d)
trap 'kill "$(cat "$run/pid" 2>/dev/null)" 2>/dev/null || true; rm -rf "$run"' EXIT
truncate -s 64M "$run/usb.raw"
printf 'label: gpt\n,\n' | sfdisk -q "$run/usb.raw"
truncate -s $((62 * 1024 * 1024)) "$run/p1"
mkfs.exfat -L STICK "$run/p1" >/dev/null
dd if="$run/p1" of="$run/usb.raw" bs=1M seek=1 conv=notrunc status=none
qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 2G -cdrom "$iso" -boot d -display none \
	-device qemu-xhci -drive "file=$run/usb.raw,format=raw,if=none,id=usb" -device usb-storage,drive=usb,removable=on,serial=USBSTICK \
	-serial "file:$out/serial-drives.log" -nic "user,hostfwd=tcp::$port-:22" -daemonize -pidfile "$run/pid"
ssh_() { sshpass -p tetronos ssh -p "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=3 -o PreferredAuthentications=password tetronos@127.0.0.1 "$@"; }
start=$(date +%s)
until ssh_ true 2>/dev/null; do
	[ $(( $(date +%s) - start )) -lt 180 ] || { echo "no ssh within 180 s"; exit 1; }
	sleep 2
done
fails=0
check() { if [ "$2" = 0 ]; then echo "PASS $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }
dev=$(ssh_ "lsblk -dno NAME,SERIAL | awk '\$2==\"USBSTICK\"{print \"/dev/\"\$1\"1\"}'")
ssh_ "findmnt -rn -o TARGET | grep -q '^/media/'"; [ $? -ne 0 ]; check "nothing mounted by itself" $?
ssh_ "tetron-wm drives" | tee "$out/drives-list.txt" | grep -q "STICK.*exfat.*rm"; check "the stick is listed" $?
ssh_ "tetron-wm drives mount $dev 2>&1; findmnt -rn -S $dev" > "$out/mount.txt" 2>&1
mp=$(head -1 "$out/mount.txt")
grep -q "^/run/media/tetronos/STICK " "$out/mount.txt"; check "mount without sudo, per user under /run/media (mount.txt)" $?
ssh_ "echo hi > '$mp/t' && grep -q hi '$mp/t'"; check "write to it" $?
ssh_ "tetron-wm drives unmount $dev"; check "unmount" $?
ssh_ "tetron-wm drives eject $dev"; check "eject (power off)" $?
sleep 2
ssh_ "tetron-wm drives" | grep -q STICK; [ $? -ne 0 ]; check "the ejected stick is gone" $?
echo "drives: $fails failed"
[ "$fails" = 0 ]
