# PipeWire for a console system: ALSA, PulseAudio and Bluetooth audio stay;
# no X11 bell (libcanberra, libX11), Vulkan, GStreamer (gst-plugins-base needs
# X11/GL), ffmpeg, libcamera, avahi, AirPlay (RAOP) or ROC.
{ lib, pipewire }:

let
  off = [ "gstreamer" "gstreamer-device-provider" "ffmpeg" "libcamera" ];
  flip = f: let m = builtins.match "-D(.*)=enabled" f; in
    if m != null && builtins.elem (builtins.head m) off then "-D${builtins.head m}=disabled" else f;
  dropped = [ "gst-plugins-base" "gstreamer" "ffmpeg" "libcamera" ];
in
(pipewire.override {
  x11Support = false;
  vulkanSupport = false;
  zeroconfSupport = false;
  raopSupport = false;
  rocSupport = false;
}).overrideAttrs (old: {
  mesonFlags = map flip old.mesonFlags;
  buildInputs = lib.filter (p: !(builtins.elem (lib.getName p) dropped)) old.buildInputs;
})
