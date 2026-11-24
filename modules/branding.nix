# TetronOS branding, as on the Debian TetronOS: boot menu splash and theme,
# "TetronOS" as the distro name in boot entries and os-release (ID stays
# nixos), the login greeting of tetronos-branding.
{ config, lib, pkgs, ... }:
let
  cfg = config.tetron-nixos.branding;
in {
  options.tetron-nixos.branding = {
    edition = lib.mkOption { type = lib.types.str; default = "server"; description = "Edition name on the boot splash."; };
    theme = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "Boot theme directory: theme.txt, splash.png (640x480), unifont-16.pf2.";
    };
  };

  config = {
    tetron-nixos.branding.theme = pkgs.tetron-boot-theme {
      inherit (cfg) edition;
      base = "NixOS ${config.system.nixos.release}";
      arch = pkgs.stdenv.hostPlatform.uname.processor;
      kernel = config.boot.kernelPackages.kernel.version;
    };
    system.nixos.distroName = "TetronOS";
    services.getty.greetingLine = ''\e{lightgreen}TetronOS\e{reset} - The desktop for your terminal.'';
    services.getty.helpLine = lib.mkForce "";
  };
}
