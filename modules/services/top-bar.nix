{ pkgs, ... }:
let
  waybarConfigDir = "/home/iva/nix/dotfiles/waybar";
in
{
  environment.systemPackages = with pkgs; [
    blueman
    mako
    networkmanagerapplet
    pavucontrol
  ];

  programs.waybar = {
    enable = true;
    systemd.target = "graphical-session.target";
  };

  systemd.user.services.mako = {
    description = "Mako notification daemon";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.mako}/bin/mako";
      Restart = "on-failure";
    };
  };

  systemd.tmpfiles.rules = [
    "d /home/iva/.config 0755 iva users - -"
    "d /home/iva/.config/waybar 0755 iva users - -"
    "d /home/iva/.config/waybar/bin 0755 iva users - -"
    "L+ /home/iva/.config/waybar/config.jsonc - - - - ${waybarConfigDir}/config.jsonc"
    "L+ /home/iva/.config/waybar/style.css - - - - ${waybarConfigDir}/style.css"
    "L+ /home/iva/.config/waybar/colors.css - - - - ${waybarConfigDir}/colors.css"
    "L+ /home/iva/.config/waybar/bin/updatecheck - - - - ${waybarConfigDir}/bin/updatecheck"
  ];
}
