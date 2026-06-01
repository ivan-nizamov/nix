{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    networkmanagerapplet
    pavucontrol
  ];

  programs.waybar = {
    enable = true;
    systemd.target = "graphical-session.target";
  };
}
