{ pkgs, ... }:
let
  terminalphone = pkgs.callPackage ../../pkgs/terminalphone { };
in
{
  environment.systemPackages = with pkgs; [
    ghostty
    kitty
    helium
    terminalphone
  ];
}
