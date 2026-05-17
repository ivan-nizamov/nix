{ lib, pkgs, ... }:
{
  users.users.iva = {
    isNormalUser = true;
    extraGroups = lib.mkDefault [ "wheel" ];
    linger = true;
    shell = pkgs.zsh;
  };

  systemd.tmpfiles.rules = [
    "d /home/iva/.pi 0755 iva users - -"
    "d /home/iva/.pi/agent 0755 iva users - -"
    "L+ /home/iva/.pi/agent/settings.json - - - - /home/iva/nix/dotfiles/pi/settings.json"
  ];
}
