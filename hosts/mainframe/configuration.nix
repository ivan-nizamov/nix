# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  pkgs,
  zen-browser,
  lib,
  inputs,
  yandex-browser,
  ...
}: let
  scripts = import ../../modules/home/scripts.nix {inherit pkgs;};
in {
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../modules/system/common.nix
    ]
    ++ lib.optionals (inputs.nixos-hardware.nixosModules ? common-cpu-amd) [
      inputs.nixos-hardware.nixosModules.common-cpu-amd
    ]
    ++ lib.optionals (inputs.nixos-hardware.nixosModules ? common-gpu-nvidia) [
      inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    ];

  boot.kernelParams = [
    "amd_pstate=guided"
    # Fixes intermittent keyboard failures on Lenovo Legions
    "i8042.reset"
    "i8042.nomux"
    "i8042.nopnp"
    "i8042.noloop"
    # Disables USB autosuspend globally
    # "usbcore.autosuspend=-1"
    # Fix screen flickering/blackouts on AMD iGPUs (Scatter/Gather display issue)
    "amdgpu.sg_display=0"
  ];

  # Enable firmware and microcode updates

  hardware.enableRedistributableFirmware = true;

  boot.kernelModules = ["kvm" "kvm-amd"];
  boot.kernel.sysctl = {"vm.swappiness" = 1;};

  networking.hostName = "mainframe"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us,ru,ro";
    variant = ",,std";
  };

  # Virtualization: libvirtd for KVM/QEMU
  # virtualisation.libvirtd.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).

  # services.xserver.libinput.enable = true;

  users.users.iva.extraGroups = ["input"];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages =
    # --- UNSTABLE PACKAGES (Default) ---
    (with pkgs; [
      libreoffice
      wl-clipboard
      blender
      davinci-resolve
      ffmpeg_7-full
      audacity
      orca-slicer
      losslesscut-bin

      scripts.davinciNvidia
      scripts.lenovoConservation
      qbittorrent
      clock-rs
    ])
    ++
    # --- STABLE PACKAGES (NixOS 24.11) ---
    # Use this for packages that fail to build on unstable (e.g. huge Qt apps)
    (with inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}; [
      easyeffects
    ])
    ++
    # --- FLAKE INPUTS ---
    [
      zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.ayugram-desktop.packages.${pkgs.stdenv.hostPlatform.system}.ayugram-desktop
      yandex-browser.packages.${pkgs.stdenv.hostPlatform.system}.yandex-browser-stable
      inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Disable the conflicting default power manager
  services.power-profiles-daemon.enable = false;

  # Handle power button press with hybrid-sleep
  services.logind.settings.Login.HandlePowerKey = "hybrid-sleep";

  services.tlp = {
    enable = true;
    settings = {
      # Disable autosuspend for USB input devices (keyboards/mice)
      USB_AUTOSUSPEND = 0;
    };
  };

  systemd.tmpfiles.rules = [
    # 1 enables conservation mode (60% limit), 0 disables it (100% charge)
    "w /sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode - - - - 1"
  ];

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Allow 'iva' to run the conservation script without a password
  security.sudo.extraRules = [
    {
      users = ["iva"];
      commands = [
        {
          command = "/run/current-system/sw/bin/lenovo-conservation";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  services.syncthing = {
    enable = true;
    user = "iva";
    dataDir = "/home/iva/.local/share/syncthing";
    configDir = "/home/iva/.config/syncthing";
    overrideDevices = false;
    overrideFolders = false;
    openDefaultPorts = true;
  };

  # Open ports in the firewall.
  networking.firewall = {
    allowedUDPPortRanges = [
      {
        from = 59000;
        to = 65000;
      } # Helps with P2P connections (Telegram)
    ];
  };

  # Fix for Screen Sharing on Wayland
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };

  # Force Wayland for Qt apps (Telegram)
  environment.sessionVariables = {
    QT_QPA_PLATFORM = "wayland";
  };

  # Graphics / Nvidia
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    # Required for DaVinci to see OpenCL/CUDA
    extraPackages = with pkgs; [
      rocmPackages.clr
      rocmPackages.rocminfo
    ];
  };

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
    prime = {
      sync.enable = false;
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      amdgpuBusId = "PCI:5:0:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  specialisation = {
    performance.configuration = {
      system.nixos.tags = ["performance"];
      hardware.nvidia = {
        powerManagement.finegrained = lib.mkForce false;
        prime = {
          sync.enable = lib.mkForce true;
          offload = {
            enable = lib.mkForce false;
            enableOffloadCmd = lib.mkForce false;
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
  system.stateVersion = "25.05"; # Did you read the comment?
}
