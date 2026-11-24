# programs.tetron-tui: the tetron terminal UI. Standalone.
flake:
{ config, lib, pkgs, ... }:
let cfg = config.programs.tetron-tui; in {
  options.programs.tetron-tui = {
    enable = lib.mkEnableOption "tetron-tui, the terminal UI for the tetron mesh";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.tetron-tui or flake.packages.${pkgs.stdenv.hostPlatform.system}.tetron-tui;
      defaultText = lib.literalExpression "pkgs.tetron-tui or tetron-nixos.packages.\${system}.tetron-tui";
      description = "The tetron-tui package.";
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
