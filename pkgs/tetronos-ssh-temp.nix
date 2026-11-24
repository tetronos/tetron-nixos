# tetronos-ssh-temp from the Debian TetronOS (tetron-os packaging/files/tetronos-base-config),
# with the Debian paths and names swapped for NixOS ones. --replace-fail stops the build
# when the upstream script changes, so a swap is never silently skipped.
{ lib, stdenvNoCC, src, openssh }:

stdenvNoCC.mkDerivation {
  pname = "tetronos-ssh-temp";
  version = "0.15.0";
  inherit src;
  dontBuild = true;
  installPhase = ''
    install -Dm755 packaging/files/tetronos-base-config/tetronos-ssh-temp $out/bin/tetronos-ssh-temp
    substituteInPlace $out/bin/tetronos-ssh-temp \
      --replace-fail '[ -x /usr/sbin/sshd ] || die "openssh-server is not installed (sudo apt install openssh-server)"' \
                     '[ -x ${openssh}/bin/sshd ] || die "sshd is missing"' \
      --replace-fail '/usr/sbin/sshd -t' '${openssh}/bin/sshd -t' \
      --replace-fail 'ssh.service' 'sshd.service' \
      --replace-fail '[ -x /usr/bin/sudo ] && getent group sudo' '[ -x /run/wrappers/bin/sudo ] && getent group wheel' \
      --replace-fail 'usermod -aG sudo' 'usermod -aG wheel' \
      --replace-fail 'could not add $user to the sudo group' 'could not add $user to the wheel group' \
      --replace-fail "grep -qx sudo" "grep -qx wheel" \
      --replace-fail 'useradd -m -s /bin/bash' 'useradd -m -s /run/current-system/sw/bin/bash'
    patchShebangs $out/bin
  '';
  meta = { mainProgram = "tetronos-ssh-temp"; platforms = lib.platforms.linux; };
}
