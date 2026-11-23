# Spike 0 live ISO: server-like, console only. Live user tetronos, autologin.
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ "${modulesPath}/installer/cd-dvd/iso-image.nix" ];

  isoImage.makeEfiBootable = true;
  isoImage.makeUsbBootable = true;
  isoImage.squashfsCompression = "zstd -Xcompression-level 19";
  image.baseName = lib.mkForce "tetronixos-spike0";

  networking.hostName = "tetronixos";
  networking.networkmanager.enable = false;
  services.openssh.enable = true;

  users.users.tetronos = { isNormalUser = true; extraGroups = [ "wheel" "tetron" "video" "input" ]; initialPassword = "tetronos"; };
  security.sudo.wheelNeedsPassword = false;
  services.getty.autologinUser = "tetronos";

  documentation.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;
  environment.defaultPackages = [ ];

  system.stateVersion = "26.05";
}
