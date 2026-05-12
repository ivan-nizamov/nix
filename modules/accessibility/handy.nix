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
}
