# Spike 0 live ISO: server-like, console only. Live user tetronos, autologin.
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ "${modulesPath}/installer/cd-dvd/iso-image.nix" ];

  isoImage.makeEfiBootable = true;
  isoImage.makeUsbBootable = true;
  isoImage.squashfsCompression = "zstd -Xcompression-level 19";
  image.baseName = lib.mkForce "tetron-nixos-spike0";

  networking.hostName = "tetron-nixos";
  services.openssh.enable = true;

  # Spike only: Intel wifi for the ThinkPad P1. The policy (module default) is
  # the full Debian tetronos-firmware-wifi set.
  tetron-nixos.firmware.wifi = [ "iwlwifi-*" "intel/iwlwifi" ];

  users.users.tetronos = { isNormalUser = true; extraGroups = [ "wheel" "tetron" "video" "input" "networkmanager" ]; initialPassword = "tetronos"; };
  security.sudo.wheelNeedsPassword = false;
  services.getty.autologinUser = "tetronos";

  documentation.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;
  environment.defaultPackages = [ ];

  system.stateVersion = "26.05";
}
