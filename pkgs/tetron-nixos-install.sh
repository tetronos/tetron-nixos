#!/bin/sh
# tetron-nixos-install INSTALL.JSON
# Installs tetron-nixos from one install.json (plan section 12, no TUI yet):
# writes the host flake, partitions with disko from it, runs nixos-install.
# The host flake stays on the machine at /etc/tetronos-config.
set -eu
die() { echo "tetron-nixos-install: $*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || exec sudo -- "$0" "$@"
json=${1:?usage: tetron-nixos-install INSTALL.JSON}
[ -r "$json" ] || die "cannot read $json"
src=/etc/tetron-nixos/source
[ -f "$src/flake.nix" ] || die "no tetron-nixos source at $src"

disk=$(jq -er .disk "$json") || die "install.json: disk missing"
host=$(jq -er .hostname "$json") || die "install.json: hostname missing"
jq -er '.user.name and .user.hashedPassword' "$json" >/dev/null || die "install.json: user.name and user.hashedPassword are required"
case $host in ''|*[!a-z0-9-]*) die "hostname: lowercase letters, digits and - only" ;; esac
[ -b "$disk" ] || die "$disk is not a block device"
dev=$(readlink -f "$disk")

# Never the medium this system runs from.
for m in /iso /nix/.ro-store; do
	s=$(findmnt -no SOURCE "$m" 2>/dev/null) || continue
	case $s in /dev/*) p=$(lsblk -no PKNAME "$s" 2>/dev/null); [ -n "$p" ] || p=${s#/dev/}
		[ "/dev/$p" = "$dev" ] || [ "$s" = "$dev" ] && die "$disk holds the running live system" ;;
	esac
done
mountpoint -q /mnt && die "/mnt is in use"

echo "Target: $disk ($(lsblk -dno MODEL,SERIAL,SIZE "$dev" | tr -s ' '))"
echo "Everything on it is erased."

cfg=$(mktemp -d /run/tetron-nixos-install.XXXXXX)
cp -rL "$src" "$cfg/tetron-nixos"
chmod -R u+w "$cfg/tetron-nixos"
cp "$json" "$cfg/install.json"
cat > "$cfg/flake.nix" <<EOF
{
  description = "tetron-nixos host $host";
  inputs.tetron-nixos.url = "path:./tetron-nixos";
  outputs = { tetron-nixos, ... }: {
    nixosConfigurations.$host = tetron-nixos.lib.mkHost {
      install = builtins.fromJSON (builtins.readFile ./install.json);
      hardware = ./hardware-configuration.nix;
    };
  };
}
EOF
nixos-generate-config --no-filesystems --show-hardware-config > "$cfg/hardware-configuration.nix"
git -C "$cfg" init -q
git -C "$cfg" add -A
git -C "$cfg" -c user.name=tetron-nixos-install -c user.email=install@tetron-nixos.invalid commit -qm "install $host"

disko --mode destroy,format,mount --yes-wipe-all-disks --flake "$cfg#$host"
mkdir -p /mnt/etc
cp -a "$cfg" /mnt/etc/tetronos-config
chmod 0755 /mnt/etc/tetronos-config
nixos-install --flake "/mnt/etc/tetronos-config#$host" --no-root-passwd --no-channel-copy
echo "Installed. The host config is /etc/tetronos-config (change it, then: nixos-rebuild switch --flake /etc/tetronos-config#$host)."
