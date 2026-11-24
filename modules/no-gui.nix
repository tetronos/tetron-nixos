# No GUI in tetron-nixos: no X server, Wayland, Mesa, GTK or Qt, and no X client
# libraries in the system closure. The build fails if one is pulled in.
# Allowed on purpose: libdrm (kernel display interface kmscon draws through),
# libxkbcommon (keymaps), xkeyboard-config (keymap data), the X compose data
# copied into libxkbcommon-console.
{ config, lib, ... }:
{
  # su's pam_xauth forwards X credentials and pulls in xauth.
  security.pam.services.su.forwardXAuth = lib.mkForce false;

  system.forbiddenDependenciesRegexes = [
    "-libx11-[0-9]"
    "-libxcb-[0-9]"
    "-libxau-[0-9]"
    "-libxdmcp-[0-9]"
    "-libxext-[0-9]"
    "-libxrender-[0-9]"
    "-libxft-[0-9]"
    "-libxi-[0-9]"
    "-libxfixes-[0-9]"
    "-libxrandr-[0-9]"
    "-libxmu-[0-9]"
    "-xauth-[0-9]"
    "-xorg-server-"
    "-xwayland-"
    "-wayland-[0-9]"
    "-mesa-"
    "-libgbm-"
    "-libglvnd-"
    "-libGL-"
    "-llvm-"
    "-gtk[+]?[0-9]*-[0-9]"
    "-qtbase-"
  ];
}
