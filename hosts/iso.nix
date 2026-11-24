# Spike 0 live ISO: server-like, console only. Live user tetronos, autologin.
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ "${modulesPath}/installer/cd-dvd/iso-image.nix" ];

  isoImage.makeEfiBootable = true;
  isoImage.makeUsbBootable = true;
  isoImage.squashfsCompression = "zstd -Xcompression-level 19";
  image.baseName = lib.mkForce "tetron-nixos-spike0";

  # Boot menu as on the Debian TetronOS ISO: the splash with the menu over
  # its lower half, entries "TetronOS live ...". GRUB (UEFI) uses the live
  # theme, syslinux (BIOS) the Debian stdmenu colors.
  system.nixos.label = "live";
  isoImage.appendToMenuLabel = "";
  isoImage.grubTheme = config.tetron-nixos.branding.theme;
  isoImage.efiSplashImage = "${config.tetron-nixos.branding.theme}/splash.png";
  isoImage.splashImage = "${config.tetron-nixos.branding.theme}/splash.png";
  isoImage.syslinuxTheme = ''
    MENU TITLE TetronOS
    MENU RESOLUTION 640 480
    MENU CLEAR
    MENU VSHIFT 12
    MENU ROWS 10
    MENU HELPMSGROW 15
    MENU CMDLINEROW 16
    MENU TIMEOUTROW 16
    MENU TABMSGROW 18
    MENU MARGIN 0
    MENU COLOR TITLE   * #FFFFFFFF *
    MENU COLOR BORDER  * #00000000 #00000000 none
    MENU COLOR SEL     * #ffffffff #c04caf50 *
    MENU COLOR HOTSEL  1;7;37;40 #ffffffff #c04caf50 *
    MENU COLOR TABMSG  * #ffffffff #00000000 *
    MENU COLOR HELP    37;40 #ffdddd00 #00000000 none
  '';

  networking.hostName = "tetron-nixos";
  # Spike only: sshd with password login from boot, for vm/boot-iso.sh and remote
  # checks. The base default is off (tetronos-ssh-temp turns it on).
  tetron-nixos.sshAtBoot = true;
  services.openssh.settings.PasswordAuthentication = true;

  # Spike only: Intel wifi for the ThinkPad P1. The policy (module default) is
  # the full Debian tetronos-firmware-wifi set.
  tetron-nixos.firmware.wifi = [ "iwlwifi-*" "intel/iwlwifi" ];

  users.users.tetronos = { isNormalUser = true; extraGroups = [ "wheel" "tetron" "video" "input" "networkmanager" ]; initialPassword = "tetronos"; };
  security.sudo.wheelNeedsPassword = false;
  services.getty.autologinUser = "tetronos";
  services.tetron.operator = "tetronos";

  documentation.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;
  environment.defaultPackages = [ ];

  system.stateVersion = "26.05";
}
