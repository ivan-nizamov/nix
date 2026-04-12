{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.calibre
  ];

  # Calibre uses 8080 for the content server and 9090 for wireless device
  # connections, both of which are useful for e-book readers on the LAN.
  networking.firewall.allowedTCPPorts = [
    8080
    9090
  ];
}
