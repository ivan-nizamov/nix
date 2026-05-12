{ inputs, pkgs, ... }:
{
  imports = [
    inputs.handy.nixosModules.default
  ];

  programs.handy.enable = true;

  # Wayland text injection path recommended by Handy for GNOME sessions.
  environment.systemPackages = [ pkgs.wtype ];
}
