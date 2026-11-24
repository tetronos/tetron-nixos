# TetronOS boot menu theme from the Debian TetronOS sources (tetron-os
# config/common/bootloaders): splash.svg rendered to a 640x480 PNG with the
# NixOS facts filled in, the live grub theme, and a Unifont 16 GRUB font.
# Rendered with stock nixpkgs tools (cache hits); nothing of them is in the
# output's closure.
{ runCommand, stock, src, edition, base, arch, built, kernel }:

runCommand "tetron-boot-theme" {
  nativeBuildInputs = [ stock.librsvg stock.grub2 ];
  FONTCONFIG_FILE = stock.makeFontsConf { fontDirectories = [ stock.dejavu_fonts ]; };
} ''
  b=${src}/config/common/bootloaders
  mkdir -p $out
  sed -e 's|@TETRONOS_EDITION@ edition · based on Debian @VERSION@ (@DISTRIBUTION@) · @ARCHITECTURE@|${edition} edition · based on ${base} · ${arch}|' \
      -e 's|built @YEAR@-@MONTH@-@DAY@ · linux @LINUX_VERSIONS@|${built} · linux ${kernel}|' \
      $b/splash.svg > splash.svg
  if grep -q '@[A-Z_]*@' splash.svg; then echo "splash.svg: placeholder left" >&2; grep -o '@[A-Z_]*@' splash.svg >&2; exit 1; fi
  rsvg-convert -w 640 -h 480 -b '#080a09' -o $out/splash.png splash.svg
  sed 's|"\.\./splash\.png"|"splash.png"|' $b/grub-pc/live-theme/theme.txt > $out/theme.txt
  grep -q '^desktop-image: "splash.png"' $out/theme.txt
  echo 'desktop-color: "#000000"' >> $out/theme.txt
  grub-mkfont -s 16 -n "Unifont Regular 16" -o $out/unifont-16.pf2 ${stock.unifont}/share/fonts/opentype/unifont.otf
''
