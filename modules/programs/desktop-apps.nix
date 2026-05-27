{ pkgs, ... }:
let
  ratty = pkgs.callPackage ../../pkgs/ratty { };
in
{
  environment.systemPackages = [
    pkgs.helium
    ratty
  ];
}
