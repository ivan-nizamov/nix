{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.helium
  ];
}
