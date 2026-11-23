'''
tetron-nixos product: the NixOS flavour of TetronOS.
'''

from libspec import UserStory
from .err import Feat, Req


class Flavour(Req):
    '''The NixOS flavour is a second flavour beside the Debian TetronOS
    (tetronos/tetron-os), not a replacement. Debian packaging (.deb, apt,
    live-build) is not touched from this repository.
    '''


class ConsoleNative(Req):
    '''Same product identity as TetronOS: kmscon console, tetron-wm, tetron
    mesh. No X11 and no Wayland in any closure.
    '''


class ServerNixInstall(UserStory):
    """USER-STORY: NIX-SERVER-INSTALL

    An operator boots the NixOS flavour ISO (local or BMC virtual media) and
    installs a declared host onto a disk, then the machine joins the tetron mesh.

    Priority: high.
    Acceptance: VM boot and install test first (nixosTest), then hardware.
    """
    brief_title = "Declarative install of the NixOS flavour"
    priority = "high"
