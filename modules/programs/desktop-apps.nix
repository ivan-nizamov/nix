{ pkgs, ... }:
let
  terminalphone = pkgs.callPackage ../../pkgs/terminalphone { };
in
{
  environment.systemPackages = [
    pkgs.ghostty
    pkgs.helium
    terminalphone
  ];
}
