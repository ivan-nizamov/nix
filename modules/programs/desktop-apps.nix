{ pkgs, ... }:
let
  terminalphone = pkgs.callPackage ../../pkgs/terminalphone { };
in
{
  environment.systemPackages = [
    pkgs.helium
    terminalphone
  ];
}
