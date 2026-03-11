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
    ../../modules/security/passwordless-rebuilds.nix
    ../../modules/services/audio-pipewire.nix
    ../../modules/services/desktop-gnome.nix
    ../../modules/users/iva.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "mainframe";

  system.stateVersion = "25.11";
}
