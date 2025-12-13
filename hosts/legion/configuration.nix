# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, zen-browser, lib, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  #Experimental features
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.kernelParams = [
    "amd_pstate=guided"
    # Fixes intermittent keyboard failures on Lenovo Legions
    "i8042.reset"
    "i8042.nomux"
    "i8042.nopnp"
    "i8042.noloop"
    # Disables USB autosuspend globally
    # "usbcore.autosuspend=-1"
    "resume_offset=119848960"
  ];
  boot.extraModulePackages = [ config.boot.kernelPackages.lenovo-legion-module ];
  boot.kernelModules = [ "lenovo-legion-module" "kvm" "kvm-amd" ];
  
  # Enable hibernation
  boot.resumeDevice = "/dev/disk/by-uuid/88959556-19f5-4847-96d7-63e2da596458";

  # Define a swap file for hibernation and general use
  swapDevices = [ {
    device = "/swapfile";
    size = 16 * 1024; # 16GB (adjust based on RAM)
  } ];
  
  # Prevent swapping unless absolutely necessary (keeps swap available for hybrid sleep)
  boot.kernel.sysctl = {
    "vm.swappiness" = 1;
  };



  networking.hostName = "legion"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Bucharest";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "ro_RO.UTF-8/UTF-8"
  ];

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us,ru,ro";
    variant = ",,std";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
    wireplumber.extraConfig = {
      "10-disable-camera" = {
        "monitor.alsa.rules" = [
          {
            matches = [ { "node.name" = "~alsa_input.pci.*"; } ];
            actions = {
              update-props = {
                "api.alsa.use-ucm" = false;
              };
            };
          }
        ];
      };
    };
  };

  # Virtualization: libvirtd for KVM/QEMU
  virtualisation.libvirtd.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.iva = {
    isNormalUser = true;
    description = "IVA";
    extraGroups = [
      "networkmanager"
      "wheel"
      "input"
      "kvm"
      "libvirtd"
      "docker"
    ];
    shell = pkgs.zsh;
    initialPassword = "changme";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = 
    # --- UNSTABLE PACKAGES (Default) ---
    (with pkgs; [
      git
      gh
      stow
      emacs
      vscode
      zed-editor
      codex
      starship
      zoxide
      tree
      bitwarden-desktop
      maple-mono.NF
      dconf-editor
      fastfetch
      obs-studio
      bat
      easyeffects
      ripgrep
      fd
      gparted
      libsForQt5.xp-pen-deco-01-v2-driver
      ghostty
      nix-search-cli
      nixd
      rnote
      anki-bin
      # mpv
      apple-cursor
      gnome-tweaks
      gnomeExtensions.space-bar # This is the coolest thing ever, gnome is soooo  gooood!
      nodejs_22
      wl-clipboard
      blender
      davinci-resolve
      ffmpeg_7-full
      audacity
      orca-slicer
      virt-manager
      qemu
      OVMF
      (pkgs.writeShellScriptBin "davinci-nvidia" ''
        export __NV_PRIME_RENDER_OFFLOAD=1
        export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
        export __GLX_VENDOR_LIBRARY_NAME=nvidia
        export __VK_LAYER_NV_optimus=NVIDIA_only
        exec ${pkgs.davinci-resolve}/bin/davinci-resolve "$@"
      '')
      (pkgs.writeShellScriptBin "lenovo-conservation" ''
        if [ "$1" == "1" ]; then
          echo 1 > /sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode
        else
          echo 0 > /sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode
        fi
      '')
    ]) 
    ++ 
    # --- STABLE PACKAGES (NixOS 24.11) ---
    # Use this for packages that fail to build on unstable (e.g. huge Qt apps)
    (with inputs.nixpkgs-stable.legacyPackages.${pkgs.system}; [
    ])
    ++ 
    # --- FLAKE INPUTS ---
    [
      zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.ayugram-desktop.packages.${pkgs.system}.ayugram-desktop
    ];

  fonts.fontDir.enable = true;

  programs.zsh.enable = true;

  programs.pay-respects.enable = true;

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    openssl
    zlib
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  services.n8n.enable = true;

  # Disable the conflicting default power manager
  services.power-profiles-daemon.enable = false;

  # Handle power button press with hybrid-sleep
  services.logind.powerKey = "hybrid-sleep";
  services.logind.settings = {
    Login = {
      PowerKeyIgnoreInhibited = "yes";
    };
  };

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
      users = [ "iva" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/lenovo-conservation";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Open ports in the firewall.
  networking.firewall = {
    allowedUDPPortRanges = [
      { from = 59000; to = 65000; } # Helps with P2P connections (Telegram)
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
    # Required for DaVinci to see OpenCL/CUDA
    extraPackages = with pkgs; [
      rocmPackages.clr
      rocmPackages.rocminfo
    ];
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = {
      offload = {
        enable = lib.mkOverride 1010 true;
        enableOffloadCmd = lib.mkForce config.hardware.nvidia.prime.offload.enable;
      };
      amdgpuBusId = "PCI:5:0:0";
      nvidiaBusId = "PCI:1:0:0";
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
