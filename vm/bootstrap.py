#!/usr/bin/env python3
"""Spike 0: bootstrap the throwaway NixOS dev VM from the official minimal ISO.
Drives the ISO serial console: partition (GPT, ESP + ext4), nixos-generate-config,
install vm/configuration.nix, nixos-install, poweroff. Run from the repo root:
  python3 vm/bootstrap.py
Every step is logged to build/vm/bootstrap.log."""
import os, re, subprocess, sys
import pexpect

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VMDIR = os.path.join(ROOT, "build", "vm")
ISO = os.path.join(VMDIR, "nixos-minimal-26.05.iso")
DISK = os.path.join(VMDIR, "disk.qcow2")
VARS = os.path.join(VMDIR, "OVMF_VARS.fd")
CODE = "/usr/share/OVMF/OVMF_CODE_4M.fd"
PORT = os.environ.get("VM_PORT", "2223")


def main():
    for f in (ISO, os.path.join(VMDIR, "id_ed25519.pub"), CODE):
        if not os.path.exists(f):
            sys.exit(f"bootstrap: missing {f}")
    if os.path.exists(DISK):
        sys.exit(f"bootstrap: {DISK} exists; archive it first (never overwritten)")
    pub = open(os.path.join(VMDIR, "id_ed25519.pub")).read().strip()
    cfg = open(os.path.join(ROOT, "vm", "configuration.nix")).read().replace("@SSHPUB@", pub)
    subprocess.run(["qemu-img", "create", "-f", "qcow2", DISK, "120G"], check=True)
    subprocess.run(["cp", "/usr/share/OVMF/OVMF_VARS_4M.fd", VARS], check=True)
    # Direct kernel boot so the ISO kernel gets console=ttyS0 (its menu has no serial entry).
    x = os.path.join(VMDIR, "iso-x")
    os.makedirs(x, exist_ok=True)
    grub = subprocess.run(["xorriso", "-osirrox", "on", "-indev", ISO, "-extract", "/boot/efi.img", os.path.join(x, "efi.img")],
                          capture_output=True, text=True)
    subprocess.run(["mcopy", "-n", "-i", os.path.join(x, "efi.img"), "::EFI/BOOT/grub.cfg", x], check=True)
    m = re.search(r"linux (/boot/\S+/bzImage) \S+ (init=\S+) (.*?)\n\s*initrd (/boot/\S+/initrd)", open(os.path.join(x, "grub.cfg")).read())
    if not m:
        sys.exit("bootstrap: could not read the kernel line from the ISO grub.cfg")
    kern, init, rest, ird = m.group(1), m.group(2), m.group(3), m.group(4)
    for src, dst in ((kern, "bzImage"), (ird, "initrd")):
        subprocess.run(["xorriso", "-osirrox", "on", "-indev", ISO, "-extract", src, os.path.join(x, dst)], check=True, capture_output=True)
    append = f"{init} {rest} console=ttyS0,115200"
    cmd = (f"qemu-system-x86_64 -enable-kvm -cpu host -smp 8 -m 16G -nographic "
           f"-kernel {x}/bzImage -initrd {x}/initrd -append '{append}' "
           f"-drive if=pflash,format=raw,readonly=on,file={CODE} "
           f"-drive if=pflash,format=raw,file={VARS} "
           f"-drive file={DISK},if=virtio,format=qcow2 "
           f"-drive file={ISO},if=none,id=iso,format=raw,readonly=on -device virtio-blk-pci,drive=iso "
           f"-nic user,hostfwd=tcp::{PORT}-:22")
    log = open(os.path.join(VMDIR, "bootstrap.log"), "w")
    p = pexpect.spawn("/bin/sh", ["-c", cmd], encoding="utf-8", timeout=900)
    p.logfile = log
    # The prompt is colored and carries a terminal title escape; match its tail.
    prompt = r"nixos@nixos:[^\n\]]*\]\$"
    p.expect(prompt, timeout=600)

    def run(c, t=900):
        p.sendline(c)
        p.expect(prompt, timeout=t)

    run("sudo -i true")
    # Verify target: the install disk is the one virtio disk of exactly 120G
    # (the ISO is also a virtio disk, and its name order is not fixed).
    run("lsblk -bdno NAME,SIZE")
    disks = re.findall(r"^(vd[a-z])\s+128849018880\s*$", p.before.replace("\r", ""), re.M)
    if len(disks) != 1:
        p.terminate(force=True)
        sys.exit(f"bootstrap: want exactly one 120G virtio disk, found {disks}; refusing to partition")
    d = "/dev/" + disks[0]
    run(f"sudo parted -s {d} -- mklabel gpt mkpart ESP fat32 1MiB 513MiB set 1 esp on mkpart root ext4 513MiB 100%")
    run(f"sudo mkfs.fat -F 32 -n boot {d}1 && sudo mkfs.ext4 -F -L nixos {d}2")
    run("sudo mount /dev/disk/by-label/nixos /mnt && sudo mkdir -p /mnt/boot && sudo mount /dev/disk/by-label/boot /mnt/boot")
    run("sudo nixos-generate-config --root /mnt")
    run("sudo sh -c 'cat > /mnt/etc/nixos/configuration.nix' <<'CFGEOF'\n" + cfg + "\nCFGEOF")
    run("sudo nixos-install --no-root-passwd 2>&1 | tail -25", t=3600)
    p.sendline("sudo poweroff")
    p.expect(pexpect.EOF, timeout=300)
    print("bootstrap: done; disk", DISK)


main()
