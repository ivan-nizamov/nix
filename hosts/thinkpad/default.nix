{ lib, nixos-hardware, pkgs, ... }:
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
  # monotone content (common with PSR/FBC on Intel i915 panels).
  boot.kernelParams = lib.mkAfter [
    "mem_sleep_default=deep"
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
    backend = "python-validity";
  };
  security.pam.services.sudo.fprintAuth = true;
  security.pam.services.polkit-1.fprintAuth = true;

  console = {
    packages = [ pkgs.terminus_font ];
    font = "${pkgs.terminus_font}/share/consolefonts/ter-v16n.psf.gz";
    earlySetup = true;
  };

  users.users.iva.extraGroups = [ "wheel" "networkmanager" "input" "ydotool" "plugdev" "dialout" ];

  system.stateVersion = "25.11";
}
