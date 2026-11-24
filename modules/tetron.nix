# services.tetron: the tetron mesh daemon as a declared service (no `tetron
# install`, no unit under /etc). Standalone: usable on any NixOS without the
# rest of tetron-nixos. `flake` is this flake (package default).
flake:
{ config, lib, pkgs, ... }:
let
  cfg = config.services.tetron;
  env = { TETRON_CONFIG_DIR = "/var/lib/tetron"; TETRON_LOG_DIR = "/var/log/tetron"; };
in {
  imports = [
    (lib.mkRenamedOptionModule [ "tetron-nixos" "tetron" "operator" ] [ "services" "tetron" "operator" ])
  ];

  options.services.tetron = {
    enable = lib.mkEnableOption "the tetron P2P mesh VPN daemon";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.tetron or flake.packages.${pkgs.stdenv.hostPlatform.system}.tetron;
      defaultText = lib.literalExpression "pkgs.tetron or tetron-nixos.packages.\${system}.tetron";
      description = "The tetron package (daemon and CLI).";
    };
    operator = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "alice";
      description = ''
        The user who controls tetron without sudo (tetron set-operator), set at
        every boot. The Debian TetronOS does this once in tetronos-firstboot.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "tun" ];
    users.groups.tetron = { };
    environment.systemPackages = [ cfg.package ];
    # The CLI must see the same paths as the daemon.
    environment.variables = env;

    systemd.services.tetron = {
      description = "tetron P2P mesh VPN";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.iproute2 ];
      environment = env;
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/tetron daemon";
        Restart = "on-failure";
        RestartSec = 5;
        StateDirectory = "tetron";
        LogsDirectory = "tetron";
      };
    };

    systemd.services.tetron-operator = lib.mkIf (cfg.operator != null) {
      description = "tetron: make ${cfg.operator} the operator";
      after = [ "tetron.service" ];
      requires = [ "tetron.service" ];
      wantedBy = [ "multi-user.target" ];
      environment = env;
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
      # The daemon can answer status before it accepts set-operator: retry (as tetronos-firstboot).
      script = ''
        i=0
        until ${cfg.package}/bin/tetron set-operator ${lib.escapeShellArg cfg.operator}; do
          i=$((i + 1))
          [ "$i" -lt 30 ] || { echo "set-operator ${cfg.operator} failed"; exit 1; }
          sleep 2
        done
      '';
    };
  };
}
