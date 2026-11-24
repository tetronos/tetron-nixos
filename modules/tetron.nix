# tetron daemon as a declared service: no `tetron install`, no unit under /etc.
{ config, lib, pkgs, ... }:
let
  env = { TETRON_CONFIG_DIR = "/var/lib/tetron"; TETRON_LOG_DIR = "/var/log/tetron"; };
  operator = config.tetron-nixos.tetron.operator;
in {
  options.tetron-nixos.tetron.operator = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "tetronos";
    description = ''
      The user who controls tetron without sudo (tetron set-operator), set at
      every boot. The Debian TetronOS does this once in tetronos-firstboot.
    '';
  };

  config = {
  boot.kernelModules = [ "tun" ];
  users.groups.tetron = { };
  environment.systemPackages = [ pkgs.tetron pkgs.tetron-tui ];
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
      ExecStart = "${pkgs.tetron}/bin/tetron daemon";
      Restart = "on-failure";
      RestartSec = 5;
      StateDirectory = "tetron";
      LogsDirectory = "tetron";
    };
  };

  systemd.services.tetron-operator = lib.mkIf (operator != null) {
    description = "tetron: make ${operator} the operator";
    after = [ "tetron.service" ];
    requires = [ "tetron.service" ];
    wantedBy = [ "multi-user.target" ];
    environment = env;
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    # The daemon can answer status before it accepts set-operator: retry (as tetronos-firstboot).
    script = ''
      i=0
      until ${pkgs.tetron}/bin/tetron set-operator ${lib.escapeShellArg operator}; do
        i=$((i + 1))
        [ "$i" -lt 30 ] || { echo "set-operator ${operator} failed"; exit 1; }
        sleep 2
      done
    '';
  };
  };
}
