'''
The nix way: everything is declared, nothing is mutated.
'''

from .err import Feat, Req


class Declarative(Req):
    '''The system, the ISO and the installed host come from one flake.
    Configuration is Nix modules, not shell scripts that edit files. There is
    no imperative post-install step that is not itself a declared unit.
    '''


class Pinned(Req):
    '''flake.lock pins every input. A build from the same commit gives the
    same result. nixpkgs follows a stable release branch (decision D7 pending).
    '''


class Tiers(Feat):
    '''Tiers (server, server-fw, desktop) are NixOS configurations that share
    modules. A tier change is a changed option plus nixos-rebuild switch.
    '''


class Installer(Feat):
    '''Install is declarative: disko for partitioning and nixos-install from
    the flake (nixos-anywhere for remote). The TUI selects or writes a host
    declaration (user, hostname, disk, tier, invite), it does not copy a tree.
    '''


class Checks(Feat):
    '''nix flake check runs the guardrails: no X11 or Wayland packages in the
    closure, a recorded size budget, and nixosTest VM boot tests.
    '''
