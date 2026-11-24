# tetron-wm: the console window manager. Git dependencies (tetron-proto,
# tetron-catalog) are fetched by builtins.fetchGit at the Cargo.lock revisions.
{ lib, rustPlatform, makeWrapper, fontconfig, chafa, curl, openssh, src, version, catalogSrc }:

rustPlatform.buildRustPackage {
  pname = "tetron-wm";
  inherit version src;
  # The label must match the source: a stale flake.lock once shipped v0.15.21 as 0.15.22.
  postPatch = ''
    grep -qx 'version = "${version}"' Cargo.toml || { echo "version label ${version} does not match Cargo.toml" >&2; exit 1; }
  '';
  cargoLock = { lockFile = "${src}/Cargo.lock"; allowBuiltinFetchGit = true; };
  doCheck = false;
  nativeBuildInputs = [ makeWrapper ];
  # Workaround (finding C8): the vendored tetron-catalog crate resolves
  # src/../../../assets/catalog.json to $NIX_BUILD_TOP/assets/catalog.json.
  preBuild = ''
    mkdir -p "$NIX_BUILD_TOP/assets"
    cp ${catalogSrc}/assets/catalog.json ${catalogSrc}/assets/suite-apps.txt "$NIX_BUILD_TOP/assets/"
  '';
  postInstall = ''
    install -Dm755 scripts/tetron-wm-startpage $out/bin/tetron-wm-startpage
    wrapProgram $out/bin/tetron-wm --prefix PATH : ${lib.makeBinPath [ fontconfig.bin chafa curl openssh ]}
  '';
  meta = { mainProgram = "tetron-wm"; };
}
