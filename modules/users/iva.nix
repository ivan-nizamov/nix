{ lib, pkgs, ... }:
{
  users.users.iva = {
    isNormalUser = true;
    extraGroups = lib.mkDefault [ "wheel" ];
    linger = true;
    shell = pkgs.zsh;
  };
}
