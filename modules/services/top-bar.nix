{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    networkmanagerapplet
    pavucontrol
    waybar
  ];

  programs.waybar = {
    enable = true;
    systemd.target = "graphical-session.target";
  };
}
