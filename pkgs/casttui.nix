# casttui: a terminal UI for casting media to a Chromecast, built on catt.
# catt is an application in nixpkgs; toPythonModule makes it importable
# (casttui uses catt.api). ffmpeg is not bundled, as in the Debian package:
# transcoding and desktop capture use the ffmpeg on PATH (desktop capture
# needs one with x11grab or fbdev, which ffmpeg-headless lacks).
{ lib, python3Packages, catt, src, version }:

python3Packages.buildPythonApplication {
  pname = "casttui";
  inherit version src;
  pyproject = true;
  build-system = [ python3Packages.hatchling ];
  dependencies = [ (python3Packages.toPythonModule catt) python3Packages.tomlkit python3Packages.urwid ];
  postPatch = ''
    grep -qx 'version = "${version}"' pyproject.toml || { echo "version label ${version} does not match pyproject.toml" >&2; exit 1; }
  '';
  # The tests need a Chromecast double and pytest-asyncio; the release runs them.
  doCheck = false;
  pythonImportsCheck = [ "casttui" ];
  meta = { description = "Terminal UI for casting media to a Chromecast"; mainProgram = "casttui"; license = lib.licenses.mit; };
}
