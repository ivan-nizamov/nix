{ pkgs, ... }:
let
  handy = pkgs.callPackage ../../pkgs/handy { };
in
{
  # GNOME/Wayland does not support the virtual-keyboard protocol used by
  # wtype, so prefer the same uinput-based path as the DIY dictation setup.
  environment.systemPackages = [
    handy
    pkgs.dotool
  ];

  systemd.user.services.handy = {
    description = "Handy speech-to-text app";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "default.target" "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${handy}/bin/handy --start-hidden";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
