# The component modules change nothing outside their component: a NixOS that
# enables all of them builds dbus, cairo, pango, pipewire, alsa-plugins and
# libtsm exactly as stock nixpkgs, and has no no-GUI rule. Evaluation only.
{ nixpkgs, componentModules, system }:
let
  stock = nixpkgs.legacyPackages.${system};
  sys = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = nixpkgs.lib.attrValues componentModules ++ [{
      services.tetron.enable = true;
      programs.tetron-tui.enable = true;
      programs.tetron-wm = { enable = true; desktop.enable = true; };
      services.tetron-console.enable = true;
      programs.casttui.enable = true;
      fileSystems."/" = { device = "/dev/null"; fsType = "ext4"; };
      boot.loader.grub.device = "nodev";
      system.stateVersion = "26.05";
    }];
  };
  names = [ "dbus" "cairo" "pango" "pipewire" "alsa-plugins" "libtsm" "kmscon" ];
  changed = builtins.filter (n: sys.pkgs.${n}.drvPath != stock.${n}.drvPath) names;
in
assert changed == [ ] || throw "component modules changed nixpkgs packages: ${toString changed}";
assert sys.config.system.forbiddenDependenciesRegexes == [ ] || throw "the no-GUI rule leaked into a component module";
stock.runCommand "tetron-gui-untouched" { } ''
  echo ${sys.config.system.build.toplevel.drvPath} > $out
''
