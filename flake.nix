{
  description = "tetron-nixos: the NixOS flavour of TetronOS (spike 0)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    tetron-src = { url = "github:tetronos/tetron/v0.15.6"; flake = false; };
    tetron-wm-src = { url = "github:tetronos/tetron-wm/v0.15.23"; flake = false; };
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
    # Partitioning for the installer (plan section 12).
    disko = { url = "github:nix-community/disko/latest"; inputs.nixpkgs.follows = "nixpkgs"; };
  };

  outputs = inputs@{ self, nixpkgs, disko, tetron-src, tetron-wm-src, tetron-appstore-src, tetron-tui-src, tetron-os-src, kmscon-src, libtsm-src }:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      # The suite: our own packages only, on stock nixpkgs. Overrides no
      # nixpkgs package, so a desktop NixOS or any distro with Nix can use it
      # and every dependency comes from cache.nixos.org.
      suite = final: prev: {
        tetron = final.callPackage ./pkgs/tetron.nix { src = tetron-src; version = "0.15.6"; };
        tetron-wm = final.callPackage ./pkgs/tetron-wm.nix { src = tetron-wm-src; version = "0.15.23"; catalogSrc = tetron-appstore-src; };
        tetron-tui = final.callPackage ./pkgs/tetron-tui.nix { src = tetron-tui-src; version = "0.15.3"; };
        tetronos-ssh-temp = final.callPackage ./pkgs/tetronos-ssh-temp.nix { src = tetron-os-src; };
        libxkbcommon-console = final.callPackage ./pkgs/libxkbcommon-console.nix { };
        # libtsm 4.8 for kmscon only: the system libtsm stays as it is.
        kmscon = final.callPackage ./pkgs/kmscon.nix {
          inherit (prev) kmscon;
          src = kmscon-src;
          libtsm = prev.libtsm.overrideAttrs { version = "4.8.0"; src = libtsm-src; };
        };
      };
      # The TetronOS console system: no GUI anywhere (modules/no-gui.nix
      # enforces it). System-wide rebuilds, so only the edition uses this.
      console = final: prev: {
        pipewire = final.callPackage ./pkgs/pipewire-console.nix { inherit (prev) pipewire; };
        # alsa-utils bundles alsa-plugins, whose full ffmpeg pulls SDL, zenity and GTK.
        alsa-plugins = prev.alsa-plugins.override { ffmpeg = final.ffmpeg-headless; };
        # dbus without X11 autolaunch, cairo and pango without Xlib, XCB, Xft,
        # Xrender: kmscon, chafa (tetron-wm) and NixOS's own tools all get these.
        dbus = prev.dbus.override { x11Support = false; };
        cairo = prev.cairo.override { x11Support = false; xcbSupport = false; };
        pango = prev.pango.override { x11Support = false; };
      };
      # Edition tools: boot theme and installer.
      edition = final: prev: {
        # Boot splash and theme (modules/branding.nix). Built date: this flake's commit.
        tetron-boot-theme = args: final.callPackage ./pkgs/tetron-boot-theme.nix ({
          stock = nixpkgs.legacyPackages.${system};
          src = tetron-os-src;
          # "built DATE" from this flake's own date; a copy without one (the
          # installed host's path input) shows the pinned nixpkgs date instead.
          built = let
            day = d: "${builtins.substring 0 4 d}-${builtins.substring 4 2 d}-${builtins.substring 6 2 d}";
            own = self.lastModified or 0;
          in if own > 0 then "built ${day self.lastModifiedDate}" else "nixpkgs ${day nixpkgs.lastModifiedDate}";
        } // args);
        tetron-nixos-install = final.writeShellApplication {
          name = "tetron-nixos-install";
          # disko from nixpkgs (same 1.13.0 as the input): it shares this
          # nixpkgs source and systemd; the flake's package embedded a second
          # copy of each (197 MiB and 179 MiB). The input gives the module only.
          runtimeInputs = with final; [ jq git util-linux coreutils nixos-install-tools final.disko ];
          text = builtins.readFile ./pkgs/tetron-nixos-install.sh;
        };
      };
      overlay = lib.composeManyExtensions [ suite console edition ];
      # Linux platforms the suite packages are built for (no macOS: USER).
      systems = [ "x86_64-linux" "aarch64-linux" ];
      suitePkgs = sys: import nixpkgs { system = sys; overlays = [ suite ]; };
      pkgs = import nixpkgs { inherit system; overlays = [ overlay ]; };
      # sharedModules without the overlay, for nixosTests (their pkgs is fixed
      # and already has the overlay); modules adds it for real systems.
      modules = [ { nixpkgs.overlays = [ overlay ]; } ] ++ sharedModules;
      sharedModules = [ ./modules/tetron.nix ./modules/console.nix ./modules/no-gui.nix ./modules/firmware-wifi.nix ./modules/base.nix ./modules/sound.nix ./modules/branding.nix ];
      # What an installed machine's host flake gets as its tetron-nixos copy.
      source = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.unions [ ./flake.nix ./flake.lock ./lib ./modules ./pkgs ./hosts ./tests ];
      };
      # The live ISO carries the source and every flake input, so the installer
      # evaluates the host flake without fetching sources.
      installerModule = { pkgs, ... }: {
        environment.etc."tetron-nixos/source".source = source;
        environment.systemPackages = [ pkgs.tetron-nixos-install ];
        system.extraDependencies = map (i: i.outPath) (lib.attrValues (removeAttrs inputs [ "self" ]));
      };
    in {
      overlays = { default = overlay; inherit suite console edition; };
      lib.mkHost = { install, hardware ? null }: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = modules ++ [ disko.nixosModules.disko (import ./lib/host.nix install) ] ++ lib.optional (hardware != null) hardware;
      };
      nixosModules = { tetron = ./modules/tetron.nix; console = ./modules/console.nix; no-gui = ./modules/no-gui.nix; firmware-wifi = ./modules/firmware-wifi.nix; base = ./modules/base.nix; sound = ./modules/sound.nix; branding = ./modules/branding.nix; };

      # Suite packages on stock nixpkgs, for every Linux platform; the edition
      # images on x86_64 only.
      packages = lib.genAttrs systems (sys:
        let p = suitePkgs sys; in {
          inherit (p) tetron tetron-wm tetron-tui tetronos-ssh-temp kmscon;
        } // lib.optionalAttrs (sys == system) {
          inherit (pkgs) tetron-nixos-install;
          iso = self.nixosConfigurations.iso.config.system.build.isoImage;
          iso-baseline = self.nixosConfigurations.iso-baseline.config.system.build.isoImage;
          default = self.packages.${system}.iso;
        });

      nixosConfigurations = {
        iso = nixpkgs.lib.nixosSystem { inherit system; modules = modules ++ [ ./hosts/iso.nix installerModule ]; };
        # Baseline for the size comparison: the stock minimal installer, unchanged.
        iso-baseline = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix" ];
        };
      };

      checks.${system} = {
        mesh = import ./tests/mesh.nix { inherit pkgs; modules = sharedModules; };
      };
    };
}
