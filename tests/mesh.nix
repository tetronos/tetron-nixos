# A7: two VMs; A creates a network, B joins by invite, both ping over the mesh.
# Commands as in tetron-testsuite core-smoke.sh and join-invite-input.sh.
# Risk: the nixosTest network has no internet; if iroh discovery needs a relay
# or the DHT, this hermetic run fails and the spike falls back to two VMs with
# user networking (recorded in the results, not hidden).
{ pkgs, modules }:
pkgs.testers.runNixOSTest {
  name = "tetron-mesh";
  nodes = {
    a = { imports = modules; environment.systemPackages = [ pkgs.jq ]; };
    b = { imports = modules; environment.systemPackages = [ pkgs.jq ]; };
  };
  testScript = ''
    start_all()
    for m in (a, b):
        m.wait_for_unit("tetron.service")
        m.wait_until_succeeds("tetron status", timeout=60)
    a.succeed("tetron create --network-name spike --hostname a >&2")
    invite = a.succeed("tetron invite spike create --json | jq -r .invite_key").strip()
    assert invite, "no invite_key from tetron invite create"
    b.succeed(f"printf '%s\\n' '{invite}' | tetron join - --hostname b >&2")
    a.wait_until_succeeds("tetron status --json | jq -e '[.. | .hostname? // empty] | index(\"b\")'", timeout=180)
    ip = "ip -4 -o addr show | awk '/ 10\\.88\\./{print $4}' | cut -d/ -f1"
    a_ip = a.wait_until_succeeds(ip, timeout=60).strip()
    b_ip = b.wait_until_succeeds(ip, timeout=60).strip()
    a.wait_until_succeeds(f"ping -c1 -W2 {b_ip}", timeout=180)
    b.wait_until_succeeds(f"ping -c1 -W2 {a_ip}", timeout=180)
  '';
}
