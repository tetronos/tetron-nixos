# kmscon 10.0.4 as in the Debian TetronOS: no OpenGL modules (no mesa, gbm,
# GLU, GL in the closure; software renderer only) and touchpad tap-to-click.
# nixpkgs' sandbox.patch is written for 9.3.5; the same change (systemd units
# into the store, not /etc) is made here against the 10.0.4 meson.build.
{ lib, kmscon, libtsm, libxkbcommon-console, dbus, seatd, src }:

(kmscon.override { inherit libtsm; libxkbcommon = libxkbcommon-console; }).overrideAttrs (o: {
  version = "10.0.4";
  inherit src;
  patches = [ ./patches/kmscon-touchpad-tap.patch ];
  postPatch = (o.postPatch or "") + ''
    sed -z -i "s|systemdsystemunitdir = systemd_deps.get_variable([^)]*)|systemdsystemunitdir = get_option('libdir') / 'systemd' / 'system'|" meson.build
    grep -q "systemdsystemunitdir = get_option('libdir')" meson.build
  '';
  buildInputs = builtins.filter
    (p: !(builtins.elem (lib.getName p) [ "libGLU" "libGL" "glu" "libglvnd" "libgbm" "mesa-libgbm" ]))
    o.buildInputs
    # 10.x adds dbus and libseat (both on in the Debian build, --auto-features=enabled).
    ++ [ dbus seatd ];
  # nixpkgs' postFixup edits bin/kmscon as a shell script (9.x); in 10.x it is
  # the ELF binary. kmscon-launch-gui only exists to start graphical programs
  # from the console: a GUI component, so it is removed, not patched.
  postFixup = ''
    rm $out/bin/kmscon-launch-gui
  '';
  mesonFlags = (o.mesonFlags or [ ]) ++ [
    "-Dvideo_drm3d=disabled"
    "-Drenderer_gltex=disabled"
  ];
})
