# An installed machine from install.json (plan section 12). The JSON is the
# whole input; everything else is the shared modules.
install:
{ config, lib, ... }:
let
  user = install.user;
  sshAtBoot = install.ssh_at_boot or false;
in {
  disko.devices.disk.main = {
    type = "disk";
    device = install.disk;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = { type = "filesystem"; format = "vfat"; mountpoint = "/boot"; mountOptions = [ "umask=0077" ]; };
        };
        root = {
          size = "100%";
          content = { type = "filesystem"; format = "ext4"; mountpoint = "/"; };
        };
      };
    };
  };

  # GRUB, as on the Debian TetronOS, so the installed menu has the same
  # splash and theme as the live ISO; generations appear as menu entries.
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
    theme = config.tetron-nixos.branding.theme;
    splashImage = "${config.tetron-nixos.branding.theme}/splash.png";
  };
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = install.hostname;
  users.users.${user.name} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "tetron" "video" "input" "networkmanager" "audio" ];
    hashedPassword = user.hashedPassword;
  };

  services.tetron.operator = user.name;
  tetron-nixos.sshAtBoot = sshAtBoot;
  services.openssh.settings.PasswordAuthentication = lib.mkIf sshAtBoot true;
  tetron-nixos.firmware.wifi = lib.mkIf (install ? wifi_firmware) install.wifi_firmware;

  system.stateVersion = "26.05";
}
