# tetron-tui: the terminal UI for tetron. The invite share runs core's
# tetron-invite-serve.py, found through TETRON_INVITE_SERVE (the Debian path
# /usr/share/tetron does not exist here).
{ lib, rustPlatform, makeWrapper, curl, tetron, src, version }:

rustPlatform.buildRustPackage {
  pname = "tetron-tui";
  inherit version src;
  # The label must match the source: a stale flake.lock once shipped v0.15.21 as 0.15.22.
  postPatch = ''
    grep -qx 'version = "${version}"' Cargo.toml || { echo "version label ${version} does not match Cargo.toml" >&2; exit 1; }
  '';
  cargoLock = { lockFile = "${src}/Cargo.lock"; allowBuiltinFetchGit = true; };
  doCheck = false;
  nativeBuildInputs = [ makeWrapper ];
  postInstall = ''
    wrapProgram $out/bin/tetron-tui \
      --prefix PATH : ${lib.makeBinPath [ curl ]} \
      --set-default TETRON_INVITE_SERVE ${tetron}/share/tetron/tetron-invite-serve.py
  '';
  meta = { mainProgram = "tetron-tui"; };
}
