# libxkbcommon for the console only: no xkbcommon-x11 library (no libxcb), no
# Wayland tools, and the X compose data copied as plain files so libx11 (and
# its libxcb) leave the runtime closure. Keymaps and dead keys keep working.
{ lib, libxkbcommon, libx11, runCommand }:

let
  composeData = runCommand "x11-locale-data" { } ''
    mkdir -p $out/share/X11
    cp -r --no-preserve=mode ${libx11.out}/share/X11/locale $out/share/X11/
    # Compose files `include` each other by absolute store path; point them here.
    find $out -type f -exec sed -i "s|${libx11.out}|$out|g" {} +
    ! grep -rq ${libx11.out} $out
  '';
in
(libxkbcommon.override { withWaylandTools = false; }).overrideAttrs (o: {
  pname = "libxkbcommon-console";
  buildInputs = builtins.filter (p: lib.getName p != "libxcb") o.buildInputs;
  nativeBuildInputs = builtins.filter (p: lib.getName p != "xvfb-run" && lib.getName p != "xvfb") o.nativeBuildInputs;
  mesonFlags = map
    (f: if lib.hasPrefix "-Dx-locale-root=" f then "-Dx-locale-root=${composeData}/share/X11/locale" else f)
    o.mesonFlags ++ [ "-Denable-x11=false" ];
  doCheck = false; # the test suite wants an X server (xvfb)
  meta = o.meta // { pkgConfigModules = [ "xkbcommon" "xkbregistry" ]; };
})
