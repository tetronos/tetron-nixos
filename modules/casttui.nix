# programs.casttui: cast media to a Chromecast from the terminal. Standalone.
flake:
{ config, lib, pkgs, ... }:
let cfg = config.programs.casttui; in {
  options.programs.casttui = {
    enable = lib.mkEnableOption "casttui, a terminal UI for casting to a Chromecast";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.casttui or flake.packages.${pkgs.stdenv.hostPlatform.system}.casttui;
      defaultText = lib.literalExpression "pkgs.casttui or tetron-nixos.packages.\${system}.casttui";
      description = "The casttui package.";
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Open TCP 45000 to 47000, the range catt picks the port for serving a
        local file to the Chromecast from (catt stream_info.py), so casting
        a file works with the firewall on. Desktop and cells casting use a
        random port and still need the firewall open for the Chromecast.
      '';
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    networking.firewall.allowedTCPPortRanges = lib.mkIf cfg.openFirewall [ { from = 45000; to = 47000; } ];
  };
}
