#!/bin/sh
# tetron-wm on NixOS (WMNIX-001 to 008): boot the ISO, let tetron-wm start,
# then check that every tetron-wm path it wrote to disk (mc.ini clipboard
# commands, clipboard shims, user service unit) is a profile link and never
# a /nix/store path, that tetronos-ssh-temp is on PATH, and that console
# fonts are reachable through XDG_DATA_DIRS. Runs `clip setup-mc` and
# `service install` first so the files exist.
#   vm/wm-nix-paths.sh ISO OUTDIR
# Port 2229.
set -eu
iso=${1:?iso}; out=${2:?outdir}; port=2229
mkdir -p "$out"
run=$(mktemp -d)
trap 'kill "$(cat "$run/pid" 2>/dev/null)" 2>/dev/null || true; rm -rf "$run"' EXIT
qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 2G -cdrom "$iso" -boot d -vga std -display none \
	-monitor "unix:$run/mon,server,nowait" -nic "user,hostfwd=tcp::$port-:22" -daemonize -pidfile "$run/pid"
mon() { python3 -c 'import socket,sys,time; s=socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); time.sleep(0.3); s.recv(4096); s.sendall((sys.argv[2]+"\n").encode()); time.sleep(1); s.close()' "$run/mon" "$1"; }
on() { sshpass -p tetronos ssh -p "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=3 -o PreferredAuthentications=password tetronos@127.0.0.1 "$@"; }
t=$(date +%s); until on true 2>/dev/null; do [ $(( $(date +%s) - t )) -lt 180 ] || { echo "no ssh"; exit 1; }; sleep 2; done
sleep 15
mon "screendump $run/s.ppm"; convert "$run/s.ppm" "$out/screen-desktop.png"
on 'set -x
tetron-wm --version
tetron-wm --help | grep TETRON_WM_EXE
command -v tetronos-ssh-temp
echo "XDG_DATA_DIRS=$XDG_DATA_DIRS"
for d in $(echo "$XDG_DATA_DIRS" | tr : " "); do ls "$d/consolefonts" 2>/dev/null | head -2; done
tetron-wm clip setup-mc
tetron-wm service install
sleep 3
tetron-wm service status
grep -h "paths:\|packaging:\|clipboard: shims" ~/.local/state/tetron-wm/debug.log | tail -5
grep -h clipboard_ ~/.config/mc/ini 2>/dev/null
find ~/.local/share/tetron-wm ~/.local/state/tetron-wm ~/.local/bin -maxdepth 2 -type l -exec ls -l {} \; 2>/dev/null | cut -c40-
grep -rh ExecStart ~/.config/systemd/user 2>/dev/null' > "$out/checks.txt" 2>&1 || true
cat "$out/checks.txt"
bad=$(on 'grep -h "clipboard_" ~/.config/mc/ini 2>/dev/null; find ~/.local/share/tetron-wm ~/.local/state/tetron-wm ~/.local/bin -maxdepth 2 -type l -exec readlink {} \; 2>/dev/null; grep -rh ExecStart ~/.config/systemd/user 2>/dev/null' | grep /nix/store || true)
fail=0
[ -z "$bad" ] || { echo "FAIL: store paths written: $bad"; fail=1; }
grep -q 'clipboard_store=/run/current-system/sw/bin/tetron-wm clip' "$out/checks.txt" || { echo "FAIL: mc.ini lacks the profile path"; fail=1; }
grep -q 'ExecStart=/run/current-system/sw/bin/tetron-wm --apphost' "$out/checks.txt" || { echo "FAIL: unit lacks the profile path"; fail=1; }
grep -q '^/run/current-system/sw/bin/tetronos-ssh-temp' "$out/checks.txt" || { echo "FAIL: tetronos-ssh-temp not on PATH"; fail=1; }
grep -q TETRON_WM_EXE "$out/checks.txt" || { echo "FAIL: --help lacks TETRON_WM_EXE"; fail=1; }
[ "$fail" = 0 ] && echo "WMNIX paths: PASS"
exit "$fail"
