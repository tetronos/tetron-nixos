# tetron core: P2P mesh VPN daemon and CLI. Built from the release tag; the
# [patch.crates-io] path crates under vendor/ come with the source.
{ lib, rustPlatform, makeWrapper, python3, iproute2, src, version }:

rustPlatform.buildRustPackage {
  pname = "tetron";
  inherit version src;
  # The label must match the source: a stale flake.lock once shipped v0.15.21 as 0.15.22.
  postPatch = ''
    grep -qx 'version = "${version}"' Cargo.toml || { echo "version label ${version} does not match Cargo.toml" >&2; exit 1; }
  '';
  cargoLock.lockFile = "${src}/Cargo.lock";
  # Tests need TUN and network; the real check is the two-VM nixosTest.
  doCheck = false;
  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ python3 ]; # patchShebangs for tetron-invite-serve
  postInstall = ''
    install -Dm755 contrib/tetron-invite-serve.py $out/share/tetron/tetron-invite-serve.py
    install -Dm755 contrib/tetron-invite-serve.py $out/bin/tetron-invite-serve
    wrapProgram $out/bin/tetron --prefix PATH : ${lib.makeBinPath [ iproute2 ]}
  '';
  meta = { mainProgram = "tetron"; license = lib.licenses.mpl20; };
}
