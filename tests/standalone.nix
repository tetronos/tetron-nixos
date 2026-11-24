# Each suite component alone on a plain NixOS: stock nixpkgs, no tetron-nixos
# overlay, base or no-GUI rule. The node imports only the component modules
# and turns on the daemon, tetron-tui, tetron-wm and casttui (not the console: a test
# VM keeps its serial console).
{ pkgs, componentModules }:
pkgs.testers.runNixOSTest {
  name = "tetron-standalone";
  nodes.plain = { pkgs, ... }: {
    imports = [ componentModules.tetron componentModules.tetron-tui componentModules.tetron-wm componentModules.casttui ];
    services.tetron = { enable = true; operator = "alice"; };
    programs.tetron-tui.enable = true;
    programs.tetron-wm = { enable = true; desktop.enable = true; };
    programs.casttui = { enable = true; openFirewall = true; };
    users.users.alice = { isNormalUser = true; extraGroups = [ "tetron" ]; };
    environment.systemPackages = [ pkgs.jq ];
  };
  testScript = ''
    plain.wait_for_unit("tetron.service")
    plain.wait_until_succeeds("tetron status --json | jq -e .daemon_version", timeout=60)
    plain.wait_for_unit("tetron-operator.service")
    plain.succeed("tetron-tui --version >&2")
    plain.succeed("tetron-wm --version >&2")
    plain.succeed("fc-list | grep -q 'Symbols Nerd Font'")
    plain.succeed("command -v mc")
    plain.succeed("casttui --help >&2")
    plain.succeed("iptables -S | grep -q -- '--dport 45000:47000'")
    # tetron-wm writes the profile path, never the store path (WMNIX-003).
    plain.succeed("su - alice -c 'tetron-wm clip setup-mc' >&2")
    plain.succeed("grep -q 'clipboard_store=/run/current-system/sw/bin/tetron-wm clip' /home/alice/.config/mc/ini")
  '';
}
