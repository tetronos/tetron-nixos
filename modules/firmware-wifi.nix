# Wifi in every tetron-nixos edition, server included, so a wifi-only laptop
# gets online. Default = the Debian tetronos-firmware-wifi set (Intel, Realtek,
# MediaTek, Atheros, Broadcom/Cypress), taken from linux-firmware instead of all
# of it (1.9 GB). A host may narrow `tetron-nixos.firmware.wifi` (the spike ISO
# keeps only Intel). NetworkManager (nmcli, nmtui) as in the Debian
# tetronos-core; iw for diagnostics.
{ config, lib, pkgs, ... }:
let
  cfg = config.tetron-nixos.firmware.wifi;
  wifiFirmware = pkgs.runCommand "tetron-nixos-firmware-wifi" { } ''
    src=${pkgs.linux-firmware}/lib/firmware
    dst=$out/lib/firmware
    mkdir -p $dst
    cd $src
    for p in ${lib.concatStringsSep " " cfg}; do
      for f in $p; do
        [ -e "$f" ] || continue
        mkdir -p "$dst/$(dirname "$f")"
        cp -rL "$f" "$dst/$f"
      done
    done
    test -n "$(ls -A $dst)"
  '';
in
{
  options.tetron-nixos.firmware.wifi = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    description = "Shell globs under lib/firmware of linux-firmware to ship.";
    default = [
      "iwlwifi-*" "intel/iwlwifi"                                  # Intel
      "rtw88" "rtw89" "rtlwifi" "rtl_nic"                          # Realtek
      "mediatek" "mt76*" "mt7*"                                    # MediaTek
      "ath9k_htc" "ath10k" "ath11k" "ath12k" "ath6k" "htc_*.fw" "ar9170*.fw" # Atheros
      "brcm" "cypress"                                             # Broadcom, Cypress
    ];
  };

  # USER 2026-11-24: mobile broadband (ModemManager, libqmi, 67 MiB) is an
  # option, off by default; a laptop with a WWAN card or a USB modem turns it on.
  options.tetron-nixos.modem.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "ModemManager for 4G/5G cards and USB modems.";
  };

  config = {
    networking.modemmanager.enable = config.tetron-nixos.modem.enable;
    # The NetworkManager package links ModemManager for its WWAN plugin
    # whatever the service setting; without the modem option it is built
    # without it (-Dmodem_manager=false), so libqmi and friends stay out.
    networking.networkmanager.package = lib.mkIf (!config.tetron-nixos.modem.enable)
      (pkgs.networkmanager.overrideAttrs (old: {
        mesonFlags = map (f: if f == "-Dmodem_manager=true" then "-Dmodem_manager=false" else f) old.mesonFlags;
        buildInputs = lib.filter (p: lib.getName p != "modemmanager") old.buildInputs;
      }));
    # An empty list (a VM, a wired box) ships no wifi firmware at all.
    hardware.firmware = lib.optional (cfg != [ ]) wifiFirmware;
    hardware.wirelessRegulatoryDatabase = true;
    networking.networkmanager.enable = true;
    environment.systemPackages = [ pkgs.iw ];
  };
}
