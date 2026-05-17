{ lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/locale.nix
    ../../modules/core/memory.nix
    ../../modules/core/networking.nix
    ../../modules/core/nix-settings.nix
    ../../modules/core/shell.nix
    ../../modules/programs/llm-agents.nix
    ../../modules/services/openclaw-embeddings.nix
    ../../modules/services/openclaw-gateway.nix
    ../../modules/services/failure-reporting.nix
    ../../modules/services/nextcloud.nix
    ../../modules/services/syncthing.nix
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
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDoWmG5X2/Fd6aP4J0DhGBrc1okvWE9p/34HYY7+DBg1G5ozSbBVTC0AHf/Vj0ZCWGNiz7ba2m0bKkjdsmlHfeGGukiVyMy/2fK711PNKDxMhzpqvmcz9VQcgIZNuCITJu/VAYAPcr9btb1Ru7EkXt9GOv+EMnY/hJn7/NX6pH73ALotlviAPh9qYGVh3AgMpxiGudeOJoslFi5rcxhLXNxJllHeaq5XWot14iWC7eURC8HyPsxstDjY7ECdyncofFvBnPyEretfz9r1PTDFOj0ab2TgTU4acD8In8LqnQHp2H2ezKJew8DKGYO8OoeeJzZC8BENE0J13lKMcHJyFrt"
  ];

  services.openssh.enable = true;
  services.openssh.openFirewall = false;
  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };
  networking.firewall = {
    allowedTCPPorts = [ ];
    trustedInterfaces = [ "tailscale0" ];
  };

  services.qemuGuest.enable = true;

  services.syncthing.settings = {
    devices.thinkpad = {
      id = "6HKQA6G-7EBXXRK-3WEA6FG-O72ECBN-SZ2SF65-AZXAHPY-TOEC5JJ-XG77LAI";
    };
    folders."openclaw-workspace".devices = lib.mkAfter [ "thinkpad" ];
  };

  local.openclaw.embeddings = {
    modelId = "BAAI/bge-small-en-v1.5";
    modelRevision = "b49342cba6a5914c1760cd4aae1d75a6f2e8fc4c";
    device = "cpu";
    batchSize = 2;
    environment = {
      INFINITY_BETTERTRANSFORMER = "false";
      OMP_NUM_THREADS = "2";
      MKL_NUM_THREADS = "2";
    };
  };

  systemd.services.qemu-guest-agent = {
    path = [
      pkgs.shadow
      pkgs.bashInteractive
      pkgs.coreutils
    ];
    wantedBy = [ "multi-user.target" ];
  };
  systemd.tmpfiles.rules = [
    "d /usr/sbin 0755 root root - -"
    "L+ /bin/bash - - - - /run/current-system/sw/bin/bash"
    "L+ /usr/bin/passwd - - - - /run/wrappers/bin/passwd"
    "L+ /usr/bin/chpasswd - - - - /run/current-system/sw/bin/chpasswd"
    "L+ /usr/sbin/chpasswd - - - - /run/current-system/sw/bin/chpasswd"
  ];
  services.udev.extraRules = ''
    ATTR{address}=="00:f9:65:b5:c9:e7", NAME="eth0"
  '';

  system.stateVersion = "25.11";
}
