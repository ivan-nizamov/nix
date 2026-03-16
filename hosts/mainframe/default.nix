{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/accessibility/dictation.nix
    ../../modules/core/locale.nix
    ../../modules/core/networking.nix
    ../../modules/core/nix-settings.nix
    ../../modules/core/shell.nix
    ../../modules/hardware/hybrid-graphics.nix
    ../../modules/input/wayland-text-injection.nix
    ../../modules/programs/llm-agents.nix
    ../../modules/programs/neru.nix
    ../../modules/programs/obsidian.nix
    ../../modules/security/passwordless-rebuilds.nix
    ../../modules/services/audio-pipewire.nix
    ../../modules/services/desktop-gnome.nix
    ../../modules/services/failure-reporting.nix
    ../../modules/services/openclaw-embeddings.nix
    ../../modules/services/openclaw-gateway.nix
    ../../modules/users/iva.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "mainframe";

  hardware.keyboard.qmk.enable = true;

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
  };

  boot.kernel.sysctl."vm.swappiness" = 180;

  system.stateVersion = "25.11";
}
