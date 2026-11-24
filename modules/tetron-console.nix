# services.tetron-console: kmscon on the VTs (touchpad tap patch), tetron-wm
# started by tetron-session on the primary console login (never over ssh,
# never nested), login shell fallback. Standalone; for a machine without a
# display manager. Turns on programs.tetron-wm.
flake:
{ config, lib, pkgs, ... }:
let
  cfg = config.services.tetron-console;
  tetron-session = pkgs.writeShellScriptBin "tetron-session" ''
    command -v tetron-wm >/dev/null 2>&1 || exec "''${SHELL:-/bin/sh}" -l
    export TETRON_WM_ACTIVE=1
    if tetron-wm ls 2>/dev/null | grep -qE ' (attached|detached) '; then
      tetron-wm attach -d
    else
      tetron-wm
    fi
    exec "''${SHELL:-/bin/sh}" -l
  '';
in {
  options.services.tetron-console = {
    enable = lib.mkEnableOption "the TetronOS console: kmscon on the VTs and tetron-wm on tty1";
    kmsconPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.kmscon-tetron or flake.packages.${pkgs.stdenv.hostPlatform.system}.kmscon;
      defaultText = lib.literalExpression "tetron-nixos.packages.\${system}.kmscon";
      description = "kmscon with the touchpad tap patch.";
    };
  };

  config = lib.mkIf cfg.enable {
  programs.tetron-wm.enable = true;
  services.kmscon = {
    enable = true;
    package = cfg.kmsconPackage;
    hwRender = false;
    fonts = [ { name = "DejaVu Sans Mono"; package = pkgs.dejavu_fonts; } ];
    term = "xterm-256color";
    extraConfig = ''
      mouse
      touchpad-tap
      xkb-layout=us
      font-size=14
    '';
  };
  console.packages = [ pkgs.terminus_font ];
  # Terminus in the system profile too: tetron-wm reads console fonts from
  # XDG_DATA_DIRS (/run/current-system/sw/share/consolefonts) for screenshots.
  environment.systemPackages = [ tetron-session pkgs.terminus_font ];
  environment.pathsToLink = [ "/share/consolefonts" ];

  # Start the desktop on a kmscon (or tty1) login only.
  environment.loginShellInit = ''
    if [ -z "$TETRON_WM_ACTIVE" ] && [ -z "$SSH_CONNECTION" ]; then
      _tw=0
      [ "$(tty)" = /dev/tty1 ] && _tw=1
      _p=$PPID
      while [ "$_tw" = 0 ] && [ "''${_p:-0}" -gt 1 ]; do
        [ "$(cat /proc/$_p/comm 2>/dev/null)" = kmscon ] && _tw=1
        _p=$(awk '/^PPid:/{print $2}' /proc/$_p/status 2>/dev/null)
      done
      [ "$_tw" = 1 ] && { unset _tw _p; exec ${tetron-session}/bin/tetron-session; }
      unset _tw _p
    fi
  '';
  };
}
