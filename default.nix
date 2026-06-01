{ lib, nixos-hardware, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    nixos-hardware.nixosModules.lenovo-thinkpad-t480
    ./modules/core/fonts.nix
    ./modules/core/locale.nix
    ./modules/core/memory.nix
    ./modules/core/networking.nix
    ./modules/core/nix-settings.nix
    ./modules/core/shell.nix
    ./modules/programs/desktop-apps.nix
    ./modules/programs/telegram.nix
    ./modules/programs/file-manager.nix
    ./modules/programs/llm-agents.nix
    ./modules/programs/obsidian.nix
    ./modules/services/audio-pipewire.nix
    ./modules/services/desktop-controls.nix
    ./modules/services/desktop-driftwm.nix
    ./modules/services/failure-reporting.nix
    ./modules/services/nextcloud.nix
    ./modules/services/syncthing.nix
    ./modules/services/top-bar.nix
    ./modules/users/iva.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;
  # Keep the Kaby Lake display workarounds that avoid panel flicker.
  boot.kernelParams = lib.mkAfter [
    "mem_sleep_default=deep"
    "i915.enable_guc=0"
    "i915.enable_dc=0"
    "i915.enable_psr=0"
    "i915.enable_fbc=0"
  ];

  networking.hostName = "thinkpad-driftwm";
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false;
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
    };
  };

  services.openssh.enable = true;
  services.openssh.openFirewall = false;
  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  environment.systemPackages = with pkgs; [
    swaylock
    usbutils
  ];

  security.pam.services.swaylock = { };

  users.users.iva = {
    extraGroups = [ "wheel" "networkmanager" "input" "ydotool" "plugdev" "dialout" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF1BLhireRUEVRQvaJLXOhjNlwAcR739exqlYelC7AAl A53 -> ThinkPad"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDaagT2Kwf7W24WrKQLmLCZKn80MCTALm82Zw80DGlhW Mainframe -> ThinkPad"
    ];
  };

  system.stateVersion = "25.11";
}
