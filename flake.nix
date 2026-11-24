{
  description = "tetron-nixos: the NixOS flavour of TetronOS (spike 0)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    tetron-src = { url = "github:tetronos/tetron/v0.15.6"; flake = false; };
    tetron-wm-src = { url = "github:tetronos/tetron-wm/v0.15.22"; flake = false; };
    # Same kmscon as the Debian TetronOS (10.0.4); nixpkgs 26.05 ships 9.3.5,
    # which the touchpad patch does not fit (src/config.c and friends differ).
    kmscon-src = { url = "github:kmscon/kmscon/v10.0.4"; flake = false; };
    # kmscon 10.0.4 needs libtsm >= 4.8.0 (its wrap file pins v4.8.0); nixpkgs has 4.5.0.
    libtsm-src = { url = "github:kmscon/libtsm/v4.8.0"; flake = false; };
    # The tetron-catalog git crate include_str!s ../../../assets/catalog.json, a file
    # outside the crate, so cargo vendoring drops it. Pinned to the rev in the
    # tetron-wm v0.15.22 Cargo.lock; must move with it.
    tetron-appstore-src = { url = "github:tetronos/tetron-appstore/c7cee998afd6cedf521e928bb6bb19e1dade0640"; flake = false; };
    tetron-tui-src = { url = "github:tetronos/tetron-tui/v0.15.3"; flake = false; };
    # Debian TetronOS sources reused here (tetronos-ssh-temp). tetron-os main.
    tetron-os-src = { url = "github:tetronos/tetron-os/cc235c0ec16f76daa32a8b3308f8117159515a9d"; flake = false; };
  };

  outputs = { self, nixpkgs, tetron-src, tetron-wm-src, tetron-appstore-src, tetron-tui-src, tetron-os-src, kmscon-src, libtsm-src }:
    let
      system = "x86_64-linux";
      overlay = final: prev: {
        tetron = final.callPackage ./pkgs/tetron.nix { src = tetron-src; version = "0.15.6"; };
        tetron-wm = final.callPackage ./pkgs/tetron-wm.nix { src = tetron-wm-src; version = "0.15.22"; catalogSrc = tetron-appstore-src; };
        tetron-tui = final.callPackage ./pkgs/tetron-tui.nix { src = tetron-tui-src; version = "0.15.3"; };
        tetronos-ssh-temp = final.callPackage ./pkgs/tetronos-ssh-temp.nix { src = tetron-os-src; };
        pipewire = final.callPackage ./pkgs/pipewire-console.nix { inherit (prev) pipewire; };
        # alsa-utils bundles alsa-plugins, whose full ffmpeg pulls SDL, zenity and GTK.
        alsa-plugins = prev.alsa-plugins.override { ffmpeg = final.ffmpeg-headless; };
        libtsm = prev.libtsm.overrideAttrs { version = "4.8.0"; src = libtsm-src; };
        libxkbcommon-console = final.callPackage ./pkgs/libxkbcommon-console.nix { };
        # No GUI anywhere (modules/no-gui.nix enforces it): dbus without X11
        # autolaunch, cairo and pango without Xlib, XCB, Xft, Xrender. System-wide,
        # so kmscon, chafa (tetron-wm) and NixOS's own tools all get these.
        dbus = prev.dbus.override { x11Support = false; };
        cairo = prev.cairo.override { x11Support = false; xcbSupport = false; };
        pango = prev.pango.override { x11Support = false; };
        kmscon = final.callPackage ./pkgs/kmscon.nix { inherit (prev) kmscon; src = kmscon-src; };
      };
      pkgs = import nixpkgs { inherit system; overlays = [ overlay ]; };
      modules = [ { nixpkgs.overlays = [ overlay ]; } ./modules/tetron.nix ./modules/console.nix ./modules/no-gui.nix ./modules/firmware-wifi.nix ./modules/base.nix ./modules/sound.nix ];
    in {
      overlays.default = overlay;
      nixosModules = { tetron = ./modules/tetron.nix; console = ./modules/console.nix; no-gui = ./modules/no-gui.nix; firmware-wifi = ./modules/firmware-wifi.nix; base = ./modules/base.nix; sound = ./modules/sound.nix; };

      packages.${system} = {
        inherit (pkgs) tetron tetron-wm tetron-tui tetronos-ssh-temp kmscon;
        iso = self.nixosConfigurations.iso.config.system.build.isoImage;
        iso-baseline = self.nixosConfigurations.iso-baseline.config.system.build.isoImage;
        default = self.packages.${system}.iso;
      };

      nixosConfigurations = {
        iso = nixpkgs.lib.nixosSystem { inherit system; modules = modules ++ [ ./hosts/iso.nix ]; };
        # Baseline for the size comparison: the stock minimal installer, unchanged.
        iso-baseline = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix" ];
        };
      };

      checks.${system} = {
        mesh = import ./tests/mesh.nix { inherit pkgs modules; };
      };
    };
}
