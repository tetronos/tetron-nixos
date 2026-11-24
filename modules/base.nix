# Base of every edition, the Nix side of the Debian tetronos-base-config:
# home folders, flakes, and temporary ssh access (tetronos-ssh-temp).
{ config, lib, pkgs, ... }:
let
  cfg = config.tetron-nixos;
  homeDirs = [ "Desktop" "Documents" "Downloads" "Pictures" "code" ];
  normalUsers = lib.filter (u: u.isNormalUser) (lib.attrValues config.users.users);
in {
  options.tetron-nixos.sshAtBoot = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Start sshd at boot. Off: sshd runs only while tetronos-ssh-temp is on.";
  };

  config = {
    # The folders the tetron-wm Files app expects, and ~/code. /etc/skel covers
    # accounts made with useradd (tetronos-ssh-temp); declared users get them
    # from tmpfiles, without touching anything already there.
    systemd.tmpfiles.rules =
      map (d: "d /etc/skel/${d} 0755 root root -") homeDirs
      ++ lib.concatMap (u: map (d: "d ${u.home}/${d} 0755 ${u.name} ${u.group} -") homeDirs) normalUsers;

    # nix shell nixpkgs#x and nix-shell -p x both work out of the box.
    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    # Temporary password login over ssh (tetronos-ssh-temp on|off|status|cleanup).
    # sshd is installed; password login is off for everyone except the one account
    # the helper names in its Match block, read through the Include below.
    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = lib.mkDefault false;
      settings.KbdInteractiveAuthentication = false;
      extraConfig = lib.mkAfter "Include /etc/ssh/sshd_config.d/*.conf";
    };
    # PAM must check passwords, or the Match block's PasswordAuthentication yes
    # has nothing to check against (NixOS ties unixAuth to the global setting).
    security.pam.services.sshd.unixAuth = lib.mkForce true;
    systemd.services.sshd.wantedBy = lib.mkIf (!cfg.sshAtBoot) (lib.mkForce [ ]);
    systemd.tmpfiles.settings."10-ssh-temp"."/etc/ssh/sshd_config.d".d = { mode = "0755"; };
    # git: the host config (/etc/tetronos-config) is a git repository.
    environment.systemPackages = [ pkgs.tetronos-ssh-temp pkgs.git ];
    systemd.services.tetronos-ssh-temp-cleanup = {
      description = "TetronOS: end a temporary ssh login left over from before this boot";
      unitConfig.ConditionPathExists = "/var/lib/tetronos/ssh-temp/state";
      before = [ "sshd.service" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [ shadow procps systemd iproute2 gnused gawk coreutils ];
      serviceConfig = { Type = "oneshot"; ExecStart = "${lib.getExe pkgs.tetronos-ssh-temp} cleanup"; TimeoutStartSec = 30; };
    };
  };
}
