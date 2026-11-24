# Console stack: kmscon on the VTs, tetron-wm started by tetron-session on the
# primary console login (never over ssh, never nested), login shell fallback.
{ config, lib, pkgs, ... }:
let
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
  services.kmscon = {
    enable = true;
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
  environment.systemPackages = [ pkgs.tetron-wm tetron-session ];

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
}
