# Sound in every edition by default (USER 2026-11-24): PipeWire with ALSA and
# PulseAudio compatibility, WirePlumber; wpctl is what tetron-wm's volume uses.
{ config, lib, pkgs, ... }:
{
  options.tetron-nixos.sound.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "PipeWire sound. Turn off for a headless box.";
  };

  config = lib.mkIf config.tetron-nixos.sound.enable {
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
    environment.systemPackages = [ pkgs.wireplumber pkgs.alsa-utils ];
  };
}
