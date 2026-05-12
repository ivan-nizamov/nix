{ pkgs, ... }:
let
  handy = pkgs.callPackage ../../pkgs/handy { };
in
{
  # Wayland text injection path recommended by Handy for GNOME sessions.
  environment.systemPackages = [
    handy
    pkgs.wtype
  ];
}
