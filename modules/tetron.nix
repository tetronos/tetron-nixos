# tetron daemon as a declared service: no `tetron install`, no unit under /etc.
{ config, lib, pkgs, ... }:
let
  env = { TETRON_CONFIG_DIR = "/var/lib/tetron"; TETRON_LOG_DIR = "/var/log/tetron"; };
in {
  boot.kernelModules = [ "tun" ];
  users.groups.tetron = { };
  environment.systemPackages = [ pkgs.tetron ];
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
}
