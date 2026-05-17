{ config, lib, nixos-hardware, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    nixos-hardware.nixosModules.lenovo-thinkpad-t480
    ../../modules/core/fonts.nix
    ../../modules/core/locale.nix
    ../../modules/core/memory.nix
    ../../modules/core/networking.nix
    ../../modules/core/nix-settings.nix
    ../../modules/core/shell.nix
    ../../modules/accessibility/handy.nix
    ../../modules/input/wayland-text-injection.nix
    ../../modules/programs/desktop-apps.nix
    ../../modules/programs/llm-agents.nix
    ../../modules/programs/obsidian.nix
    ../../modules/services/audio-pipewire.nix
    ../../modules/services/desktop-gnome.nix
    ../../modules/services/failure-reporting.nix
    ../../modules/services/syncthing.nix
    ../../modules/users/iva.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;
  # Override nixos-hardware Kaby Lake defaults to avoid eDP panel flicker on
  # monotone content and display timing glitches on Intel i915 panels.
  boot.kernelParams = lib.mkAfter [
    "mem_sleep_default=deep"
    "i915.enable_guc=0"
    "i915.enable_dc=0"
    "i915.enable_psr=0"
    "i915.enable_fbc=0"
  ];

  networking.hostName = "thinkpad";
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  environment.systemPackages = [ pkgs.usbutils ];

  services."06cb-009a-fingerprint-sensor" = {
    enable = true;
    backend = "libfprint-tod";
    calib-data-file = ./calib-data.bin;
  };
  security.pam.services.gdm-fingerprint.text = lib.mkIf config.services.fprintd.enable (lib.mkOverride 0 ''
    auth       required                    pam_shells.so
    auth       requisite                   pam_nologin.so
    auth       requisite                   pam_faillock.so      preauth
    auth       required                    ${config.services.fprintd.package}/lib/security/pam_fprintd.so max-tries=6 timeout=60
    auth       required                    pam_env.so conffile=/etc/pam/environment readenv=0
    auth       [success=ok default=1]      ${pkgs.gdm}/lib/security/pam_gdm.so
    auth       optional                    ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so

    account    include                     login

    password   required                    pam_deny.so

    session    include                     login
  '');
  security.pam.services.sudo.fprintAuth = false;
  security.pam.services.polkit-1.fprintAuth = true;

  console = {
    packages = [ pkgs.terminus_font ];
    font = "${pkgs.terminus_font}/share/consolefonts/ter-v16n.psf.gz";
    earlySetup = true;
  };

  users.users.iva.extraGroups = [ "wheel" "networkmanager" "input" "ydotool" "plugdev" "dialout" ];

  system.stateVersion = "25.11";
}
