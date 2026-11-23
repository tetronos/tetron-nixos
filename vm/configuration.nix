# Spike 0 dev VM: throwaway NixOS, flakes, sshd (key only), serial console.
# Bootstrapped by vm/bootstrap.py; rebuilt in place with nixos-rebuild.
{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "console=ttyS0,115200" ];

  networking.hostName = "spikevm";
  time.timeZone = "UTC";

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "dev" ];
    max-jobs = "auto";
    cores = 6;
  };

  users.users.dev = {
    isNormalUser = true;
    extraGroups = [ "wheel" "kvm" ];
    openssh.authorizedKeys.keys = [ "@SSHPUB@" ];
  };
  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings = { PasswordAuthentication = false; PermitRootLogin = "no"; };
  };

  environment.systemPackages = with pkgs; [ git curl vim jq tmux ];

  system.stateVersion = "26.05";
}
