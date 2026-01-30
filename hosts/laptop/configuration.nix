# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  inputs,
  lib,
  pkgs,
  zen-browser,
  ...
}: {
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../modules/system/common.nix
    ]
    ++ lib.optionals (inputs.nixos-hardware.nixosModules ? common-cpu-intel) [
      inputs.nixos-hardware.nixosModules.common-cpu-intel
    ];

  boot.kernelParams = [
    # Required for hibernate/hybrid-sleep with swapfile (physical offset from filefrag)
    "resume_offset=28744960"
  ];

  # Resume from the swapfile on boot (swapfile sits on the root partition).
  boot.resumeDevice = "/dev/disk/by-uuid/02a37ded-6329-4e7b-a3d8-9abe009cc650";

  networking.hostName = "laptop"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Virtualization: libvirtd for KVM/QEMU
  # virtualisation.libvirtd.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages =
    (with pkgs; [
      easyeffects
      opentabletdriver
    ])
    ++ [
      zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

  # Keep hibernation/hybrid-sleep enabled explicitly so GNOME can expose it.
  systemd.sleep.extraConfig = ''
    AllowSuspend=yes
    AllowHibernation=yes
    AllowHybridSleep=yes
  '';

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  services.syncthing = {
    enable = true;
    user = "iva";
    dataDir = "/home/iva";
    configDir = "/home/iva/.config/syncthing";
    openDefaultPorts = true;
    overrideDevices = false; # allow GUI device management
    overrideFolders = true; # keep folders declarative
    settings = {
      options = {
        relaysEnabled = true;
        globalAnnounceEnabled = true;
      };
      folders = {
        "documents" = {
          path = "/home/iva/Documents";
          devices = [];
          versioning = {
            type = "simple";
            params.keep = "10";
          };
        };
      };
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
