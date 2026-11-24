# tetron-nixos

NixOS flavour of [TetronOS](https://github.com/tetronos/tetron-os): kmscon console, tetron-wm, tetron mesh. Everything is declarative, built from one flake. Status: early; the live ISO and installer work, not released.

- Spec (libspec): `spec/`. Spec first, code second.
- Planning docs live in `DO-NOT-COMMIT/` (not published).

## Install parts of the suite

Each part of the tetron suite installs on its own, as `apt install tetron-tui` does on Debian. Packages build on stock nixpkgs (x86_64-linux and aarch64-linux): every dependency comes from cache.nixos.org, only the suite's own code compiles. macOS users: use the release binaries of each project.

| Part | Package | NixOS module |
|---|---|---|
| [tetron](https://github.com/tetronos/tetron), the mesh daemon and CLI | `tetron` | `services.tetron` |
| [tetron-tui](https://github.com/tetronos/tetron-tui) | `tetron-tui` | `programs.tetron-tui` |
| [tetron-wm](https://github.com/tetronos/tetron-wm), the desktop for your terminal | `tetron-wm` | `programs.tetron-wm` (`desktop.enable` adds its fonts and tools) |
| kmscon with touchpad tap, tetron-wm on tty1 | `kmscon` | `services.tetron-console` |
| [casttui](https://github.com/tetronos/casttui), cast to a Chromecast | `casttui` | `programs.casttui` |

### Any Linux with Nix

```sh
nix profile install github:tetronos/tetron-nixos#tetron-tui
nix run github:tetronos/tetron-nixos#casttui        # try without installing
```

The tetron daemon needs a system service: on NixOS use the module below; elsewhere `sudo $(command -v tetron) install`. Known issue in tetron v0.15.6: that unit names the Nix store path, which an upgrade and garbage collection remove; run the command again after `nix profile upgrade` until the fix is released.

### NixOS

Add the flake and enable only what you want; nothing else on the machine changes (a check in this repo proves the module set leaves nixpkgs packages as they are).

```nix
{
  inputs.tetron-nixos.url = "github:tetronos/tetron-nixos";
  outputs = { nixpkgs, tetron-nixos, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        tetron-nixos.nixosModules.tetron
        tetron-nixos.nixosModules.tetron-tui
        {
          services.tetron = { enable = true; operator = "alice"; };
          programs.tetron-tui.enable = true;
        }
      ];
    };
  };
}
```

`services.tetron-console` replaces the login on the virtual consoles: use it on a machine without a display manager.

### The whole TetronOS

`tetron-nixos.nixosModules.default` is the complete system (all parts plus the no-GUI console base, sound, wifi firmware, branding), as the live ISO (`nix build .#iso`) and its installer set up.
