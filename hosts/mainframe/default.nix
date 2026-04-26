{ lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/locale.nix
    ../../modules/core/memory.nix
    ../../modules/core/networking.nix
    ../../modules/core/nix-settings.nix
    ../../modules/core/shell.nix
    ../../modules/programs/llm-agents.nix
    ../../modules/security/passwordless-rebuilds.nix
    ../../modules/services/failure-reporting.nix
    ../../modules/users/iva.nix
  ];

  boot.loader.grub.enable = true;

  local.rebuild.flakeTarget = "mainframe";

  networking.hostName = "mainframe";
  networking.nameservers = [
    "2001:4860:4860::8888"
    "2001:4860:4860::8844"
  ];
  networking.defaultGateway6 = {
    address = "2a0c:4ac1:4::1";
    interface = "eth0";
  };
  networking.dhcpcd.enable = false;
  networking.networkmanager.enable = lib.mkForce false;
  networking.usePredictableInterfaceNames = lib.mkForce false;
  networking.interfaces.eth0 = {
    ipv4.addresses = [ ];
    ipv6.addresses = [
      {
        address = "2a0c:4ac1:4:1f3::a";
        prefixLength = 64;
      }
      {
        address = "fe80::2f9:65ff:feb5:c9e7";
        prefixLength = 64;
      }
    ];
    ipv6.routes = [
      {
        address = "2a0c:4ac1:4::1";
        prefixLength = 128;
      }
    ];
  };

  users.users.iva.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKpHMUJk8uBJ1sMaSnj2jT1mSU2r10KS5FtApuVkEvHO"
  ];

  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };
  services.qemuGuest.enable = true;
  systemd.services.qemu-guest-agent.wantedBy = [ "multi-user.target" ];
  services.udev.extraRules = ''
    ATTR{address}=="00:f9:65:b5:c9:e7", NAME="eth0"
  '';

  system.stateVersion = "25.11";
}
