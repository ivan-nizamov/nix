{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    networkmanagerapplet
    blueman
    pavucontrol
  ];

  programs.waybar = {
    enable = true;
    systemd.target = "graphical-session.target";
  };
}
