{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/accessibility/dictation.nix
    ../../modules/core/fonts.nix
    ../../modules/core/locale.nix
    ../../modules/core/memory.nix
    ../../modules/core/networking.nix
    ../../modules/core/nix-settings.nix
    ../../modules/core/shell.nix
    ../../modules/hardware/espressif-serial.nix
    ../../modules/hardware/hybrid-graphics.nix
    ../../modules/input/wayland-text-injection.nix
    ../../modules/programs/desktop-apps.nix
    ../../modules/programs/llm-agents.nix
    ../../modules/programs/obs-studio.nix
    ../../modules/programs/obsidian.nix
    ../../modules/services/audio-pipewire.nix
    ../../modules/services/desktop-gnome.nix
    ../../modules/services/failure-reporting.nix
    ../../modules/services/openclaw-embeddings.nix
    ../../modules/services/openclaw-gateway.nix
    ../../modules/services/syncthing.nix
    ../../modules/users/iva.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "legion";
  networking.networkmanager.enable = true;

  local.openclaw.enable = false;

  users.users.iva.extraGroups = [ "wheel" "networkmanager" "input" "ydotool" "plugdev" "dialout" ];

  hardware.keyboard.qmk.enable = true;

  system.stateVersion = "25.11";
}
