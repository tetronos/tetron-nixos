# programs.tetron-wm: the terminal desktop. Standalone: works in any terminal
# on any NixOS (a desktop machine runs it in its terminal emulator);
# services.tetron-console adds the console session.
flake:
{ config, lib, pkgs, ... }:
let cfg = config.programs.tetron-wm; in {
  options.programs.tetron-wm = {
    enable = lib.mkEnableOption "tetron-wm, the desktop for your terminal";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.tetron-wm or flake.packages.${pkgs.stdenv.hostPlatform.system}.tetron-wm;
      defaultText = lib.literalExpression "pkgs.tetron-wm or tetron-nixos.packages.\${system}.tetron-wm";
      description = "The tetron-wm package.";
    };
    desktop.enable = lib.mkEnableOption ''
      the tools tetron-wm uses, as the Debian tetron-wm-desktop package:
      the Nerd Font symbols, DejaVu Sans Mono and mc'';
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ] ++ lib.optionals cfg.desktop.enable [ pkgs.mc ];
    fonts.packages = lib.mkIf cfg.desktop.enable [ pkgs.nerd-fonts.symbols-only pkgs.dejavu_fonts ];
  };
}
