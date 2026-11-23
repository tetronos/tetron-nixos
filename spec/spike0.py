'''
Stage 0 spike acceptance: a declarative NixOS image carries kmscon, tetron and
tetron-wm, boots and meshes in VMs. Pass or fail, each recorded with output.
nixpkgs: current stable release branch (26.05 on 2026-11-23), pinned by flake.lock.
'''

from .err import Feat, Req


class A1TetronBuilds(Req):
    '''A1: `nix build .#tetron` succeeds from the v0.15.5 git tag with no network
    in the build. `tetron --version` prints 0.15.5. The closure has no rustc
    reference (nix why-depends).
    '''


class A2WmBuilds(Req):
    '''A2: `nix build .#tetron-wm` succeeds from v0.15.21. Its shell-out helpers
    (systemctl, fc-list, chafa, curl) are resolved by a PATH wrapper.
    '''


class A3IsoBuilds(Req):
    '''A3: `nix build .#iso` gives a hybrid ISO from the pinned nixpkgs.'''


class A4Boots(Req):
    '''A4: the ISO reaches a kmscon login within 60 s under QEMU/KVM with SeaBIOS
    and with OVMF (UEFI).
    '''


class A5Console(Req):
    '''A5: kmscon is the VT (not agetty). Login as tetronos works, tetron-wm
    starts, and quitting it falls back to a login shell.
    '''


class A6DaemonModule(Req):
    '''A6: the tetron service is active from a NixOS module without running
    `tetron install`; state is in StateDirectory; group tetron exists.
    '''


class A7Mesh(Req):
    '''A7: a two-VM nixosTest passes: A creates a network, B joins by invite,
    both ping each other over the mesh.
    '''


class A8KmsconPatch(Req):
    '''A8: the touchpad tap-to-click patch applies in an overlay and kmscon
    builds. No hardware test.
    '''


class A9InstallSmoke(Req):
    '''A9: disko plus nixos-install --flake from a hand-written install.json
    installs into a qcow2; the machine reboots, login works, the daemon is
    active.
    '''


class A10NoGui(Req):
    '''A10: the ISO closure has no X11 or Wayland packages.'''


class Measurements(Feat):
    '''Record: ISO and squashfs bytes; closure sizes (tetron, tetron-wm, whole
    toplevel); cold and warm build times; time to login; sizes after trims
    (documentation off, no default packages, zstd 19 versus xz, minimal kernel
    modules). Baseline: the stock installation-cd-minimal ISO. Compare with the
    Debian server ISO (515 MB).
    '''


class ExitDecision(Req):
    '''Go: A1 to A8 pass and ISO at most 900 MB. Conditional: 900 MB to 1.3 GB or
    a fixable A9 failure (USER decides). No-go: core needs changes beyond the
    D9 and C1 guards, the mesh cannot work, or over 1.3 GB with all trims.
    '''
