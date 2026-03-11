{ pkgs, ... }:
{
  users.users.iva = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "input" "ydotool" ];
    linger = true;
    shell = pkgs.zsh;
  };
}
