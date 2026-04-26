{ lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    tailscale
  ];

  services.tailscale = {
    enable = true;
    openFirewall = true;
    extraSetFlags = [ "--ssh" ];
  };

  systemd.services.tailscaled = {
    unitConfig = {
      StartLimitIntervalSec = "10min";
      StartLimitBurst = 5;
      OnFailure = [ "service-failure-report@%n.service" ];
    };

    serviceConfig = {
      RestartSec = lib.mkForce "15s";
    };
  };
}
