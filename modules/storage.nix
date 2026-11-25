# Drive mounting without sudo, as the Debian tetronos-storage package does:
# udisks2, the tools for exFAT, FAT, NTFS and ext4, and a polkit rule that
# lets members of users mount, unlock, eject and power off drives. Console
# logins (kmscon) and ssh are not active seat sessions, so polkit's
# allow_active defaults never apply to them. Nothing is mounted by itself:
# the Files app (tetron-wm) and `udisksctl` mount on request. Formatting,
# partitioning and unmounting other users' or system mounts are not granted.
{ lib, pkgs, ... }:
{
  services.udisks2.enable = lib.mkDefault true;
  # Mounts go to /run/media/<user>/<label>, per user (NixOS default;
  # Debian uses /media/<user>). mountOnMedia would share /media/<label> between users.
  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
      if (/^org\.freedesktop\.udisks2\.(filesystem-mount|filesystem-mount-system|filesystem-mount-other-seat|encrypted-unlock|encrypted-unlock-system|encrypted-unlock-other-seat|eject-media|eject-media-system|eject-media-other-seat|power-off-drive|power-off-drive-system|power-off-drive-other-seat)$/.test(action.id) &&
          subject.isInGroup("users")) {
        return polkit.Result.YES;
      }
    });
  '';
  environment.systemPackages = with pkgs; [ exfatprogs dosfstools ntfs3g e2fsprogs ];
}
