{ lib, pkgs, ... }:
let
  authorizedKeys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDoMZzpfBa3IuYKM/NH3twsxX7QFdMzaM1ZrDRW6FqY+whAiXPLAkSBPkR69M23g4ihzDcKB2Yl0JEYrcm/m3ZQp2sWoT6x//RJegvE4WhXXCMN99qGdZoaoIh2HzF6CWB3h58k0hikHQ4wcYF50wVSQzECjcj9i9wVUxqSynOxhsXirvWXd/T1cmkV0msTANKg9wEDBr2oT3iIgIY/dovQDo4ikpDbn2c1tS2rWA6MNotMuTMh5rAYxj8kwaKMidk1ELTagRIYcJlGDHQyA+jKYp3x/8UkVtHWJ3Ina9YmrMBtolAbEZc3h5ENmQkbkXvUUal8wWGY6TS2GlQPgHQt"
  ];
in
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/core/locale.nix
    ../../modules/core/memory.nix
    ../../modules/core/nix-settings.nix
    ../../modules/users/iva.nix
  ];

  boot.loader.grub.enable = true;

  networking.hostName = "mainframe";
  networking.useDHCP = false;
  networking.networkmanager.enable = lib.mkForce false;

  services.cloud-init = {
    enable = true;
    network.enable = true;
  };

  services.openssh.enable = true;
  services.openssh.openFirewall = false;
  services.openssh.settings = {
    PermitRootLogin = "prohibit-password";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  services.qemuGuest.enable = true;

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  environment.systemPackages = with pkgs; [
    curl
    git
    htop
    tmux
    vim
    wget
  ];

  users.users.iva = {
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = authorizedKeys;
  };

  users.users.root.openssh.authorizedKeys.keys = authorizedKeys;

  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "25.11";
}
